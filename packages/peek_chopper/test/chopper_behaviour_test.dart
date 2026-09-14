import 'dart:async';
import 'dart:convert';

import 'package:chopper/chopper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final class Probe implements Interceptor {
  Request? seen;
  Object? thrown;
  Object? returned;

  @override
  FutureOr<Response<BodyType>> intercept<BodyType>(Chain<BodyType> chain) async {
    seen = chain.request;
    try {
      final response = await chain.proceed(chain.request);
      returned = response;
      return response;
    } on Object catch (error) {
      thrown = error;
      rethrow;
    }
  }
}

void describe(String label, Probe probe, http.Request? got) {
  final seen = probe.seen;
  print('--- $label');
  print('seen.method=${seen?.method}');
  print('seen.url=${seen?.url}');
  print('seen.uri=${seen?.uri} seen.baseUri=${seen?.baseUri}');
  print('seen.headers=${seen?.headers}');
  print('seen.body type=${seen?.body.runtimeType} value=${seen?.body}');
  print('seen.multipart=${seen?.multipart} parts=${seen?.parts}');
  print('returned=${probe.returned}');
  print('thrown=${probe.thrown.runtimeType} / ${probe.thrown}');
  if (got != null) {
    print('wire.method=${got.method} wire.url=${got.url}');
    print('wire.headers=${got.headers}');
    print('wire.body=${got.body.length > 200 ? '${got.body.substring(0, 200)}…' : got.body}');
  }
}

void main() {
  final base = Uri.parse('https://api.example.com');

  test('discovery', () async {
    // 1. body through the converter
    var probe = Probe();
    http.Request? got;
    var client = ChopperClient(
      baseUrl: base,
      client: MockClient((request) async {
        got = request;
        return http.Response('{"ok":true}', 200, headers: {'content-type': 'application/json'});
      }),
      interceptors: [probe],
      converter: const JsonConverter(),
    );
    await client.send<dynamic, dynamic>(
      Request('POST', Uri.parse('/orders'), base, body: const {'sku': 'A-1'}),
    );
    describe('1. body + converter', probe, got);

    // 2. parameters and the final uri
    probe = Probe();
    got = null;
    client = ChopperClient(
      baseUrl: base,
      client: MockClient((request) async {
        got = request;
        return http.Response('[]', 200);
      }),
      interceptors: [probe],
    );
    await client.send<dynamic, dynamic>(
      Request('GET', Uri.parse('/users'), base,
          parameters: const {'page': 2, 'tag': ['a', 'b']},
          headers: const {'X-Trace': 'abc'}),
    );
    describe('2. parameters', probe, got);

    // 3. a 404
    probe = Probe();
    client = ChopperClient(
      baseUrl: base,
      client: MockClient((request) async => http.Response('{"error":"gone"}', 404)),
      interceptors: [probe],
      converter: const JsonConverter(),
    );
    try {
      final response = await client.send<dynamic, dynamic>(
        Request('GET', Uri.parse('/missing'), base),
      );
      print('3. send returned: status=${response.statusCode} '
          'isSuccessful=${response.isSuccessful} body=${response.body} '
          'error=${response.error} errorType=${response.error.runtimeType}');
    } on Object catch (error) {
      print('3. send threw ${error.runtimeType}: $error');
    }
    describe('3. 404', probe, null);

    // 4. a broken connection
    probe = Probe();
    client = ChopperClient(
      baseUrl: base,
      client: MockClient((request) async => throw http.ClientException('closed', request.url)),
      interceptors: [probe],
    );
    try {
      await client.send<dynamic, dynamic>(Request('GET', Uri.parse('/flaky'), base));
    } on Object catch (error) {
      print('4. send threw ${error.runtimeType}: $error');
    }
    describe('4. connection', probe, null);

    // 5. an aborted call
    probe = Probe();
    final abort = Completer<void>();
    client = ChopperClient(
      baseUrl: base,
      client: MockClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return http.Response('late', 200);
      }),
      interceptors: [probe],
    );
    try {
      final call = client.send<dynamic, dynamic>(
        Request('GET', Uri.parse('/slow'), base, abortTrigger: abort.future),
      );
      Future<void>.delayed(const Duration(milliseconds: 20), abort.complete);
      await call;
    } on Object catch (error) {
      print('5. send threw ${error.runtimeType}: $error');
    }
    describe('5. abort', probe, null);

    // 6. multipart
    probe = Probe();
    got = null;
    client = ChopperClient(
      baseUrl: base,
      client: MockClient((request) async {
        got = request;
        return http.Response('{}', 200);
      }),
      interceptors: [probe],
    );
    await client.send<dynamic, dynamic>(
      Request('POST', Uri.parse('/upload'), base, multipart: true, parts: [
        const PartValue<String>('note', 'a photo of a cat'),
        PartValueFile<List<int>>('photo', utf8.encode('not really a png')),
      ]),
    );
    describe('6. multipart', probe, got);
    final part = probe.seen?.parts.last;
    print('6. part type=${part.runtimeType} name=${part?.name} '
        'valueType=${part?.value.runtimeType}');
  });
}
