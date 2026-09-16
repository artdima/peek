// Everything Peek needs to show the calls a package:http client makes: one
// wrapping client. This is a Dart script so it can run anywhere; in an app
// the screen opens with `showPeek(context, peek: peek)`, and the full app is
// under `packages/peek/example`.

import 'package:http/http.dart' as http;
import 'package:peek/core.dart';
import 'package:peek_http/peek_http.dart';

/// Records one call and reads it back from the store.
Future<void> main() async {
  // Masking is opt-in; the default policy covers the usual secret names.
  final peek = Peek(
    options: const PeekOptions(redaction: PeekRedactionPolicy()),
  );
  final client = PeekHttpClient(peek, http.Client());

  final response = await client.get(
    Uri.parse('https://httpbin.org/bearer'),
    headers: const {'Authorization': 'Bearer not-for-the-log'},
  );

  final entry = peek.store.entries.single;
  assert(
    entry.statusCode == response.statusCode,
    'the call was recorded as it went',
  );
  assert(
    entry.request.headers['authorization'] == '*****',
    'the policy masked the token before it was stored',
  );

  client.close();
  peek.dispose();
}
