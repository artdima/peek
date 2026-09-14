// Everything Peek needs to show the calls Chopper makes: one interceptor in
// the client's chain. This is a Dart script so it can run anywhere; in an
// app the screen opens with `showPeek(context, peek: peek)`, and the full
// app is under `packages/peek/example`.

import 'package:chopper/chopper.dart';
import 'package:peek/core.dart';
import 'package:peek_chopper/peek_chopper.dart';

/// Records one call and reads it back from the store.
Future<void> main() async {
  // Masking is opt-in; the default policy covers the usual secret names.
  final peek = Peek(
    options: const PeekOptions(redaction: PeekRedactionPolicy()),
  );
  final base = Uri.parse('https://httpbin.org');
  final client = ChopperClient(
    baseUrl: base,
    interceptors: [PeekChopperInterceptor(peek)],
  );

  await client.send<dynamic, dynamic>(
    Request(
      'GET',
      Uri.parse('/bearer'),
      base,
      headers: const {'Authorization': 'Bearer not-for-the-log'},
    ),
  );

  final entry = peek.store.entries.single;
  assert(entry.statusCode == 200, 'the call was recorded as it went');
  assert(
    entry.request.headers['authorization'] == '*****',
    'the policy masked the token before it was stored',
  );

  client.dispose();
  peek.dispose();
}
