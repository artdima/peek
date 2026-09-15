import 'dart:typed_data';

import 'package:chopper/chopper.dart';

/// One thing the Chopper route can do to the network.
///
/// Chopper takes the base of a call per request, so each scenario names its
/// own host and the client is free of one.
final class ChopperScenario {
  /// Creates a scenario named [name].
  const ChopperScenario({
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
  final Future<void> Function(ChopperClient client) run;
}

final Uri _httpbin = Uri.parse('https://httpbin.org');
final Uri _placeholder = Uri.parse('https://jsonplaceholder.typicode.com');

/// Everything the Chopper route can do, in the order it is worth trying.
const List<ChopperScenario> chopperScenarios = [
  ChopperScenario(
    name: 'GET JSON',
    detail: 'A small object, shown as a tree',
    run: _getJson,
  ),
  ChopperScenario(
    name: 'POST JSON',
    detail: 'The body the converter produced, as it goes out',
    run: _postJson,
  ),
  ChopperScenario(
    name: 'Upload a file',
    detail: 'Multipart: the part is described, never read',
    run: _upload,
  ),
  ChopperScenario(
    name: 'Not found',
    detail: '404 — an answer, not a failure',
    run: _notFound,
  ),
  ChopperScenario(
    name: 'Server error',
    detail: '500, in the colour of a server error',
    run: _serverError,
  ),
  ChopperScenario(
    name: 'Called off',
    detail: 'Aborted in flight; not an error',
    run: _aborted,
  ),
  ChopperScenario(
    name: 'An image',
    detail: 'Bytes, shown as a picture',
    run: _image,
  ),
  ChopperScenario(
    name: 'A big body',
    detail: 'Around a megabyte of JSON, truncated to the limit',
    run: _bigBody,
  ),
  ChopperScenario(
    name: 'A secret header',
    detail: 'Authorization, shown as sent until a policy masks it',
    run: _secret,
  ),
];

Future<void> _getJson(ChopperClient client) =>
    client.send<dynamic, dynamic>(_get('/users/1', _placeholder));

Future<void> _postJson(ChopperClient client) => client.send<dynamic, dynamic>(
  Request(
    'POST',
    Uri.parse('/post'),
    _httpbin,
    body: const {'sku': 'A-1', 'quantity': 2},
  ),
);

Future<void> _upload(ChopperClient client) => client.send<dynamic, dynamic>(
  Request(
    'POST',
    Uri.parse('/post'),
    _httpbin,
    multipart: true,
    parts: [
      const PartValue<String>('note', 'a photo of a cat'),
      PartValueFile<List<int>>('photo', Uint8List(64 * 1024)),
    ],
  ),
);

Future<void> _notFound(ChopperClient client) =>
    client.send<dynamic, dynamic>(_get('/status/404', _httpbin));

Future<void> _serverError(ChopperClient client) =>
    client.send<dynamic, dynamic>(_get('/status/500', _httpbin));

Future<void> _aborted(ChopperClient client) => client.send<dynamic, dynamic>(
  Request(
    'GET',
    Uri.parse('/delay/5'),
    _httpbin,
    abortTrigger: Future<void>.delayed(const Duration(milliseconds: 400)),
  ),
);

Future<void> _image(ChopperClient client) =>
    client.send<dynamic, dynamic>(_get('/image/png', _httpbin));

Future<void> _bigBody(ChopperClient client) =>
    client.send<dynamic, dynamic>(_get('/photos', _placeholder));

Future<void> _secret(ChopperClient client) => client.send<dynamic, dynamic>(
  _get(
    '/bearer',
    _httpbin,
    headers: const {'Authorization': 'Bearer a-token-nobody-should-see'},
  ),
);

Request _get(String path, Uri base, {Map<String, String> headers = const {}}) =>
    Request('GET', Uri.parse(path), base, headers: headers);
