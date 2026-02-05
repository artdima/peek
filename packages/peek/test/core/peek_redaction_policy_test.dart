import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';

void main() {
  group('PeekRedactionPolicy', () {
    test('masks the usual suspects by default', () {
      const policy = PeekRedactionPolicy();
      expect(policy.matchesHeader('authorization'), isTrue);
      expect(policy.matchesHeader('Set-Cookie'), isTrue);
      expect(policy.matchesQuery('access_token'), isTrue);
      expect(policy.matchesBodyKey('client_secret'), isTrue);
      expect(policy.replacement, '*****');
      expect(policy.isEmpty, isFalse);
    });

    test('matches names case-insensitively and exactly', () {
      const policy = PeekRedactionPolicy(headerNames: {'X-Auth-Token'});
      expect(policy.matchesHeader('x-auth-token'), isTrue);
      expect(policy.matchesHeader('X-AUTH-TOKEN'), isTrue);
      expect(policy.matchesHeader('x-auth-token-2'), isFalse);
      expect(policy.matchesHeader('auth-token'), isFalse);
      expect(policy.matchesQuery('x-auth-token'), isFalse);
    });

    test('none masks nothing', () {
      expect(PeekRedactionPolicy.none.isEmpty, isTrue);
      expect(PeekRedactionPolicy.none.matchesHeader('authorization'), isFalse);
      expect(PeekRedactionPolicy.none.matchesBodyKey('password'), isFalse);
    });

    test('copies with replaced fields', () {
      const policy = PeekRedactionPolicy();
      final copy = policy.copyWith(replacement: '[hidden]', queryKeys: {});
      expect(copy.replacement, '[hidden]');
      expect(copy.queryKeys, isEmpty);
      expect(copy.headerNames, policy.headerNames);
      expect(copy.bodyKeys, policy.bodyKeys);
    });

    test('compares sets regardless of order', () {
      const one = PeekRedactionPolicy(headerNames: {'a', 'b'});
      const two = PeekRedactionPolicy(headerNames: {'b', 'a'});
      expect(one, two);
      expect(one.hashCode, two.hashCode);
      expect(one, isNot(const PeekRedactionPolicy(headerNames: {'a'})));
      expect(one, isNot(one.copyWith(replacement: 'x')));
    });

    test('prints its sizes', () {
      expect(
        const PeekRedactionPolicy().toString(),
        'PeekRedactionPolicy(6 headers, 9 query keys, 10 body keys)',
      );
    });
  });
}
