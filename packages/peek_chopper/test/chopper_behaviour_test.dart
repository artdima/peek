import 'dart:async';

import 'package:chopper/chopper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// What Chopper hands an interceptor, pinned down.
///
/// The adapter is written against these answers rather than against the
/// documentation, and a Chopper release that changes one of them breaks this
/// file first — which is the point of it.
final class Probe implements Interceptor {
  /// The requests the chain handed over, in order.
  final List<Request> requests = [];

  /// What came back out of `proceed`, one way or the other.
  final List<Response<dynamic>> responses = [];
  final List<Object> errors = [];

  /// The only call of the test.
  Request get request => requests.single;

  @override
  FutureOr<Response<BodyType>> intercept<BodyType>(
    Chain<BodyType> chain,
  ) async {
    requests.add(chain.request);
    try {
      final response = await chain.proceed(chain.request);
      responses.add(response);
      return response;
    } on Object catch (error) {
      errors.add(error);
      rethrow;
    }
  }
}

void main() {
  final base = Uri.parse('https://api.example.com');
  late Probe probe;
  late http.Request? wire;

  ChopperClient clientAnswering(
    FutureOr<http.Response> Function(http.Request request) answer, {
    Converter? converter,
  }) => ChopperClient(
    baseUrl: base,
    client: MockClient((request) async {
      wire = request;
      return answer(request);
    }),
    interceptors: [probe],
    converter: converter,
  );

  setUp(() {
    probe = Probe();
    wire = null;
  });

  test('the request is the one the converter produced', () async {
    final client = clientAnswering(
      (_) => http.Response('{"ok":true}', 200),
      converter: const JsonConverter(),
    );

    await client.send<dynamic, dynamic>(
      Request('POST', Uri.parse('/orders'), base, body: const {'sku': 'A-1'}),
    );

    expect(probe.request.body, '{"sku":"A-1"}');
    expect(
      probe.request.headers['content-type'],
      startsWith('application/json'),
    );
    expect(wire!.body, probe.request.body);
  });

  test('the request carries the uri Chopper is about to call', () async {
    final client = clientAnswering((_) => http.Response('[]', 200));

    await client.send<dynamic, dynamic>(
      Request(
        'GET',
        Uri.parse('/users'),
        base,
        parameters: const {
          'page': 2,
          'tag': ['a', 'b'],
        },
        headers: const {'X-Trace': 'abc'},
      ),
    );

    expect(probe.request, isA<http.BaseRequest>());
    expect(probe.request.url, Uri.parse('$base/users?page=2&tag=a&tag=b'));
    expect(probe.request.url, wire!.url);
    expect(probe.request.method, 'GET');
    expect(probe.request.headers['X-Trace'], 'abc');
  });

  test('a failed status is a response, not an exception', () async {
    final client = clientAnswering(
      (_) => http.Response('{"error":"gone"}', 404),
      converter: const JsonConverter(),
    );

    final response = await client.send<dynamic, dynamic>(
      Request('GET', Uri.parse('/missing'), base),
    );

    expect(probe.errors, isEmpty);
    expect(response.isSuccessful, isFalse);
    expect(response.statusCode, 404);
    // The converted body is null on a failure; the payload moves to `error`,
    // while `base` keeps what the server actually sent.
    expect(response.body, isNull);
    expect(response.error, '{"error":"gone"}');
    expect((response.base as http.Response).body, '{"error":"gone"}');
  });

  test('a broken connection reaches the interceptor as it is', () async {
    final client = clientAnswering(
      (request) => throw http.ClientException('closed', request.url),
    );

    await expectLater(
      client.send<dynamic, dynamic>(Request('GET', Uri.parse('/flaky'), base)),
      throwsA(isA<http.ClientException>()),
    );

    expect(probe.errors.single, isA<http.ClientException>());
    expect(probe.responses, isEmpty);
  });

  test('an aborted call arrives as a kind of ClientException', () async {
    final client = clientAnswering(
      (request) => throw http.RequestAbortedException(request.url),
    );

    await expectLater(
      client.send<dynamic, dynamic>(Request('GET', Uri.parse('/slow'), base)),
      throwsA(isA<http.RequestAbortedException>()),
    );

    // Cancellation is a ClientException too, so an adapter sorting errors by
    // type has to look for it first or it will call every abort a connection
    // failure.
    expect(probe.errors.single, isA<http.ClientException>());
  });

  test('multipart parts arrive whole, the body stays empty', () async {
    final client = clientAnswering((_) => http.Response('{}', 200));

    await client.send<dynamic, dynamic>(
      Request(
        'POST',
        Uri.parse('/upload'),
        base,
        multipart: true,
        parts: [
          const PartValue<String>('note', 'a photo of a cat'),
          PartValueFile<List<int>>('photo', List<int>.filled(16, 0)),
        ],
      ),
    );

    final seen = probe.request;
    expect(seen.multipart, isTrue);
    expect(seen.body, isNull);
    expect(seen.parts, hasLength(2));
    expect(seen.parts.first.name, 'note');
    expect(seen.parts.first.value, 'a photo of a cat');
    expect(seen.parts.last, isA<PartValueFile<List<int>>>());
    expect(wire!.headers['content-type'], startsWith('multipart/form-data'));
  });
}
