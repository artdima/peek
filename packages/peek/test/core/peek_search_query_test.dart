import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';

import 'fixtures.dart';

void main() {
  final login = PeekEntry(
    id: const PeekId('login'),
    request: PeekRequest(
      method: 'POST',
      uri: Uri.parse('https://api.example.com/login'),
      headers: PeekHeaders.fromMap({'X-Client': 'MobileApp/2.1'}),
      body: PeekBody.text('{"user":"Ann","remember":true}'),
    ),
    startedAt: fixtureStart,
    source: 'dio',
    response: PeekResponse(
      statusCode: 200,
      headers: PeekHeaders.fromMap({'X-Trace': 'abc-123'}),
      body: PeekBody.text('{"greeting":"Welcome back"}'),
    ),
    completedAt: fixtureStart,
  );
  final upload = PeekEntry(
    id: const PeekId('upload'),
    request: PeekRequest(
      method: 'POST',
      uri: Uri.parse('https://api.example.com/upload'),
      body: PeekBody.form(
        fields: const [PeekFormField('album', 'Holiday')],
        files: const [PeekFormFile('photo', filename: 'beach.jpg')],
      ),
    ),
    startedAt: fixtureStart,
    source: 'dio',
    failure: const PeekFailure(
      kind: PeekFailureKind.connection,
      message: 'Connection reset by peer',
      details: 'errno 54',
    ),
    completedAt: fixtureStart,
  );
  final all = [...fixtures, login, upload];

  List<String> found(PeekSearchQuery query) => idsOf(query.apply(all));

  List<String> foundIn(PeekSearchScope scope, String text) =>
      found(PeekSearchQuery(text, scopes: {scope}));

  group('PeekSearchQuery', () {
    test('matches everything when empty', () {
      expect(PeekSearchQuery.none.isEmpty, isTrue);
      expect(const PeekSearchQuery('   ').isEmpty, isTrue);
      expect(const PeekSearchQuery('x', scopes: {}).isEmpty, isTrue);
      expect(identical(PeekSearchQuery.none.apply(all), all), isTrue);
      expect(PeekSearchQuery.none.matches(login), isTrue);
    });

    test('searches URLs, ignoring case', () {
      const query = PeekSearchQuery('USERS', scopes: {PeekSearchScope.url});
      expect(found(query), ['e1', 'e5']);
      expect(found(const PeekSearchQuery('cdn.EXAMPLE')), ['e3']);
    });

    test('searches header names and values on both sides', () {
      const headers = PeekSearchScope.headers;
      expect(foundIn(headers, 'x-client'), ['login']);
      expect(foundIn(headers, 'mobileapp'), ['login']);
      expect(foundIn(headers, 'abc-123'), ['login']);
      expect(foundIn(headers, 'image/png'), ['e3']);
      expect(foundIn(PeekSearchScope.url, 'abc-123'), isEmpty);
    });

    test('searches text and form request bodies', () {
      const body = PeekSearchScope.requestBody;
      expect(foundIn(body, 'ann'), ['login']);
      expect(foundIn(body, 'holiday'), ['upload']);
      expect(foundIn(body, 'beach.jpg'), ['upload']);
      expect(foundIn(body, 'photo'), ['upload']);
      expect(foundIn(body, 'welcome'), isEmpty);
    });

    test('searches response bodies', () {
      const body = PeekSearchScope.responseBody;
      expect(foundIn(body, 'welcome'), ['login']);
      expect(foundIn(body, 'body of e2'), ['e2']);
      expect(foundIn(body, 'ann'), isEmpty);
    });

    test('searches failure kind, message and details', () {
      const error = PeekSearchScope.error;
      expect(foundIn(error, 'timeout'), ['e5']);
      expect(foundIn(error, 'reset by peer'), ['upload']);
      expect(foundIn(error, 'errno'), ['upload']);
      expect(foundIn(error, 'login'), isEmpty);
    });

    test('looks everywhere by default and trims the text', () {
      expect(found(const PeekSearchQuery('  errno ')), ['upload']);
      expect(found(const PeekSearchQuery('example.com')), idsOf(all));
    });

    test('treats the text literally, not as a pattern', () {
      expect(found(const PeekSearchQuery('.*')), isEmpty);
      expect(found(const PeekSearchQuery('users/1')), ['e5']);
    });

    test('searches bodies only up to the cap', () {
      final long = PeekEntry(
        id: const PeekId('long'),
        request: PeekRequest(
          method: 'GET',
          uri: Uri.parse('https://example.com/'),
          body: PeekBody.text('${'a' * 100}needle'),
        ),
        startedAt: fixtureStart,
        source: 'dio',
      );
      const capped = PeekSearchQuery('needle', maxBodyLength: 50);
      expect(capped.matches(long), isFalse);
      expect(capped.copyWith(maxBodyLength: 200).matches(long), isTrue);
      expect(const PeekSearchQuery('needle').matches(long), isTrue);
    });

    test('copies, compares and prints', () {
      const query = PeekSearchQuery('a', scopes: {PeekSearchScope.url});
      expect(query.copyWith(text: 'b').text, 'b');
      expect(query.copyWith(text: 'b').scopes, {PeekSearchScope.url});
      expect(query, const PeekSearchQuery('a', scopes: {PeekSearchScope.url}));
      expect(
        query.hashCode,
        const PeekSearchQuery('a', scopes: {PeekSearchScope.url}).hashCode,
      );
      expect(query, isNot(const PeekSearchQuery('a')));
      expect(query, isNot(query.copyWith(maxBodyLength: 1)));
      expect(query.toString(), 'PeekSearchQuery("a", 1 scopes)');
    });
  });
}
