import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';

void main() {
  group('PeekId', () {
    test('equals another id with the same value', () {
      expect(const PeekId('a'), const PeekId('a'));
      expect(const PeekId('a').hashCode, const PeekId('a').hashCode);
      expect(const PeekId('a'), isNot(const PeekId('b')));
    });

    test('works as a map key', () {
      final entries = <PeekId, int>{};
      entries[const PeekId('a')] = 1;
      entries[const PeekId('a')] = 2;
      expect(entries, hasLength(1));
      expect(entries[const PeekId('a')], 2);
    });

    test('prints as its bare value', () {
      expect('${const PeekId('a-1')}', 'a-1');
    });

    test('generates 100 000 distinct ids', () {
      final ids = {for (var i = 0; i < 100000; i++) PeekId.generate()};
      expect(ids, hasLength(100000));
    });

    test('generated ids share a session prefix and differ in the suffix', () {
      final first = PeekId.generate().value.split('-');
      final second = PeekId.generate().value.split('-');
      expect(first, hasLength(2));
      expect(first.first, second.first);
      expect(first.first, hasLength(6));
      expect(first.last, isNot(second.last));
    });
  });
}
