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
