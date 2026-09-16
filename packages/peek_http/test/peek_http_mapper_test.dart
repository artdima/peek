import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:peek/core.dart';
import 'package:peek_http/peek_http.dart';

final class Opaque extends http.BaseRequest {
  Opaque() : super('GET', Uri.parse('https://api.example.com'));
}

void main() {
  final url = Uri.parse('https://api.example.com/orders?page=2');

  http.StreamedResponse responseWith({
    int statusCode = 200,
    Map<String, String> headers = const {},
    String? reasonPhrase,
  }) => http.StreamedResponse(
    const Stream.empty(),
    statusCode,
    headers: headers,
    reasonPhrase: reasonPhrase,
  );

  group('a request', () {
    test('is described by what the app handed over', () {
      final request =
          http.Request('post', url)
            ..headers['X-Trace'] = 'abc'
            ..body = '{"sku":"A-1"}';

      final mapped = PeekHttpMapper.request(request);

      expect(mapped.method, 'POST');
      expect(mapped.uri, url);
      expect(mapped.headers['x-trace'], 'abc');
      expect(mapped.extra['client'], 'http');
      expect(mapped.body, isA<PeekTextBody>());
      expect(request.finalized, isFalse);
    });
  });

  group('a request body', () {
    test('is empty when nothing was set', () {
      expect(
        PeekHttpMapper.requestBody(http.Request('GET', url)),
        const PeekBody.empty(),
      );
    });

    test('keeps text as text, with the type the request declares', () {
      final request =
          http.Request('POST', url)
            ..headers['content-type'] = 'application/json'
            ..body = '{"sku":"A-1"}';

      final body = PeekHttpMapper.requestBody(request) as PeekTextBody;

      expect(body.text, '{"sku":"A-1"}');
      expect(body.contentType?.isJson, isTrue);
      expect(body.size, 13);
    });

    test('keeps a form as the text that goes out', () {
      final request = http.Request('POST', url)..bodyFields = {'q': 'a b'};

      final body = PeekHttpMapper.requestBody(request) as PeekTextBody;

      expect(body.text, 'q=a+b');
      expect(body.contentType?.isFormUrlEncoded, isTrue);
    });

    test('keeps bytes that are not text as bytes', () {
      final request =
          http.Request('POST', url)
            ..headers['content-type'] = 'image/png'
            ..bodyBytes = [137, 80, 78, 71];

      final body = PeekHttpMapper.requestBody(request) as PeekBytesBody;

      expect(body.bytes, [137, 80, 78, 71]);
      expect(body.contentType?.isImage, isTrue);
    });

    test('falls back to bytes when untyped bytes are not UTF-8', () {
      final request = http.Request('POST', url)..bodyBytes = [0xff, 0xfe];

      expect(PeekHttpMapper.requestBody(request), isA<PeekBytesBody>());
    });

    test('survives a charset the request cannot decode', () {
      final request =
          http.Request('POST', url)
            ..bodyBytes = utf8.encode('hi')
            ..headers['content-type'] = 'text/plain; charset=no-such-charset';

      final body = PeekHttpMapper.requestBody(request) as PeekTextBody;

      expect(body.text, 'hi');
    });

    test('describes multipart without finalizing it or reading a file', () {
      var read = false;
      final content = StreamController<List<int>>(onListen: () => read = true);
      // Nobody listens, so a close would wait for its done event forever.
      addTearDown(() => unawaited(content.close()));
      final file = http.MultipartFile(
        'photo',
        content.stream,
        3,
        filename: 'cat.png',
        contentType: http.MediaType('image', 'png'),
      );
      final request =
          http.MultipartRequest('POST', url)
            ..fields['name'] = 'Tom'
            ..files.add(file);

      final body = PeekHttpMapper.requestBody(request) as PeekFormBody;

      expect(body.contentType, PeekMediaType.multipartFormData);
      expect(body.fields, [const PeekFormField('name', 'Tom')]);
      expect(body.files, hasLength(1));
      expect(body.files.single.name, 'photo');
      expect(body.files.single.filename, 'cat.png');
      expect(body.files.single.contentType?.isImage, isTrue);
      expect(body.files.single.size, 3);
      expect(request.finalized, isFalse);
      expect(file.isFinalized, isFalse);
      expect(read, isFalse);
    });

    test('is unavailable for a streamed request, with its declared size', () {
      final request =
          http.StreamedRequest('POST', url)
            ..headers['content-type'] = 'application/json'
            ..contentLength = 42;

      final body = PeekHttpMapper.requestBody(request) as PeekUnavailableBody;

      expect(body.reason, PeekBodyUnavailableReason.streamed);
      expect(body.size, 42);
      expect(body.contentType?.isJson, isTrue);
    });

    test('is not captured for a request of a shape it does not know', () {
      final body = PeekHttpMapper.requestBody(Opaque()) as PeekUnavailableBody;

      expect(body.reason, PeekBodyUnavailableReason.notCaptured);
    });
  });

  group('a response', () {
    test('carries status, reason and headers', () {
      final mapped = PeekHttpMapper.response(
        responseWith(
          statusCode: 404,
          reasonPhrase: ' Not Found ',
          headers: const {'content-type': 'application/json'},
        ),
        const PeekBody.empty(),
      );

      expect(mapped.statusCode, 404);
      expect(mapped.statusMessage, 'Not Found');
      expect(mapped.headers['content-type'], 'application/json');
      expect(mapped.redirects, isEmpty);
    });

    test('has no reason when the server sent a blank one', () {
      final mapped = PeekHttpMapper.response(
        responseWith(reasonPhrase: '  '),
        const PeekBody.empty(),
      );

      expect(mapped.statusMessage, isNull);
    });

    test('keeps two Set-Cookie values two, dates and all', () {
      const expiring = 'a=1; Expires=Wed, 21 Oct 2026 07:28:00 GMT';
      final mapped = PeekHttpMapper.response(
        responseWith(headers: const {'set-cookie': '$expiring,b=2'}),
        const PeekBody.empty(),
      );

      expect(mapped.headers.valuesOf('set-cookie'), [expiring, 'b=2']);
    });
  });

  group('a response body', () {
    PeekBody bodyOf(List<int> captured, {int? received, String? contentType}) =>
        PeekHttpMapper.responseBody(
          responseWith(
            headers: {if (contentType != null) 'content-type': contentType},
          ),
          captured,
          received: received ?? captured.length,
        );

    test('is empty when no bytes arrived', () {
      expect(bodyOf(const []), const PeekBody.empty());
    });

    test('is text when it decodes, sized by what arrived', () {
      final body =
          bodyOf(utf8.encode('{"id":1}'), contentType: 'application/json')
              as PeekTextBody;

      expect(body.text, '{"id":1}');
      expect(body.size, 8);
      expect(body.isTruncated, isFalse);
    });

    test('is a truncated prefix when only part of it was kept', () {
      final body =
          bodyOf(
                utf8.encode('hello'),
                received: 5000,
                contentType: 'text/plain',
              )
              as PeekTextBody;

      expect(body.text, 'hello');
      expect(body.size, 5000);
      expect(body.isTruncated, isTrue);
    });

    test('drops a character cut in half at the end of a prefix', () {
      final bytes = utf8.encode('añ');
      final body =
          bodyOf(bytes.sublist(0, bytes.length - 1), received: 100)
              as PeekTextBody;

      expect(body.text, 'a');
      expect(body.size, 100);
    });

    test('keeps bytes whole when they are not text', () {
      final body =
          bodyOf([137, 80, 78, 71], contentType: 'image/png') as PeekBytesBody;

      expect(body.bytes, Uint8List.fromList([137, 80, 78, 71]));
    });

    test('keeps the size alone when nothing was kept', () {
      final body = bodyOf(const [], received: 10, contentType: 'text/plain');

      expect(body.size, 10);
      expect(body.isTruncated, isTrue);
    });
  });

  group('a failure', () {
    test('is sorted into a kind, abort before connection', () {
      expect(
        PeekHttpMapper.failureKind(http.RequestAbortedException(url)),
        PeekFailureKind.cancelled,
      );
      expect(
        PeekHttpMapper.failureKind(TimeoutException('slow')),
        PeekFailureKind.timeout,
      );
      expect(
        PeekHttpMapper.failureKind(http.ClientException('refused', url)),
        PeekFailureKind.connection,
      );
      expect(
        PeekHttpMapper.failureKind(StateError('odd')),
        PeekFailureKind.unknown,
      );
    });

    test('keeps the error and its trace', () {
      final error = http.ClientException('refused', url);
      final trace = StackTrace.current;

      final failure = PeekHttpMapper.failure(error, trace);

      expect(failure.kind, PeekFailureKind.connection);
      expect(failure.message, '$error');
      expect(failure.details, same(error));
      expect(failure.stackTrace, same(trace));
    });
  });
}
