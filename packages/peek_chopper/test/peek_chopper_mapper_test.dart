import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:chopper/chopper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:peek/core.dart';
import 'package:peek_chopper/peek_chopper.dart';

void main() {
  final base = Uri.parse('https://api.example.com');

  Request requestWith({
    String method = 'POST',
    String path = '/orders',
    Object? body,
    Map<String, String> headers = const {},
    bool multipart = false,
    List<PartValue<dynamic>> parts = const [],
    Object? tag,
  }) => Request(
    method,
    Uri.parse(path),
    base,
    body: body,
    headers: headers,
    multipart: multipart,
    parts: parts,
    tag: tag,
  );

  Response<dynamic> responseWith(
    http.BaseResponse base, {
    Object? body,
    Object? error,
  }) => Response<dynamic>(base, body, error: error);

  group('a request', () {
    test('is described by what goes on the wire', () {
      final mapped = PeekChopperMapper.request(
        requestWith(
          method: 'post',
          path: '/orders?page=2',
          headers: const {'X-Trace': 'abc'},
          body: '{"sku":"A-1"}',
        ),
      );

      expect(mapped.method, 'POST');
      expect(mapped.uri, Uri.parse('$base/orders?page=2'));
      expect(mapped.headers['x-trace'], 'abc');
      expect(mapped.extra['client'], 'chopper');
      expect(mapped.body, isA<PeekTextBody>());
    });

    test('carries the tag when the call was given one', () {
      expect(PeekChopperMapper.request(requestWith()).extra['tag'], isNull);
      expect(
        PeekChopperMapper.request(requestWith(tag: 'checkout')).extra['tag'],
        'checkout',
      );
    });
  });

  group('a request body', () {
    PeekBody bodyOf(Object? body, {Map<String, String> headers = const {}}) =>
        PeekChopperMapper.requestBody(
          requestWith(body: body, headers: headers),
        );

    test('is empty when there is none', () {
      expect(bodyOf(null), const PeekBody.empty());
    });

    test('keeps text as text, with the declared type', () {
      final body = bodyOf(
        '{"sku":"A-1"}',
        headers: const {'content-type': 'application/json'},
      );

      expect(body, isA<PeekTextBody>());
      expect((body as PeekTextBody).text, '{"sku":"A-1"}');
      expect(body.contentType?.isJson, isTrue);
    });

    test('keeps bytes as bytes, however they were handed over', () {
      final typed = bodyOf(Uint8List.fromList(const [1, 2, 3]));
      final plain = bodyOf(const <int>[1, 2, 3]);

      expect((typed as PeekBytesBody).bytes, const [1, 2, 3]);
      expect((plain as PeekBytesBody).bytes, const [1, 2, 3]);
    });

    test('leaves a stream alone and says so', () {
      final body = bodyOf(const Stream<List<int>>.empty());

      expect(body, isA<PeekUnavailableBody>());
      expect(
        (body as PeekUnavailableBody).reason,
        PeekBodyUnavailableReason.streamed,
      );
    });

    test('writes an unconverted value as the JSON it stands for', () {
      final body = bodyOf(const {'sku': 'A-1'});

      expect((body as PeekTextBody).text, '{"sku":"A-1"}');
    });
  });

  group('multipart', () {
    test('describes every part, and opens no file', () {
      final body = PeekChopperMapper.requestBody(
        requestWith(
          multipart: true,
          parts: [
            const PartValue<String>('note', 'a photo of a cat'),
            const PartValue<int>('count', 2),
            PartValueFile<List<int>>('bytes', utf8.encode('not a png')),
            const PartValueFile<String>('path', '/tmp/cat.png'),
            PartValue<http.MultipartFile>(
              'photo',
              http.MultipartFile.fromString('photo', 'x', filename: 'cat.txt'),
            ),
          ],
        ),
      );

      final form = body as PeekFormBody;
      expect(form.fields, [
        const PeekFormField('note', 'a photo of a cat'),
        const PeekFormField('count', '2'),
      ]);
      expect(form.files.map((file) => file.name), ['bytes', 'path', 'photo']);
      expect(form.files[0].size, 9);
      expect(form.files[1].filename, '/tmp/cat.png');
      expect(form.files[1].size, isNull);
      expect(form.files[2].filename, 'cat.txt');
      expect(form.files[2].contentType?.isText, isTrue);
      expect(form.contentType, PeekMediaType.multipartFormData);
    });
  });

  group('a response', () {
    test('is described by the answer under it', () {
      final mapped = PeekChopperMapper.response(
        responseWith(
          http.Response(
            '{"id":7}',
            200,
            headers: const {'content-type': 'application/json'},
            reasonPhrase: 'OK',
          ),
          body: const {'id': 7},
        ),
      );

      expect(mapped.statusCode, 200);
      expect(mapped.statusMessage, 'OK');
      expect(mapped.headers['content-type'], 'application/json');
      expect((mapped.body as PeekTextBody).text, '{"id":7}');
    });

    test('keeps the payload of a failed call, which has no converted body', () {
      final mapped = PeekChopperMapper.response(
        responseWith(
          http.Response('{"error":"gone"}', 404),
          error: '{"error":"gone"}',
        ),
      );

      expect(mapped.statusCode, 404);
      expect((mapped.body as PeekTextBody).text, '{"error":"gone"}');
    });

    test('shows binary as bytes and an empty answer as empty', () {
      final image = PeekChopperMapper.responseBody(
        responseWith(
          http.Response.bytes(
            const [0x89, 0x50, 0x4e, 0x47],
            200,
            headers: const {'content-type': 'image/png'},
          ),
        ),
      );
      final nothing = PeekChopperMapper.responseBody(
        responseWith(http.Response('', 204)),
      );

      expect((image as PeekBytesBody).bytes, const [0x89, 0x50, 0x4e, 0x47]);
      expect(nothing, const PeekBody.empty());
    });

    test('never drains a streamed answer', () {
      final body = PeekChopperMapper.responseBody(
        responseWith(
          http.StreamedResponse(const Stream<List<int>>.empty(), 200),
        ),
      );

      expect(
        (body as PeekUnavailableBody).reason,
        PeekBodyUnavailableReason.streamed,
      );
    });
  });

  group('a failure', () {
    test('tells cancellation from a broken connection', () {
      expect(
        PeekChopperMapper.failureKind(http.RequestAbortedException(base)),
        PeekFailureKind.cancelled,
      );
      expect(
        PeekChopperMapper.failureKind(http.ClientException('closed', base)),
        PeekFailureKind.connection,
      );
    });

    test('maps the rest of what a chain can throw', () {
      expect(
        PeekChopperMapper.failureKind(TimeoutException('too slow')),
        PeekFailureKind.timeout,
      );
      expect(
        PeekChopperMapper.failureKind(
          ChopperHttpException(responseWith(http.Response('no', 500))),
        ),
        PeekFailureKind.badResponse,
      );
      expect(
        PeekChopperMapper.failureKind(StateError('something else')),
        PeekFailureKind.unknown,
      );
    });

    test('keeps the error itself, and the answer it came with', () {
      final error = ChopperHttpException(
        responseWith(http.Response('{"error":"gone"}', 404)),
      );
      final failure = PeekChopperMapper.failure(error, StackTrace.current);

      expect(failure.details, same(error));
      expect(failure.message, isNotEmpty);
      expect(failure.stackTrace, isNotNull);
      expect(PeekChopperMapper.responseOf(error)?.statusCode, 404);
      expect(
        PeekChopperMapper.responseOf(http.ClientException('closed')),
        isNull,
      );
    });
  });
}
