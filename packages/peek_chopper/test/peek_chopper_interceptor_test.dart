import 'dart:async';

import 'package:chopper/chopper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:peek/core.dart';
import 'package:peek_chopper/peek_chopper.dart';

/// A sink that keeps what it was told, so a test can read it back.
///
/// One that is [failing] refuses every event instead, which is how a test
/// asks what happens to a call when reporting goes wrong.
final class RecordingSink implements PeekSink {
  RecordingSink({this.failing = false});

  final bool failing;
  final List<PeekEvent> events = [];
  final List<Object> errors = [];

  @override
  void report(PeekEvent event) {
    if (failing) throw StateError('this sink cannot take it');
    events.add(event);
  }

  @override
  void reportAdapterError(Object error, StackTrace stackTrace) =>
      errors.add(error);
}

/// Sits below the adapter and keeps what passed by, so a test can check that
/// what the caller got is what the chain produced.
final class Downstream implements Interceptor {
  final List<Response<dynamic>> responses = [];

  @override
  Future<Response<BodyType>> intercept<BodyType>(Chain<BodyType> chain) async {
    final response = await chain.proceed(chain.request);
    responses.add(response);
    return response;
  }
}

void main() {
  final base = Uri.parse('https://api.example.com');
  late RecordingSink sink;
  late PeekFakeClock clock;
  late Downstream downstream;

  ChopperClient clientAnswering(
    FutureOr<http.Response> Function(http.Request request) answer, {
    PeekSink? into,
  }) => ChopperClient(
    baseUrl: base,
    client: MockClient((request) async => answer(request)),
    interceptors: [
      PeekChopperInterceptor(into ?? sink, clock: clock),
      downstream,
    ],
    converter: const JsonConverter(),
  );

  Future<Response<dynamic>> get(ChopperClient client, String path) =>
      client.send<dynamic, dynamic>(Request('GET', Uri.parse(path), base));

  setUp(() {
    sink = RecordingSink();
    clock = PeekFakeClock();
    downstream = Downstream();
  });

  test('reports a call that came back', () async {
    final client = clientAnswering(
      (_) => http.Response(
        '{"id":7}',
        200,
        headers: const {'content-type': 'application/json'},
      ),
    );

    final response = await get(client, '/users');

    expect(response.statusCode, 200);
    expect(sink.errors, isEmpty);
    expect(sink.events, hasLength(2));

    final started = sink.events.first as PeekRequestStarted;
    final received = sink.events.last as PeekResponseReceived;
    expect(started.source, 'chopper');
    expect(started.request.method, 'GET');
    expect(started.request.uri.path, '/users');
    expect(started.request.extra['client'], 'chopper');
    expect(received.id, started.id);
    expect(received.response.statusCode, 200);
    expect((received.response.body as PeekTextBody).text, '{"id":7}');
  });

  test('reports a refused status as the answer it is', () async {
    final client = clientAnswering(
      (_) => http.Response('{"error":"gone"}', 404),
    );

    final response = await get(client, '/missing');

    expect(response.statusCode, 404);
    expect(sink.events.whereType<PeekRequestFailed>(), isEmpty);
    final received = sink.events.last as PeekResponseReceived;
    expect(received.response.statusCode, 404);
    expect((received.response.body as PeekTextBody).text, '{"error":"gone"}');
  });

  test('ends a call the connection broke as a failure', () async {
    final client = clientAnswering(
      (request) => throw http.ClientException('closed', request.url),
    );

    final error = await get(
      client,
      '/flaky',
    ).then<Object?>((_) => null, onError: (Object error) => error);

    final failed = sink.events.last as PeekRequestFailed;
    expect(failed.failure.kind, PeekFailureKind.connection);
    expect(failed.response, isNull);
    // The error the caller sees and the one Peek kept are one object: the
    // adapter rethrows rather than wrapping.
    expect(failed.failure.details, same(error));
  });

  test('ends an aborted call as cancelled', () async {
    final client = clientAnswering(
      (request) => throw http.RequestAbortedException(request.url),
    );

    await expectLater(
      get(client, '/slow'),
      throwsA(isA<http.RequestAbortedException>()),
    );

    final failed = sink.events.last as PeekRequestFailed;
    expect(failed.failure.kind, PeekFailureKind.cancelled);
  });

  test('hands back the response the chain produced', () async {
    final client = clientAnswering((_) => http.Response('{"id":7}', 200));

    final response = await get(client, '/users');

    expect(response, same(downstream.responses.single));
  });

  test('a sink that raises does not break the call', () async {
    final failing = RecordingSink(failing: true);
    final client = clientAnswering(
      (_) => http.Response('{"id":7}', 200),
      into: failing,
    );

    final response = await get(client, '/users');

    expect(response.statusCode, 200);
    expect(response.body, {'id': 7});
    // The start was never reported, so neither is its answer: an id the call
    // was never given is an id it cannot report under.
    expect(failing.errors, hasLength(1));
    expect(failing.errors.single, isA<StateError>());
    expect(failing.events, isEmpty);
  });

  test('a second trip through the chain is a second call', () async {
    final client = clientAnswering((_) => http.Response('{}', 200));

    await get(client, '/users');
    await get(client, '/users');

    expect(sink.events.map((event) => event.id).toSet(), hasLength(2));
    expect(sink.events.whereType<PeekRequestStarted>(), hasLength(2));
  });

  test('stamps events with the clock it was given', () async {
    final client = clientAnswering((_) => http.Response('{}', 200));

    await get(client, '/users');
    clock.advance(const Duration(seconds: 5));
    await get(client, '/users');

    expect(sink.events.map((event) => event.timestamp).toSet(), hasLength(2));
  });

  test('takes its clock from the instance it reports into', () {
    final peek = Peek(
      options: const PeekOptions().copyWith(clock: PeekFakeClock()),
    );
    addTearDown(peek.dispose);

    expect(PeekChopperInterceptor(peek).clock, same(peek.options.clock));
  });
}
