import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// One thing the `package:http` route can do to the network.
final class HttpScenario {
  /// Creates a scenario named [name].
  const HttpScenario({
    required this.name,
    required this.detail,
    required this.run,
  });

  /// What the button reads.
  final String name;

  /// What it is worth looking at in Peek afterwards.
  final String detail;

  /// Makes the call. Failures are part of the point, so they are left to
  /// the caller to swallow.
  final Future<void> Function(http.Client client) run;
}

const String _httpbin = 'https://httpbin.org';
const String _placeholder = 'https://jsonplaceholder.typicode.com';

/// Everything the `package:http` route can do, in the order it is worth
/// trying.
const List<HttpScenario> httpScenarios = [
  HttpScenario(
    name: 'GET JSON',
    detail: 'A small object, shown as a tree',
    run: _getJson,
  ),
  HttpScenario(
    name: 'POST JSON',
    detail: 'The body as the app wrote it',
    run: _postJson,
  ),
  HttpScenario(
    name: 'Upload a file',
    detail: 'Multipart: the file is described, never read',
    run: _upload,
  ),
  HttpScenario(
    name: 'Not found',
    detail: '404 — an answer, not a failure',
    run: _notFound,
  ),
  HttpScenario(
    name: 'Server error',
    detail: '500, in the colour of a server error',
    run: _serverError,
  ),
  HttpScenario(
    name: 'Called off',
    detail: 'Aborted in flight; not an error',
    run: _aborted,
  ),
  HttpScenario(
    name: 'Body read later',
    detail: 'Pending until the app reads the body, three seconds on',
    run: _readLater,
  ),
  HttpScenario(
    name: 'Redirected',
    detail: 'Followed by the client; the final answer is what is seen',
    run: _redirected,
  ),
  HttpScenario(
    name: 'An image',
    detail: 'Bytes, shown as a picture',
    run: _image,
  ),
  HttpScenario(
    name: 'A big body',
    detail: 'Around a megabyte of JSON, truncated to the limit',
    run: _bigBody,
  ),
  HttpScenario(
    name: 'A secret header',
    detail: 'Authorization, shown as sent until a policy masks it',
    run: _secret,
  ),
];

Future<void> _getJson(http.Client client) =>
    client.get(Uri.parse('$_placeholder/users/1'));

Future<void> _postJson(http.Client client) => client.post(
  Uri.parse('$_httpbin/post'),
  headers: const {'content-type': 'application/json'},
  body: '{"sku":"A-1","quantity":2}',
);

Future<void> _upload(http.Client client) async {
  final request =
      http.MultipartRequest('POST', Uri.parse('$_httpbin/post'))
        ..fields['note'] = 'a photo of a cat'
        ..files.add(
          http.MultipartFile.fromBytes(
            'photo',
            Uint8List(64 * 1024),
            filename: 'cat.png',
          ),
        );
  await http.Response.fromStream(await client.send(request));
}

Future<void> _notFound(http.Client client) =>
    client.get(Uri.parse('$_httpbin/status/404'));

Future<void> _serverError(http.Client client) =>
    client.get(Uri.parse('$_httpbin/status/500'));

Future<void> _aborted(http.Client client) async {
  final request = http.AbortableRequest(
    'GET',
    Uri.parse('$_httpbin/delay/5'),
    abortTrigger: Future<void>.delayed(const Duration(milliseconds: 400)),
  );
  await http.Response.fromStream(await client.send(request));
}

Future<void> _readLater(http.Client client) async {
  final response = await client.send(
    http.Request('GET', Uri.parse('$_httpbin/json')),
  );
  await Future<void>.delayed(const Duration(seconds: 3));
  await response.stream.drain<void>();
}

Future<void> _redirected(http.Client client) =>
    client.get(Uri.parse('$_httpbin/redirect/2'));

Future<void> _image(http.Client client) =>
    client.get(Uri.parse('$_httpbin/image/png'));

Future<void> _bigBody(http.Client client) =>
    client.get(Uri.parse('$_placeholder/photos'));

Future<void> _secret(http.Client client) => client.get(
  Uri.parse('$_httpbin/bearer'),
  headers: const {'Authorization': 'Bearer a-token-nobody-should-see'},
);
