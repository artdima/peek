import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:http/retry.dart';
import 'package:http/testing.dart';

// The adapter is written against these answers: an `http` release that
// changes one of them should break this file first.

Future<HttpServer> serve(
  Future<void> Function(HttpRequest request) handle,
) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() => server.close(force: true));
  // A client that walked away leaves the handler writing into a dead socket;
  // that is not what these tests are about.
  server.listen((request) => handle(request).onError<Object>((_, _) {}));
  return server;
}

// Unbuffered and with a length: the first part reaches the client while the
// second waits, instead of sitting in the server's output buffer.
Future<void> sendInTwoParts(
  HttpResponse response,
  String first,
  String second,
  Completer<void> between,
) async {
  response
    ..bufferOutput = false
    ..contentLength = first.length + second.length
    ..write(first);
  await response.flush();
  await between.future;
  response.write(second);
  await response.close();
}

Uri at(HttpServer server, String path) =>
    Uri.parse('http://${server.address.host}:${server.port}$path');

final class Tagged extends http.BaseClient {
  Tagged(this.inner);

  final http.Client inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      inner.send(request);

  @override
  void close() => inner.close();
}

void main() {
  late IOClient client;

  setUp(() {
    client = IOClient();
    addTearDown(client.close);
  });

  group('(1) the response IOClient hands back', () {
    test('is an IOStreamedResponse that knows the final url', () async {
      final server = await serve((request) async {
        if (request.uri.path == '/from') {
          await request.response.redirect(request.requestedUri.resolve('/to'));
        } else {
          request.response.write('here');
          await request.response.close();
        }
      });

      final response = await client.send(
        http.Request('GET', at(server, '/from')),
      );
      await response.stream.drain<void>();

      expect(response, isA<IOStreamedResponse>());
      expect(response, isA<http.BaseResponseWithUrl>());
      expect((response as http.BaseResponseWithUrl).url, at(server, '/to'));
      expect(response.statusCode, 200);
      expect(response.isRedirect, isFalse);
    });

    test('shows an unfollowed redirect as the answer it is', () async {
      final server = await serve(
        (request) =>
            request.response.redirect(request.requestedUri.resolve('/to')),
      );

      final request = http.Request('GET', at(server, '/from'))
        ..followRedirects = false;
      final response = await client.send(request);
      await response.stream.drain<void>();

      expect(response.statusCode, HttpStatus.movedTemporarily);
      expect(response.isRedirect, isTrue);
      expect(response.headers['location'], '${at(server, '/to')}');
      expect((response as http.BaseResponseWithUrl).url, request.url);
    });

    test('carries a single-subscription body stream', () async {
      final server = await serve((request) async {
        request.response.write('once');
        await request.response.close();
      });

      final response = await client.send(http.Request('GET', at(server, '/')));
      final body = response.stream.toBytes();

      expect(response.stream.isBroadcast, isFalse);
      expect(() => response.stream.listen(null), throwsStateError);
      expect(utf8.decode(await body), 'once');
    });
  });

  group('(2) response headers', () {
    test(
      'fold repeated Set-Cookie with a bare comma; the split undoes it',
      () async {
        const expiring = 'a=1; Expires=Wed, 21 Oct 2026 07:28:00 GMT';
        final server = await serve((request) async {
          request.response.headers
            ..add('set-cookie', expiring)
            ..add('set-cookie', 'b=2')
            ..add('x-fruit', 'apple')
            ..add('x-fruit', 'banana');
          await request.response.close();
        });

        final response = await client.send(
          http.Request('GET', at(server, '/')),
        );
        await response.stream.drain<void>();

        expect(response.headers['set-cookie'], '$expiring,b=2');
        // dart:io's server folds these onto one line itself.
        expect(response.headers['x-fruit'], 'apple, banana');
        expect(response.headersSplitValues['set-cookie'], [expiring, 'b=2']);
        expect(response.headersSplitValues['x-fruit'], ['apple', 'banana']);
      },
    );

    test(
      'report the zipped Content-Length for a body that arrives unzipped',
      () async {
        final text = 'x' * 1000;
        final zipped = gzip.encode(utf8.encode(text));
        final server = await serve((request) async {
          request.response
            ..headers.set('content-encoding', 'gzip')
            ..contentLength = zipped.length
            ..add(zipped);
          await request.response.close();
        });

        final response = await client.send(
          http.Request('GET', at(server, '/')),
        );
        final body = await response.stream.toBytes();

        expect(body, hasLength(text.length));
        expect(response.contentLength, zipped.length);
        // The adapter tells a zipped body apart by this header staying put.
        expect(response.headers['content-encoding'], 'gzip');
        expect(response.headers['content-length'], '${zipped.length}');
      },
    );
  });

  group('(3) a request before it is sent', () {
    test(
      'a multipart request has no content-type until it is finalized',
      () async {
        final request =
            http.MultipartRequest('POST', Uri.parse('https://x.test'))
              ..fields['name'] = 'peek'
              ..files.add(
                http.MultipartFile.fromString(
                  'file',
                  'hello',
                  filename: 'h.txt',
                ),
              );

        expect(request.headers.containsKey('content-type'), isFalse);
        expect(request.contentLength, greaterThan(0));
        expect(request.files.single.isFinalized, isFalse);

        final mock = MockClient.streaming((sent, body) async {
          await body.drain<void>();
          return http.StreamedResponse(const Stream.empty(), 200);
        });
        await mock.send(request);

        expect(request.finalized, isTrue);
        expect(request.files.single.isFinalized, isTrue);
        expect(
          request.headers['content-type'],
          startsWith('multipart/form-data; boundary=dart-http-boundary-'),
        );
      },
    );

    test('a plain request states its content-type as its body is set', () {
      final text = http.Request('POST', Uri.parse('https://x.test'))
        ..body = 'hi';
      final form = http.Request('POST', Uri.parse('https://x.test'))
        ..bodyFields = {'a': '1'};

      expect(text.headers['content-type'], 'text/plain; charset=utf-8');
      expect(text.contentLength, 2);
      expect(form.headers['content-type'], 'application/x-www-form-urlencoded');
    });

    test('the body getter throws on a charset the bytes getter ignores', () {
      final request =
          http.Request('POST', Uri.parse('https://x.test'))
            ..bodyBytes = [104, 105]
            ..headers['content-type'] = 'text/plain; charset=no-such-charset';

      expect(() => request.body, throwsFormatException);
      expect(request.bodyBytes, [104, 105]);
    });
  });

  group('(4) failures', () {
    test(
      'a refused connection is a ClientException and a SocketException',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final uri = at(server, '/');
        await server.close(force: true);

        await expectLater(
          client.send(http.Request('GET', uri)),
          throwsA(
            allOf(
              isA<http.ClientException>(),
              isA<SocketException>(),
              isNot(isA<http.RequestAbortedException>()),
            ),
          ),
        );
      },
    );

    test('an abort before the headers is thrown out of send', () async {
      final arrived = Completer<void>();
      final release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      final server = await serve((request) async {
        arrived.complete();
        await release.future;
        await request.response.close();
      });
      final trigger = Completer<void>();

      final pending = client.send(
        http.AbortableRequest(
          'GET',
          at(server, '/'),
          abortTrigger: trigger.future,
        ),
      );
      await arrived.future;
      trigger.complete();

      await expectLater(pending, throwsA(isA<http.RequestAbortedException>()));
    });

    test('an abort mid-body is an error in the stream, then its end', () async {
      final release = Completer<void>();
      addTearDown(() {
        if (!release.isCompleted) release.complete();
      });
      final server = await serve((request) async {
        await sendInTwoParts(request.response, 'first', 'second', release);
      });
      final trigger = Completer<void>();

      final response = await client.send(
        http.AbortableRequest(
          'GET',
          at(server, '/'),
          abortTrigger: trigger.future,
        ),
      );
      final chunks = <String>[];
      final errors = <Object>[];
      final done = Completer<void>();
      response.stream.listen(
        (chunk) {
          chunks.add(utf8.decode(chunk));
          if (!trigger.isCompleted) trigger.complete();
        },
        onError: errors.add,
        onDone: done.complete,
      );
      await done.future;

      expect(chunks.join(), 'first');
      expect(errors, [isA<http.RequestAbortedException>()]);
    });
  });

  test('(5) Client() inside the runWithClient factory is the default', () {
    var built = 0;
    final zoned = http.runWithClient(http.Client.new, () {
      built++;
      return Tagged(http.Client());
    });
    addTearDown(zoned.close);

    expect(zoned, isA<Tagged>());
    expect((zoned as Tagged).inner, isA<IOClient>());
    expect(built, 1);
  });

  test('(6) RetryClient sends a fresh StreamedRequest per attempt', () async {
    final seen = <http.BaseRequest>[];
    var rejectedListened = false;
    var rejectedCancelled = false;
    final rejected = StreamController<List<int>>(
      onListen: () => rejectedListened = true,
      onCancel: () => rejectedCancelled = true,
    );
    addTearDown(rejected.close);

    final retry = RetryClient(
      MockClient.streaming((request, body) async {
        seen.add(request);
        await body.drain<void>();
        return seen.length == 1
            ? http.StreamedResponse(rejected.stream, 503)
            : http.StreamedResponse(Stream.value([111, 107]), 200);
      }),
      delay: (_) => Duration.zero,
    );
    final original = http.Request('POST', Uri.parse('https://x.test'))
      ..body = 'payload';

    final response = await retry.send(original);
    await response.stream.drain<void>();

    expect(response.statusCode, 200);
    expect(original.finalized, isTrue);
    expect(seen, hasLength(2));
    expect(seen, everyElement(isA<http.StreamedRequest>()));
    expect(seen.first, isNot(same(seen.last)));
    expect(seen.first.headers['content-type'], 'text/plain; charset=utf-8');
    expect(rejectedListened, isTrue);
    expect(rejectedCancelled, isTrue);
  });

  test('(7) a paused body subscription holds delivery until resumed', () async {
    final next = Completer<void>();
    addTearDown(() {
      if (!next.isCompleted) next.complete();
    });
    final server = await serve((request) async {
      await sendInTwoParts(request.response, 'a', 'b', next);
    });

    final response = await client.send(http.Request('GET', at(server, '/')));
    final chunks = <String>[];
    final done = Completer<void>();
    late final StreamSubscription<List<int>> subscription;
    subscription = response.stream.listen((chunk) {
      chunks.add(utf8.decode(chunk));
      if (!next.isCompleted) {
        subscription.pause();
        next.complete();
      }
    }, onDone: done.complete);

    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(chunks.join(), 'a');

    subscription.resume();
    await done.future;
    await subscription.cancel();

    expect(chunks.join(), 'ab');
  });
}
