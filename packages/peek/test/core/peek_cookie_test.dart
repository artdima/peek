import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';

void main() {
  group('PeekCookie.parseCookieHeader', () {
    test('splits pairs and tolerates odd spacing', () {
      final cookies = PeekCookie.parseCookieHeader(' a=1 ;b = 2;; c ');
      expect(cookies.map((cookie) => '${cookie.name}=${cookie.value}'), [
        'a=1',
        'b=2',
        'c=',
      ]);
    });

    test('keeps everything after the first equals sign', () {
      final cookies = PeekCookie.parseCookieHeader('token=abc==; q="x=y"');
      expect(cookies.first.value, 'abc==');
      expect(cookies.last.value, '"x=y"');
    });

    test('skips parts without a name', () {
      final cookies = PeekCookie.parseCookieHeader('=orphan; ok=1');
      expect(cookies.map((cookie) => cookie.name), ['ok']);
      expect(PeekCookie.parseCookieHeader(''), isEmpty);
      expect(PeekCookie.parseCookieHeader(' ; '), isEmpty);
    });

    test('returns an unmodifiable list', () {
      final cookies = PeekCookie.parseCookieHeader('a=1');
      expect(cookies.clear, throwsUnsupportedError);
    });
  });

  group('PeekCookie.parseSetCookie', () {
    test('reads the pair and lowercases attribute names', () {
      final cookie =
          PeekCookie.parseSetCookie(
            'sid=xyz; Path=/app; Domain=example.com; Max-Age=3600; '
            'SameSite=Lax; Secure; HttpOnly',
          )!;
      expect(cookie.name, 'sid');
      expect(cookie.value, 'xyz');
      expect(cookie.path, '/app');
      expect(cookie.domain, 'example.com');
      expect(cookie.maxAge, 3600);
      expect(cookie.sameSite, 'Lax');
      expect(cookie.isSecure, isTrue);
      expect(cookie.isHttpOnly, isTrue);
      expect(cookie.attributes['secure'], isNull);
      expect(cookie.attributes.keys, [
        'path',
        'domain',
        'max-age',
        'samesite',
        'secure',
        'httponly',
      ]);
    });

    test('returns null without a name=value pair', () {
      expect(PeekCookie.parseSetCookie(''), isNull);
      expect(PeekCookie.parseSetCookie('Secure; HttpOnly'), isNull);
      expect(PeekCookie.parseSetCookie('=1; Path=/'), isNull);
    });

    test('keeps a comma inside Expires', () {
      final cookie =
          PeekCookie.parseSetCookie(
            'a=1; Expires=Wed, 21 Oct 2026 07:28:00 GMT',
          )!;
      expect(cookie.expires, 'Wed, 21 Oct 2026 07:28:00 GMT');
      expect(cookie.maxAge, isNull);
    });

    test('has no attributes for a bare pair', () {
      final cookie = PeekCookie.parseSetCookie('a=1')!;
      expect(cookie.attributes, isEmpty);
      expect(cookie.isSecure, isFalse);
      expect(cookie.isHttpOnly, isFalse);
      expect(cookie.path, isNull);
      expect(() => cookie.attributes['x'] = 'y', throwsUnsupportedError);
    });
  });

  group('PeekCookie', () {
    test('compares by name, value and attributes', () {
      const cookie = PeekCookie('n', 'v', attributes: {'path': '/'});
      const same = PeekCookie('n', 'v', attributes: {'path': '/'});
      const otherPath = PeekCookie('n', 'v', attributes: {'path': '/x'});
      expect(cookie, same);
      expect(cookie.hashCode, same.hashCode);
      expect(cookie, isNot(otherPath));
      expect(cookie, isNot(const PeekCookie('n', 'v')));
      expect(
        cookie,
        isNot(const PeekCookie('n', 'w', attributes: {'path': '/'})),
      );
    });

    test('prints its name only', () {
      expect(const PeekCookie('sid', 'secret').toString(), 'PeekCookie(sid)');
    });
  });
}
