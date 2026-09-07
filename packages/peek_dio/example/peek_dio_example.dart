// Everything Peek needs to show the calls Dio makes: one interceptor on
// the client. This is a Dart script so it can run anywhere; in an app the
// screen opens with `showPeek(context, peek: peek)`, and the full app is
// under `packages/peek/example`.

import 'package:dio/dio.dart';
import 'package:peek/core.dart';
import 'package:peek_dio/peek_dio.dart';

/// Records one call and reads it back from the store.
Future<void> main() async {
  // Masking is opt-in; the default policy covers the usual secret names.
  final peek = Peek(
    options: const PeekOptions(redaction: PeekRedactionPolicy()),
  );
  final dio = Dio()..interceptors.add(PeekDioInterceptor(peek));

  await dio.get<dynamic>(
    'https://httpbin.org/bearer',
    options: Options(headers: {'Authorization': 'Bearer not-for-the-log'}),
  );

  final entry = peek.store.entries.single;
  assert(entry.statusCode == 200, 'the call was recorded as it went');
  assert(
    entry.request.headers['authorization'] == '*****',
    'the policy masked the token before it was stored',
  );

  peek.dispose();
}
