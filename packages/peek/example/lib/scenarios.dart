import 'dart:typed_data';

import 'package:dio/dio.dart';

/// One thing the example can do to the network, so Peek has something real
/// to show.
final class Scenario {
  /// Creates a scenario named [name].
  const Scenario({required this.name, required this.detail, required this.run});

  /// What the button reads.
  final String name;

  /// What it is worth looking at in Peek afterwards.
  final String detail;

  /// Makes the call. Failures are part of the point, so they are left to
  /// the caller to swallow.
  final Future<void> Function(Dio dio) run;
}

const String _httpbin = 'https://httpbin.org';
const String _placeholder = 'https://jsonplaceholder.typicode.com';

/// Everything the example can do, in the order it is worth trying.
const List<Scenario> scenarios = [
  Scenario(
    name: 'GET JSON',
    detail: 'A small object, shown as a tree',
    run: _getJson,
  ),
  Scenario(
    name: 'POST JSON',
    detail: 'A body going out as well as coming back',
    run: _postJson,
  ),
  Scenario(
    name: 'Upload a file',
    detail: 'Multipart: the file is described, never read',
    run: _upload,
  ),
  Scenario(
    name: 'Not found',
    detail: '404, with the body the server sent with it',
    run: _notFound,
  ),
  Scenario(
    name: 'Server error',
    detail: '500, in the colour of a server error',
    run: _serverError,
  ),
  Scenario(
    name: 'Timeout',
    detail: 'Given one second for a five-second answer',
    run: _timeout,
  ),
  Scenario(
    name: 'Cancelled',
    detail: 'Called off in flight; not an error',
    run: _cancelled,
  ),
  Scenario(
    name: 'Redirected',
    detail: 'Two hops, listed on the Overview tab',
    run: _redirected,
  ),
  Scenario(name: 'An image', detail: 'Bytes, shown as a picture', run: _image),
  Scenario(
    name: 'A big body',
    detail: 'Around a megabyte of JSON, truncated to the limit',
    run: _bigBody,
  ),
  Scenario(
    name: 'A secret header',
    detail: 'Authorization, shown as sent until a policy masks it',
    run: _secret,
  ),
  Scenario(
    name: 'Many headers',
    detail: 'Enough to filter, and one name carrying three values',
    run: _manyHeaders,
  ),
];

Future<void> _getJson(Dio dio) => dio.get<dynamic>('$_placeholder/users/1');

Future<void> _postJson(Dio dio) => dio.post<dynamic>(
  '$_httpbin/post',
  data: const {'sku': 'A-1', 'quantity': 2},
);

Future<void> _upload(Dio dio) => dio.post<dynamic>(
  '$_httpbin/post',
  data: FormData.fromMap({
    'note': 'a photo of a cat',
    'photo': MultipartFile.fromBytes(Uint8List(64 * 1024), filename: 'cat.png'),
  }),
);

Future<void> _notFound(Dio dio) => dio.get<dynamic>('$_httpbin/status/404');

Future<void> _serverError(Dio dio) => dio.get<dynamic>('$_httpbin/status/500');

Future<void> _timeout(Dio dio) => dio.get<dynamic>(
  '$_httpbin/delay/5',
  options: Options(receiveTimeout: const Duration(seconds: 1)),
);

Future<void> _cancelled(Dio dio) {
  final token = CancelToken();
  Future<void>.delayed(
    const Duration(milliseconds: 400),
    () => token.cancel('the user changed their mind'),
  );
  return dio.get<dynamic>('$_httpbin/delay/5', cancelToken: token);
}

Future<void> _redirected(Dio dio) => dio.get<dynamic>('$_httpbin/redirect/2');

Future<void> _image(Dio dio) => dio.get<dynamic>(
  '$_httpbin/image/png',
  options: Options(responseType: ResponseType.bytes),
);

Future<void> _bigBody(Dio dio) => dio.get<dynamic>('$_placeholder/photos');

Future<void> _manyHeaders(Dio dio) => dio.get<dynamic>(
  '$_httpbin/headers',
  options: Options(
    headers: const {
      'Accept-Language': 'en-GB, en;q=0.9, ru;q=0.8',
      'Cache-Control': 'no-cache',
      'If-None-Match': 'W/"a1b2c3"',
      'X-Client-Build': '2026.9.1+482',
      'X-Client-Platform': 'ios',
      'X-Correlation-Id': 'c0ffee-1234-5678',
      'X-Feature-Flags': 'peek,tree,wrap',
      'X-Request-Start': 't=1757745600',
      // One name, three values: sent as three lines, and read back as one
      // row per value.
      'X-Peek-Tag': ['alpha', 'beta', 'gamma'],
    },
  ),
);

Future<void> _secret(Dio dio) => dio.get<dynamic>(
  '$_httpbin/bearer',
  options: Options(
    headers: const {'Authorization': 'Bearer a-token-nobody-should-see'},
  ),
);
