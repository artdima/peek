import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:http/retry.dart';
import 'package:peek/core.dart';
import 'package:peek_http/peek_http.dart';

final class RecordingSink implements PeekSink {
  RecordingSink({this.failingOn});

  /// Events of this type are refused, which is how a test breaks reporting.
  final Type? failingOn;
  final List<PeekEvent> events = [];
  final List<Object> errors = [];

  @override
  void report(PeekEvent event) {
    if (event.runtimeType == failingOn) {
      throw StateError('this sink cannot take it');
    }
    events.add(event);
  }

  @override
  void reportAdapterError(Object error, StackTrace stackTrace) =>
      errors.add(error);
}

final class Answering extends http.BaseClient {
  Answering(this.answer);

  final Future<http.StreamedResponse> Function(http.BaseRequest request) answer;
  final List<http.BaseRequest> requests = [];
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    requests.add(request);
    return answer(request);
  }

  @override
  void close() => closed = true;
}

void main() {
  final url = Uri.parse('https://api.example.com/users');
  late RecordingSink sink;
  late PeekFakeClock clock;

  setUp(() {
    sink = RecordingSink();
    clock = PeekFakeClock();
  });

  http.StreamedResponse answer(
    List<List<int>> chunks, {
    int statusCode = 200,
    Map<String, String> headers = const {},
    int? contentLength,
  }) => http.StreamedResponse(
    Stream.fromIterable(chunks),
    statusCode,
    headers: headers,
    contentLength: contentLength,
    reasonPhrase: 'OK',
  );

  PeekHttpClient clientAnswering(
    http.StreamedResponse Function(http.BaseRequest request) respond, {
    PeekSink? into,
  }) => PeekHttpClient(
    into ?? sink,
    Answering((request) async => respond(request)),
    clock: clock,
  );

  test('reports the call once its body has been read', () async {
    final client = clientAnswering(
      (_) => answer(
        [utf8.encode('{"id":'), utf8.encode('7}')],
        headers: const {'content-type': 'application/json'},
      ),
    );

    final response = await client.send(http.Request('GET', url));

    expect(sink.events, [isA<PeekRequestStarted>()]);
    expect(response.statusCode, 200);
    expect(response.reasonPhrase, 'OK');
    expect(response.headers['content-type'], 'application/json');

    clock.advance(const Duration(milliseconds: 40));
    expect(await response.stream.bytesToString(), '{"id":7}');

    expect(sink.errors, isEmpty);
    expect(sink.events, hasLength(2));
    final started = sink.events.first as PeekRequestStarted;
    final received = sink.events.last as PeekResponseReceived;
    expect(started.source, 'http');
    expect(started.request.method, 'GET');
    expect(started.request.uri, url);
    expect(received.id, started.id);
    expect(
      received.timestamp.difference(started.timestamp),
      const Duration(milliseconds: 40),
    );
    expect(received.response.statusCode, 200);
    expect((received.response.body as PeekTextBody).text, '{"id":7}');
  });

  test('leaves a call whose body nobody reads pending', () async {
    final client = clientAnswering((_) => answer([utf8.encode('unread')]));

    await client.send(http.Request('GET', url));
    await pumpEventQueue();

    expect(sink.events, [isA<PeekRequestStarted>()]);
  });

  test('reports a refused status as the answer it is', () async {
    final client = clientAnswering(
      (_) => answer([utf8.encode('gone')], statusCode: 404),
    );

    final response = await client.send(http.Request('GET', url));
    await response.stream.drain<void>();

    expect(sink.events.whereType<PeekRequestFailed>(), isEmpty);
    final received = sink.events.last as PeekResponseReceived;
    expect(received.response.statusCode, 404);
    expect((received.response.body as PeekTextBody).text, 'gone');
  });

  test('ends a call send threw out of as a failure, rethrowing it', () async {
    final thrown = http.ClientException('refused', url);
    final trace = StackTrace.current;
    final client = PeekHttpClient(
      sink,
      Answering((_) => Future.error(thrown, trace)),
      clock: clock,
    );

    Object? caught;
    StackTrace? caughtTrace;
    try {
      await client.send(http.Request('GET', url));
    } on Object catch (error, stackTrace) {
      caught = error;
      caughtTrace = stackTrace;
    }

    expect(caught, same(thrown));
    expect(caughtTrace, same(trace));
    expect(sink.events, hasLength(2));
    final failed = sink.events.last as PeekRequestFailed;
    expect(failed.failure.kind, PeekFailureKind.connection);
    expect(failed.failure.details, same(thrown));
    expect(failed.response, isNull);
  });

  test('ends a body that failed as a failure with what came before', () async {
    final body = StreamController<List<int>>();
    final client = clientAnswering(
      (_) => http.StreamedResponse(body.stream, 200, contentLength: 8),
    );
    final aborted = http.RequestAbortedException(url);
    final trace = StackTrace.current;

    final response = await client.send(http.Request('GET', url));
    final errors = <Object>[];
    final traces = <StackTrace>[];
    final done = Completer<void>();
    response.stream.listen(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        errors.add(error);
        traces.add(stackTrace);
      },
      onDone: done.complete,
    );
    body
      ..add(utf8.encode('half'))
      ..addError(aborted, trace);
    unawaited(body.close());
    await done.future;

    expect(errors, [same(aborted)]);
    expect(traces, [same(trace)]);
    final failed = sink.events.last as PeekRequestFailed;
    expect(failed.failure.kind, PeekFailureKind.cancelled);
    final text = failed.response?.body as PeekTextBody?;
    expect(text?.text, 'half');
    expect(text?.size, 8);
    expect(text?.isTruncated, isTrue);
  });

  test('closes a body the app walked away from with what it read', () async {
    final body = StreamController<List<int>>();
    addTearDown(() => unawaited(body.close()));
    final client = clientAnswering(
      (_) => http.StreamedResponse(
        body.stream,
        200,
        contentLength: 10,
        headers: const {'content-type': 'text/plain'},
      ),
    );

    final response = await client.send(http.Request('GET', url));
    final first = Completer<void>();
    final subscription = response.stream.listen((_) => first.complete());
    body.add(utf8.encode('abc'));
    await first.future;
    await subscription.cancel();

    final received = sink.events.last as PeekResponseReceived;
    final text = received.response.body as PeekTextBody;
    expect(text.text, 'abc');
    expect(text.size, 10);
    expect(text.isTruncated, isTrue);
  });

  test('sizes a zipped body cut short by the bytes it read', () async {
    final body = StreamController<List<int>>();
    addTearDown(() => unawaited(body.close()));
    final client = clientAnswering(
      (_) => http.StreamedResponse(
        body.stream,
        200,
        contentLength: 10,
        headers: const {'content-encoding': 'gzip'},
      ),
    );

    final response = await client.send(http.Request('GET', url));
    final first = Completer<void>();
    final subscription = response.stream.listen((_) => first.complete());
    body.add(utf8.encode('abcdefghijklmnop'));
    await first.future;
    await subscription.cancel();

    final received = sink.events.last as PeekResponseReceived;
    expect(received.response.body.size, 16);
  });

  test("keeps no more of a body than Peek's limit", () async {
    final peek = Peek(
      options: const PeekOptions(limits: PeekLimits(maxBodyBytes: 4)),
    );
    addTearDown(peek.dispose);
    final client = PeekHttpClient(
      peek,
      Answering(
        (_) async => answer(
          [utf8.encode('0123'), utf8.encode('456789')],
          headers: const {'content-type': 'text/plain'},
        ),
      ),
    );

    final response = await client.send(http.Request('GET', url));
    expect(await response.stream.bytesToString(), '0123456789');

    final body = peek.store.entries.single.response!.body as PeekTextBody;
    expect(body.text, '0123');
    expect(body.size, 10);
  });

  test('a sink that refuses the start leaves the call untouched', () async {
    final original = answer([utf8.encode('fine')]);
    final refusing = RecordingSink(failingOn: PeekRequestStarted);
    final client = PeekHttpClient(
      refusing,
      Answering((_) async => original),
      clock: clock,
    );

    final response = await client.send(http.Request('GET', url));

    expect(response, same(original));
    expect(await response.stream.bytesToString(), 'fine');
    expect(refusing.events, isEmpty);
    expect(refusing.errors, [isA<StateError>()]);
  });

  test('a sink that refuses the ending still delivers the body', () async {
    final refusing = RecordingSink(failingOn: PeekResponseReceived);
    final client = clientAnswering(
      (_) => answer([utf8.encode('fine')]),
      into: refusing,
    );

    final response = await client.send(http.Request('GET', url));

    expect(await response.stream.bytesToString(), 'fine');
    expect(refusing.events, [isA<PeekRequestStarted>()]);
    expect(refusing.errors, [isA<StateError>()]);
  });

  test('sends the request it was given and closes the client it wraps', () {
    final inner = Answering((_) async => answer(const []));
    final client = PeekHttpClient(sink, inner, clock: clock);
    final request = http.Request('POST', url)..body = 'payload';

    unawaited(client.send(request));
    client.close();

    expect(inner.requests, [same(request)]);
    expect(inner.closed, isTrue);
  });

  group('with RetryClient', () {
    http.StreamedResponse flaky(http.BaseRequest request, int attempt) =>
        attempt == 1
            ? answer([utf8.encode('busy')], statusCode: 503)
            : answer([utf8.encode('ok')]);

    test('inside it, every attempt is a call of its own', () async {
      var attempt = 0;
      final client = RetryClient(
        PeekHttpClient(
          sink,
          Answering((request) async => flaky(request, ++attempt)),
          clock: clock,
        ),
        delay: (_) => Duration.zero,
      );

      final response = await client.send(
        http.Request('POST', url)..body = 'payload',
      );
      await response.stream.drain<void>();

      final starts = sink.events.whereType<PeekRequestStarted>().toList();
      final endings = sink.events.whereType<PeekResponseReceived>().toList();
      expect(starts, hasLength(2));
      expect(endings.map((e) => e.response.statusCode), [503, 200]);
      expect(
        starts.map((e) => (e.request.body as PeekUnavailableBody).reason),
        everyElement(PeekBodyUnavailableReason.streamed),
      );
    });

    test('outside it, the call is one entry with its body', () async {
      var attempt = 0;
      final client = PeekHttpClient(
        sink,
        RetryClient(
          Answering((request) async => flaky(request, ++attempt)),
          delay: (_) => Duration.zero,
        ),
        clock: clock,
      );

      final response = await client.send(
        http.Request('POST', url)..body = 'payload',
      );
      await response.stream.drain<void>();

      expect(sink.events, hasLength(2));
      final started = sink.events.first as PeekRequestStarted;
      final received = sink.events.last as PeekResponseReceived;
      expect((started.request.body as PeekTextBody).text, 'payload');
      expect(received.response.statusCode, 200);
    });
  });

  group('over IOClient', () {
    late HttpServer server;
    late Completer<void> release;

    setUp(() async {
      release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        try {
          if (request.uri.path == '/from') {
            await request.response.redirect(
              request.requestedUri.resolve('/to'),
            );
            return;
          }
          request.response
            ..bufferOutput = false
            ..contentLength = 4
            ..write('he');
          await request.response.flush();
          await release.future;
          request.response.write('re');
          await request.response.close();
        } on Object {
          // A client that detached or left is not what these tests are about.
        }
      });
    });

    Uri at(String path) =>
        Uri.parse('http://${server.address.host}:${server.port}$path');

    test('keeps the response an IOStreamedResponse with its url', () async {
      final client = PeekHttpClient(sink, IOClient(), clock: clock);
      addTearDown(client.close);

      final response = await client.send(http.Request('GET', at('/from')));
      release.complete();

      expect(response, isA<IOStreamedResponse>());
      expect((response as http.BaseResponseWithUrl).url, at('/to'));
      expect(await response.stream.bytesToString(), 'here');
      expect(sink.events.last, isA<PeekResponseReceived>());
    });

    test('lets detachSocket reach the socket under the response', () async {
      final client = PeekHttpClient(sink, IOClient(), clock: clock);
      addTearDown(client.close);

      final response =
          await client.send(http.Request('GET', at('/'))) as IOStreamedResponse;
      final socket = await response.detachSocket();
      addTearDown(socket.destroy);

      expect(socket, isA<Socket>());
      expect(sink.events, [isA<PeekRequestStarted>()]);
    });
  });
}
