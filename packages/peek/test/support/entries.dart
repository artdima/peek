import 'dart:convert';
import 'dart:typed_data';

import 'package:peek/core.dart';

/// A small, varied set of entries shared by the query tests.
///
/// | id | call                           | outcome          | src    | ms   |
/// |----|--------------------------------|------------------|--------|------|
/// | e1 | GET api.example.com/users      | 200 json         | dio    | 120  |
/// | e2 | POST api.example.com/login     | 401 json         | dio    | 300  |
/// | e3 | GET cdn.example.com/logo.png   | 200 image/png    | dio    | 40   |
/// | e4 | GET api.example.com/slow       | pending          | talker | —    |
/// | e5 | DELETE api.example.com/users/1 | timeout, pinned  | talker | 5000 |
/// | e6 | GET other.example.com/health   | 503 text/plain   | dio    | 800  |
final DateTime fixtureStart = DateTime.utc(2026, 9, 10, 12);

PeekEntry _entry(
  String id,
  String method,
  String url, {
  required int second,
  required String source,
  int? status,
  String? type,
  int? ms,
  PeekFailure? failure,
  bool pinned = false,
}) {
  final startedAt = fixtureStart.add(Duration(seconds: second));
  final request = PeekRequest(method: method, uri: Uri.parse(url));
  final response =
      status == null
          ? null
          : PeekResponse(
            statusCode: status,
            headers:
                type == null
                    ? PeekHeaders.empty
                    : PeekHeaders.fromMap({'Content-Type': type}),
            body: PeekBody.text(
              'body of $id',
              contentType: PeekMediaType.tryParse(type),
            ),
          );
  return PeekEntry(
    id: PeekId(id),
    request: request,
    startedAt: startedAt,
    source: source,
    response: response,
    failure: failure,
    completedAt: ms == null ? null : startedAt.add(Duration(milliseconds: ms)),
    isPinned: pinned,
  );
}

final PeekEntry e1 = _entry(
  'e1',
  'GET',
  'https://api.example.com/users',
  second: 0,
  source: 'dio',
  status: 200,
  type: 'application/json; charset=utf-8',
  ms: 120,
);

final PeekEntry e2 = _entry(
  'e2',
  'POST',
  'https://api.example.com/login',
  second: 1,
  source: 'dio',
  status: 401,
  type: 'application/json',
  ms: 300,
);

final PeekEntry e3 = _entry(
  'e3',
  'GET',
  'https://cdn.example.com/logo.png',
  second: 2,
  source: 'dio',
  status: 200,
  type: 'image/png',
  ms: 40,
);

final PeekEntry e4 = _entry(
  'e4',
  'GET',
  'https://api.example.com/slow',
  second: 3,
  source: 'talker',
);

final PeekEntry e5 = _entry(
  'e5',
  'DELETE',
  'https://api.example.com/users/1',
  second: 4,
  source: 'talker',
  ms: 5000,
  failure: const PeekFailure(kind: PeekFailureKind.timeout, message: 'slow'),
  pinned: true,
);

final PeekEntry e6 = _entry(
  'e6',
  'GET',
  'https://Other.Example.com/health',
  second: 5,
  source: 'dio',
  status: 503,
  type: 'text/plain',
  ms: 800,
);

/// Every fixture entry, in id order.
final List<PeekEntry> fixtures = [e1, e2, e3, e4, e5, e6];

/// The ids of [entries], for compact assertions.
List<String> idsOf(Iterable<PeekEntry> entries) =>
    entries.map((entry) => entry.id.value).toList();

final String _bigJsonText = () {
  final rows = [
    for (var i = 0; i < 400; i++) '{"id":$i,"name":"row $i"}',
  ].join(',');
  return '{"rows":[$rows]}';
}();

/// A JSON response big enough to exercise lazy rendering.
final PeekEntry bigJson = PeekEntry(
  id: const PeekId('big'),
  request: PeekRequest(
    method: 'GET',
    uri: Uri.parse('https://api.example.com/reports/2026'),
  ),
  startedAt: fixtureStart.add(const Duration(seconds: 6)),
  source: 'dio',
  response: PeekResponse(
    statusCode: 200,
    headers: PeekHeaders.fromMap({'Content-Type': 'application/json'}),
    body: PeekBody.text(_bigJsonText, contentType: PeekMediaType.json),
  ),
  completedAt: fixtureStart.add(const Duration(seconds: 6, milliseconds: 640)),
);

/// A URL long enough to wrap or clip in any layout.
final PeekEntry longUrl = PeekEntry(
  id: const PeekId('long-url'),
  request: PeekRequest(
    method: 'GET',
    uri: Uri.parse(
      'https://analytics.example.com/v3/collect'
      '?event=checkout_completed&session=8f14e45fceea167a5a36dedd4bea2543'
      '&utm_source=newsletter&utm_medium=email&utm_campaign=autumn-sale-2026',
    ),
  ),
  startedAt: fixtureStart.add(const Duration(seconds: 7)),
  source: 'dio',
  response: PeekResponse(statusCode: 204),
  completedAt: fixtureStart.add(const Duration(seconds: 7, milliseconds: 15)),
);

