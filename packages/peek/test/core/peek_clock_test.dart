import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';

void main() {
  group('PeekSystemClock', () {
    test('follows the wall clock', () {
      final before = DateTime.now();
      final now = const PeekSystemClock().now();
      final after = DateTime.now();
      expect(now.isBefore(before), isFalse);
      expect(now.isAfter(after), isFalse);
    });
  });

  group('PeekFakeClock', () {
    test('stands still until advanced', () {
      final clock = PeekFakeClock(DateTime.utc(2026, 9, 10, 12));
      expect(clock.now(), DateTime.utc(2026, 9, 10, 12));
      expect(clock.now(), DateTime.utc(2026, 9, 10, 12));

      clock.advance(const Duration(milliseconds: 250));
      expect(
        clock.now(),
        DateTime.utc(2026, 9, 10, 12).add(const Duration(milliseconds: 250)),
      );
    });

    test('can move backwards', () {
      final clock = PeekFakeClock(DateTime.utc(2026, 9, 10));
      clock.advance(const Duration(days: -1));
      expect(clock.now(), DateTime.utc(2026, 9, 9));
    });

    test('starts at a fixed date by default', () {
      expect(PeekFakeClock().now(), DateTime.utc(2026));
    });
  });
}
