import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';

void main() {
  group('PeekTimings', () {
    test('lists only the known phases, in HAR order', () {
      const timings = PeekTimings(
        dns: Duration(milliseconds: 3),
        wait: Duration(milliseconds: 120),
        receive: Duration(milliseconds: 8),
      );
      expect(timings.known, {
        'dns': const Duration(milliseconds: 3),
        'wait': const Duration(milliseconds: 120),
        'receive': const Duration(milliseconds: 8),
      });
      expect(timings.known.keys, ['dns', 'wait', 'receive']);
      expect(const PeekTimings().known, isEmpty);
    });

    test('compares by value and prints the known phases', () {
      const timings = PeekTimings(connect: Duration(milliseconds: 20));
      expect(timings, const PeekTimings(connect: Duration(milliseconds: 20)));
      expect(
        timings.hashCode,
        const PeekTimings(connect: Duration(milliseconds: 20)).hashCode,
      );
      expect(
        timings,
        isNot(const PeekTimings(ssl: Duration(milliseconds: 20))),
      );
      expect(timings.toString(), 'PeekTimings(connect)');
    });
  });
}
