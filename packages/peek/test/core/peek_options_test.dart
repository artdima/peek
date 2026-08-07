import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';

void main() {
  group('PeekOptions', () {
    test('defaults to recording the call as it happened', () {
      const options = PeekOptions();
      expect(options.enabled, isTrue);
      expect(options.limits, const PeekLimits());
      // Masking is asked for, not assumed.
      expect(options.redaction, PeekRedactionPolicy.none);
      expect(options.redaction.isEmpty, isTrue);
      expect(const PeekRedactionPolicy().isEmpty, isFalse);
      expect(options.clock, isA<PeekSystemClock>());
      expect(options.onError, isNull);
    });

    test('copies with replaced fields', () {
      void handler(Object error, StackTrace stackTrace) {}
      final copy = const PeekOptions().copyWith(
        enabled: false,
        limits: const PeekLimits(maxEntries: 5),
        onError: handler,
      );
      expect(copy.enabled, isFalse);
      expect(copy.limits.maxEntries, 5);
      expect(copy.onError, handler);
      expect(copy.redaction, PeekRedactionPolicy.none);
    });

    test('prints the parts that matter', () {
      expect(
        const PeekOptions(enabled: false).toString(),
        'PeekOptions(PeekLimits(1000 entries, 524288 body bytes, 50 pinned), '
        'PeekRedactionPolicy(0 headers, 0 query keys, 0 body keys), '
        'enabled: false)',
      );
    });
  });
}
