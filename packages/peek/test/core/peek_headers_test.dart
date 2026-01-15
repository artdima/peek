import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';

void main() {
  group('PeekHeaders', () {
    test('looks names up regardless of case', () {
      final headers = PeekHeaders.fromMap({'Content-Type': 'text/plain'});
      expect(headers['content-type'], 'text/plain');
      expect(headers['CONTENT-TYPE'], 'text/plain');
      expect(headers.contains('Content-type'), isTrue);
      expect(headers.valuesOf('content-TYPE'), ['text/plain']);
    });

    test('keeps the first-seen casing and order of names', () {
      final headers = PeekHeaders.fromEntries(const [
        MapEntry('X-B', '1'),
        MapEntry('x-a', '2'),
        MapEntry('X-A', '3'),
      ]);
      expect(headers.names, ['X-B', 'x-a']);
      expect(headers.entries.map((entry) => entry.key), ['X-B', 'x-a', 'x-a']);
      expect(headers.entries.map((entry) => entry.value), ['1', '2', '3']);
    });

    test('collects repeated names and joins them on lookup', () {
      final headers = PeekHeaders.fromEntries(const [
        MapEntry('Accept', 'text/html'),
        MapEntry('accept', 'application/json'),
      ]);
      expect(headers.length, 1);
      expect(headers['accept'], 'text/html, application/json');
      expect(headers.valuesOf('accept'), ['text/html', 'application/json']);
    });

    test('builds from a multimap and drops names without values', () {
      final headers = PeekHeaders.fromMultiMap({
        'set-cookie': ['a=1', 'b=2'],
        'x-empty': <String>[],
        'x-blank': [''],
      });
      expect(headers.names, ['set-cookie', 'x-blank']);
      expect(headers.valuesOf('set-cookie'), ['a=1', 'b=2']);
      expect(headers['x-blank'], '');
      expect(headers.contains('x-empty'), isFalse);
    });

    test('trims names and values and skips blank names', () {
      final headers = PeekHeaders.fromMap({
        '  X-Trim  ': '  spaced  ',
        '   ': 'ignored',
        '': 'ignored too',
      });
      expect(headers.names, ['X-Trim']);
      expect(headers['x-trim'], 'spaced');
    });

    test('answers absent names with null and empty lists', () {
      expect(PeekHeaders.empty['x'], isNull);
      expect(PeekHeaders.empty.valuesOf('x'), isEmpty);
      expect(PeekHeaders.empty.contains('x'), isFalse);
      expect(PeekHeaders.empty.isEmpty, isTrue);
      expect(PeekHeaders.empty.isNotEmpty, isFalse);
      expect(PeekHeaders.empty.entries, isEmpty);
      expect(PeekHeaders.empty.names, isEmpty);
    });

    test('exposes content type and length', () {
      final json = PeekHeaders.fromMap({
        'Content-Type': 'application/json; charset=utf-8',
        'Content-Length': '42',
      });
      expect(json.contentType, 'application/json; charset=utf-8');
      expect(json.contentLength, 42);

      final odd = PeekHeaders.fromMap({'Content-Length': 'many'});
      expect(odd.contentType, isNull);
      expect(odd.contentLength, isNull);
      expect(PeekHeaders.empty.contentLength, isNull);
    });

    test('parses request cookies', () {
      final headers = PeekHeaders.fromMap({'Cookie': 'sid=abc; theme=dark'});
      expect(headers.cookies.map((cookie) => cookie.name), ['sid', 'theme']);
      expect(headers.cookies.first.value, 'abc');
      expect(PeekHeaders.empty.cookies, isEmpty);
    });

    test('parses each Set-Cookie header on its own', () {
      final headers = PeekHeaders.fromMultiMap({
        'Set-Cookie': [
          'id=1; Path=/; Expires=Wed, 21 Oct 2026 07:28:00 GMT; HttpOnly',
          'theme=dark; Secure',
          'malformed',
        ],
      });
      final cookies = headers.setCookies;
      expect(cookies.map((cookie) => cookie.name), ['id', 'theme']);
      expect(cookies.first.expires, 'Wed, 21 Oct 2026 07:28:00 GMT');
      expect(cookies.first.isHttpOnly, isTrue);
      expect(cookies.last.isSecure, isTrue);
    });

    test('compares by lowercase name and ordered values', () {
      final plain = PeekHeaders.fromMap({'A': '1', 'B': '2'});
      final shuffled = PeekHeaders.fromMap({'b': '2', 'a': '1'});
      expect(plain, shuffled);
      expect(plain.hashCode, shuffled.hashCode);
      expect(plain, isNot(PeekHeaders.fromMap({'A': '1'})));

      final multi = PeekHeaders.fromMultiMap({
        'a': ['1', '2'],
      });
      final multiUpper = PeekHeaders.fromMultiMap({
        'A': ['1', '2'],
      });
      final multiReversed = PeekHeaders.fromMultiMap({
        'a': ['2', '1'],
      });
      expect(multi, multiUpper);
      expect(multi, isNot(multiReversed));
    });

    test('prints names but never values', () {
      final headers = PeekHeaders.fromMap({'Authorization': 'Bearer secret'});
      expect(headers.toString(), 'PeekHeaders(Authorization)');
      expect(headers.toString(), isNot(contains('secret')));
    });

    test('is immutable and detached from its source', () {
      final source = <String, List<String>>{};
      source['x'] = ['1'];
      final headers = PeekHeaders.fromMultiMap(source);

      source['x']!.add('2');
      source['y'] = ['3'];
      expect(headers.valuesOf('x'), ['1']);
      expect(headers.contains('y'), isFalse);

      expect(() => headers.valuesOf('x').add('2'), throwsUnsupportedError);
      expect(() => headers.entries.clear(), throwsUnsupportedError);
      expect(() => headers.toMap()['x'] = [], throwsUnsupportedError);
    });

    test('exports a map keyed by display name', () {
      final headers = PeekHeaders.fromMultiMap({
        'X-Multi': ['1', '2'],
      });
      expect(headers.toMap(), {
        'X-Multi': ['1', '2'],
      });
    });
  });
}
