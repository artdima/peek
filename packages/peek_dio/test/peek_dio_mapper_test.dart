import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';
import 'package:peek_dio/peek_dio.dart';

RequestOptions options({
  String method = 'GET',
  String path = 'https://api.example.com/users',
  Object? data,
  Map<String, dynamic>? headers,
  String? contentType,
  ResponseType responseType = ResponseType.json,
}) => RequestOptions(
  path: path,
  method: method,
  data: data,
  headers: headers,
  contentType: contentType,
  responseType: responseType,
);

Response<dynamic> response({
  int? statusCode = 200,
  String? statusMessage = 'OK',
  Object? data,
  Map<String, List<String>> headers = const {},
  List<RedirectRecord> redirects = const [],
  ResponseType responseType = ResponseType.json,
}) => Response<dynamic>(
  requestOptions: options(responseType: responseType),
  statusCode: statusCode,
  statusMessage: statusMessage,
  data: data,
  headers: Headers.fromMap(headers),
  redirects: redirects,
);

void main() {
  group('request', () {
    test('carries the method, the address and who reported it', () {
      final mapped = PeekDioMapper.request(
        options(method: 'post', path: 'https://api.example.com/users?page=2'),
      );

      expect(mapped.method, 'POST');
      expect(mapped.uri.host, 'api.example.com');
      expect(mapped.queryParameters, {
        'page': ['2'],
      });
      expect(mapped.extra['client'], 'dio');
    });

    test('reads a header whatever Dio was given to hold it', () {
      final mapped = PeekDioMapper.request(
        options(
          headers: {
            'Accept': 'application/json',
            'X-Retry': 3,
            'X-Tag': ['a', 'b'],
          },
        ),
      );

      expect(mapped.headers['Accept'], 'application/json');
      expect(mapped.headers['X-Retry'], '3');
      expect(mapped.headers.valuesOf('X-Tag'), ['a', 'b']);
    });
  });

  group('request body', () {
    test('is empty when there is nothing to send', () {
      expect(PeekDioMapper.requestBody(options()), isA<PeekEmptyBody>());
    });

    test('is the JSON a map or a list came from', () {
      final map = PeekDioMapper.requestBody(options(data: {'sku': 'A-1'}));
      final list = PeekDioMapper.requestBody(options(data: [1, 2]));

      expect((map as PeekTextBody).text, '{"sku":"A-1"}');
      expect(map.contentType, PeekMediaType.json);
      expect((list as PeekTextBody).text, '[1,2]');
    });

    test('keeps text as text, under the type that was declared', () {
      final body = PeekDioMapper.requestBody(
        options(
          data: 'sku=A-1',
          contentType: 'application/x-www-form-urlencoded',
        ),
      );

      expect((body as PeekTextBody).text, 'sku=A-1');
      expect(body.contentType, PeekMediaType.formUrlEncoded);
    });

    test('keeps bytes as bytes', () {
      final body = PeekDioMapper.requestBody(
        options(data: Uint8List.fromList([1, 2, 3])),
      );

      expect((body as PeekBytesBody).bytes, [1, 2, 3]);
    });

    test('reads a list of numbers as Dio would send it', () {
      final json = PeekDioMapper.requestBody(options(data: <int>[4, 5]));
      final binary = PeekDioMapper.requestBody(
        options(data: <int>[4, 5], contentType: 'application/octet-stream'),
      );

      expect((json as PeekTextBody).text, '[4,5]');
      expect((binary as PeekBytesBody).bytes, [4, 5]);
    });

    test('describes a form without reading a file', () {
      final form = FormData.fromMap({
        'note': 'hello',
        'photo': MultipartFile.fromBytes([1, 2, 3, 4], filename: 'ann.png'),
      });

      final body = PeekDioMapper.requestBody(options(data: form));

      expect(body, isA<PeekFormBody>());
      expect((body as PeekFormBody).fields, [
        const PeekFormField('note', 'hello'),
      ]);
      expect(body.files.single.name, 'photo');
      expect(body.files.single.filename, 'ann.png');
      expect(body.files.single.size, 4);
    });

    test('says a stream was never buffered', () {
      final body = PeekDioMapper.requestBody(
        options(
          data: Stream<List<int>>.fromIterable([
            [1],
          ]),
        ),
      );

      expect(
        (body as PeekUnavailableBody).reason,
        PeekBodyUnavailableReason.streamed,
      );
    });

    test('says nothing about what it cannot read', () {
      final body = PeekDioMapper.requestBody(options(data: Object()));

      expect(
        (body as PeekUnavailableBody).reason,
        PeekBodyUnavailableReason.notCaptured,
      );
    });
  });

  group('response', () {
    test('carries the status, the headers and the hops', () {
      final mapped = PeekDioMapper.response(
        response(
          headers: {
            'content-type': ['application/json'],
            'set-cookie': ['a=1', 'b=2'],
          },
          redirects: [
            RedirectRecord(301, 'GET', Uri.parse('https://example.com/new')),
          ],
        ),
      );

      expect(mapped.statusCode, 200);
      expect(mapped.statusMessage, 'OK');
      expect(mapped.headers.valuesOf('Set-Cookie'), ['a=1', 'b=2']);
      expect(mapped.redirects.single.statusCode, 301);
      expect(mapped.redirects.single.location.path, '/new');
    });

    test('reads a status Dio never got as zero', () {
      final mapped = PeekDioMapper.response(
        response(statusCode: null, statusMessage: '  '),
      );

      expect(mapped.statusCode, 0);
      expect(mapped.statusMessage, isNull);
    });
  });

  group('response body', () {
    test('is the JSON the decoded data came from', () {
      final body = PeekDioMapper.responseBody(response(data: {'id': 7}));

      expect((body as PeekTextBody).text, '{"id":7}');
    });

    test('keeps a JSON response that arrived as text as it is', () {
      final body = PeekDioMapper.responseBody(response(data: 'not json'));

      expect((body as PeekTextBody).text, 'not json');
    });

    test('keeps plain text under the type the server declared', () {
      final body = PeekDioMapper.responseBody(
        response(
          data: 'hello',
          responseType: ResponseType.plain,
          headers: {
            'content-type': ['text/plain; charset=utf-8'],
          },
        ),
      );

      expect((body as PeekTextBody).text, 'hello');
      expect(body.contentType?.mimeType, 'text/plain');
    });

    test('keeps bytes as bytes', () {
      final body = PeekDioMapper.responseBody(
        response(
          data: Uint8List.fromList([9, 8]),
          responseType: ResponseType.bytes,
        ),
      );

      expect((body as PeekBytesBody).bytes, [9, 8]);
    });

    test('says a streamed response was never buffered', () {
      final body = PeekDioMapper.responseBody(
        response(data: 'ignored', responseType: ResponseType.stream),
      );

      expect(
        (body as PeekUnavailableBody).reason,
        PeekBodyUnavailableReason.streamed,
      );
    });

    test('is empty when nothing came back', () {
      expect(PeekDioMapper.responseBody(response()), isA<PeekEmptyBody>());
    });

    test('says so when what came back will not encode', () {
      final body = PeekDioMapper.responseBody(response(data: Object()));

      expect(
        (body as PeekUnavailableBody).reason,
        PeekBodyUnavailableReason.unreadable,
      );
    });
  });

  group('failure', () {
    test('maps every category Dio has', () {
      expect(
        {
          for (final type in DioExceptionType.values)
            type: PeekDioMapper.failureKind(type),
        },
        {
          DioExceptionType.connectionTimeout: PeekFailureKind.timeout,
          DioExceptionType.sendTimeout: PeekFailureKind.timeout,
          DioExceptionType.receiveTimeout: PeekFailureKind.timeout,
          DioExceptionType.transformTimeout: PeekFailureKind.timeout,
          DioExceptionType.badCertificate: PeekFailureKind.badCertificate,
          DioExceptionType.badResponse: PeekFailureKind.badResponse,
          DioExceptionType.cancel: PeekFailureKind.cancelled,
          DioExceptionType.connectionError: PeekFailureKind.connection,
          DioExceptionType.unknown: PeekFailureKind.unknown,
        },
      );
    });

    test('keeps the message, the cause and where it was raised', () {
      final trace = StackTrace.current;
      final mapped = PeekDioMapper.failure(
        DioException(
          requestOptions: options(),
          type: DioExceptionType.connectionError,
          message: 'Connection refused',
          error: const SocketMessage('refused'),
          stackTrace: trace,
        ),
      );

      expect(mapped.kind, PeekFailureKind.connection);
      expect(mapped.message, 'Connection refused');
      expect(mapped.details, const SocketMessage('refused'));
      expect(mapped.stackTrace, trace);
    });

    test('falls back to the cause, then to the category', () {
      final cause = PeekDioMapper.failure(
        DioException(
          requestOptions: options(),
          message: '   ',
          error: const SocketMessage('broken pipe'),
        ),
      );
      final bare = PeekDioMapper.failure(
        DioException(requestOptions: options(), type: DioExceptionType.cancel),
      );

      expect(cause.message, 'SocketMessage(broken pipe)');
      expect(bare.message, 'cancel');
    });
  });
}

/// Stands in for a platform error object, which a test cannot raise.
class SocketMessage {
  const SocketMessage(this.reason);

  final String reason;

  @override
  bool operator ==(Object other) =>
      other is SocketMessage && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'SocketMessage($reason)';
}
