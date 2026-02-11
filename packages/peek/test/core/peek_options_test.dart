import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';

void main() {
  group('PeekOptions', () {
    test('defaults to recording with the standard limits and policy', () {
      const options = PeekOptions();
      expect(options.enabled, isTrue);
      expect(options.limits, const PeekLimits());
      expect(options.redaction, const PeekRedactionPolicy());
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
      expect(copy.redaction, const PeekRedactionPolicy());
    });

    test('prints the parts that matter', () {
      expect(
        const PeekOptions(enabled: false).toString(),
        'PeekOptions(PeekLimits(1000 entries, 524288 body bytes), '
        'PeekRedactionPolicy(6 headers, 9 query keys, 10 body keys), '
        'enabled: false)',
      );
    });
  });
}