/// A multipart upload that ends in 201.
final PeekEntry upload = PeekEntry(
  id: const PeekId('upload'),
  request: PeekRequest(
    method: 'POST',
    uri: Uri.parse('https://api.example.com/photos'),
    headers: PeekHeaders.fromMap({
      'Content-Type': 'multipart/form-data; boundary=peek',
    }),
    body: PeekBody.form(
      fields: const [PeekFormField('album', 'Holiday')],
      files: [
        PeekFormFile(
          'photo',
          filename: 'beach.jpg',
          contentType: PeekMediaType.tryParse('image/jpeg'),
          size: 2 * 1024 * 1024,
        ),
      ],
      contentType: PeekMediaType.multipartFormData,
    ),
  ),
  startedAt: fixtureStart.add(const Duration(seconds: 8)),
  source: 'dio',
  response: PeekResponse(
    statusCode: 201,
    statusMessage: 'Created',
    headers: PeekHeaders.fromMap({
      'Content-Type': 'application/json',
      'Location': 'https://api.example.com/photos/42',
    }),
    body: PeekBody.text('{"id":42}', contentType: PeekMediaType.json),
  ),
  completedAt: fixtureStart.add(const Duration(seconds: 11, milliseconds: 200)),
);

/// A redirect chain that lands on 200.
final PeekEntry redirected = PeekEntry(
  id: const PeekId('redirect'),
  request: PeekRequest(
    method: 'GET',
    uri: Uri.parse('http://example.com/docs'),
  ),
  startedAt: fixtureStart.add(const Duration(seconds: 9)),
  source: 'dio',
  response: PeekResponse(
    statusCode: 200,
    headers: PeekHeaders.fromMap({'Content-Type': 'text/html'}),
    body: PeekBody.text('<h1>Docs</h1>', contentType: PeekMediaType.html),
    redirects: [
      PeekRedirect(
        statusCode: 301,
        method: 'GET',
        location: Uri.parse('https://example.com/docs'),
      ),
      PeekRedirect(
        statusCode: 302,
        method: 'GET',
        location: Uri.parse('https://example.com/docs/latest'),
      ),
    ],
  ),
  completedAt: fixtureStart.add(const Duration(seconds: 9, milliseconds: 310)),
);

/// A call the app cancelled.
final PeekEntry cancelled = PeekEntry(
  id: const PeekId('cancelled'),
  request: PeekRequest(
    method: 'GET',
    uri: Uri.parse('https://api.example.com/search?q=fl'),
  ),
  startedAt: fixtureStart.add(const Duration(seconds: 10)),
  source: 'dio',
  failure: const PeekFailure(
    kind: PeekFailureKind.cancelled,
    message: 'Request cancelled by the app',
  ),
  completedAt: fixtureStart.add(const Duration(seconds: 10, milliseconds: 45)),
);

/// A 404 that answers with a problem document.
final PeekEntry notFound = PeekEntry(
  id: const PeekId('not-found'),
  request: PeekRequest(
    method: 'GET',
    uri: Uri.parse('https://api.example.com/users/999'),
  ),
  startedAt: fixtureStart.add(const Duration(seconds: 11)),
  source: 'talker',
  response: PeekResponse(
    statusCode: 404,
    statusMessage: 'Not Found',
    headers: PeekHeaders.fromMap({'Content-Type': 'application/problem+json'}),
    body: PeekBody.text(
      '{"type":"about:blank","title":"Not Found","status":404}',
      contentType: PeekMediaType.tryParse('application/problem+json'),
    ),
  ),
  completedAt: fixtureStart.add(const Duration(seconds: 11, milliseconds: 90)),
);

/// A PNG response, for the image viewer.
final PeekEntry image = PeekEntry(
  id: const PeekId('image'),
  request: PeekRequest(
    method: 'GET',
    uri: Uri.parse('https://cdn.example.com/avatar.png'),
  ),
  startedAt: fixtureStart.add(const Duration(seconds: 12)),
  source: 'dio',
  response: PeekResponse(
    statusCode: 200,
    headers: PeekHeaders.fromMap({'Content-Type': 'image/png'}),
    body: PeekBody.bytes(
      transparentPixelPng,
      contentType: PeekMediaType.tryParse('image/png'),
    ),
  ),
  completedAt: fixtureStart.add(const Duration(seconds: 12, milliseconds: 60)),
);

/// A streamed download Peek could not capture.
final PeekEntry streamed = PeekEntry(
  id: const PeekId('streamed'),
  request: PeekRequest(
    method: 'GET',
    uri: Uri.parse('https://cdn.example.com/video.mp4'),
  ),
  startedAt: fixtureStart.add(const Duration(seconds: 13)),
  source: 'dio',
  response: PeekResponse(
    statusCode: 200,
    headers: PeekHeaders.fromMap({
      'Content-Type': 'video/mp4',
      'Content-Length': '73400320',
    }),
    body: const PeekBody.unavailable(
      PeekBodyUnavailableReason.streamed,
      size: 73400320,
    ),
  ),
  completedAt: fixtureStart.add(const Duration(seconds: 14, milliseconds: 800)),
);

/// Every fixture the UI tests draw on, in id order.
final List<PeekEntry> uiFixtures = [
  ...fixtures,
  bigJson,
  longUrl,
  upload,
  redirected,
  cancelled,
  notFound,
  image,
  streamed,
];

/// A 1×1 transparent PNG.
final Uint8List transparentPixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
  'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);
