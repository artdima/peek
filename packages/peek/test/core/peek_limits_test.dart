import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';

void main() {
  group('PeekLimits', () {
    test('has sensible defaults', () {
      const limits = PeekLimits();
      expect(limits.maxEntries, 1000);
      expect(limits.maxBodyBytes, 512 * 1024);
    });

    test('rejects nonsense', () {
      expect(() => PeekLimits(maxEntries: 0), throwsAssertionError);
      expect(() => PeekLimits(maxBodyBytes: -1), throwsAssertionError);
      expect(const PeekLimits(maxBodyBytes: 0).maxBodyBytes, 0);
    });

    test('copies, compares and prints', () {
      const limits = PeekLimits(maxEntries: 10, maxBodyBytes: 100);
      expect(
        limits.copyWith(maxEntries: 20),
        const PeekLimits(maxEntries: 20, maxBodyBytes: 100),
      );
      expect(limits, const PeekLimits(maxEntries: 10, maxBodyBytes: 100));
      expect(
        limits.hashCode,
        const PeekLimits(maxEntries: 10, maxBodyBytes: 100).hashCode,
      );
      expect(limits, isNot(const PeekLimits(maxEntries: 10)));
      expect(limits.toString(), 'PeekLimits(10 entries, 100 body bytes)');
    });
  });
}
