import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';

import 'fixtures.dart';

void main() {
  List<String> order(PeekSort sort) => idsOf(sort.apply(fixtures));

  group('PeekSort', () {
    test('defaults to newest first', () {
      expect(PeekSort.newestFirst.field, PeekSortField.startedAt);
      expect(PeekSort.newestFirst.descending, isTrue);
      expect(order(PeekSort.newestFirst), ['e6', 'e5', 'e4', 'e3', 'e2', 'e1']);
      expect(order(PeekSort.oldestFirst), ['e1', 'e2', 'e3', 'e4', 'e5', 'e6']);
    });

    test('orders by duration and puts pending calls last either way', () {
      expect(order(PeekSort.slowestFirst), [
        'e5',
        'e6',
        'e2',
        'e1',
        'e3',
        'e4',
      ]);
      expect(
        order(const PeekSort(field: PeekSortField.duration, descending: false)),
        ['e3', 'e1', 'e2', 'e6', 'e5', 'e4'],
      );
    });

    test('orders by status code, calls without one last', () {
      expect(order(const PeekSort(field: PeekSortField.statusCode)), [
        'e6',
        'e2',
        'e1',
        'e3',
        'e4',
        'e5',
      ]);
      expect(
        order(
          const PeekSort(field: PeekSortField.statusCode, descending: false),
        ),
        ['e1', 'e3', 'e2', 'e6', 'e4', 'e5'],
      );
    });

    test('keeps the incoming order for equal keys', () {
      expect(order(PeekSort.largestFirst), [
        'e1',
        'e2',
        'e3',
        'e6',
        'e4',
        'e5',
      ]);
      expect(
        order(
          const PeekSort(field: PeekSortField.responseSize, descending: false),
        ),
        ['e1', 'e2', 'e3', 'e6', 'e4', 'e5'],
      );
      expect(order(const PeekSort(field: PeekSortField.requestSize)), [
        'e1',
        'e2',
        'e3',
        'e4',
        'e5',
        'e6',
      ]);
      expect(idsOf(PeekSort.largestFirst.apply(fixtures.reversed)), [
        'e6',
        'e3',
        'e2',
        'e1',
        'e5',
        'e4',
      ]);
    });

    test('returns a fresh list and leaves the input alone', () {
      final input = [e2, e1];
      final sorted = PeekSort.oldestFirst.apply(input);
      expect(idsOf(sorted), ['e1', 'e2']);
      expect(idsOf(input), ['e2', 'e1']);
      expect(PeekSort.oldestFirst.apply(const []), isEmpty);
    });

    test('compares pairs consistently', () {
      const sort = PeekSort.slowestFirst;
      expect(sort.compare(e5, e1), isNegative);
      expect(sort.compare(e1, e5), isPositive);
      expect(sort.compare(e1, e1), 0);
      expect(sort.compare(e4, e1), isPositive);
      expect(sort.compare(e1, e4), isNegative);
      expect(sort.compare(e4, e4), 0);
    });

    test('copies, compares and prints', () {
      final sort = PeekSort.newestFirst.copyWith(field: PeekSortField.duration);
      expect(sort, PeekSort.slowestFirst);
      expect(sort.hashCode, PeekSort.slowestFirst.hashCode);
      expect(sort.copyWith(descending: false), isNot(sort));
      expect(sort.copyWith(), sort);
      expect(sort.toString(), 'PeekSort(duration desc)');
      expect(PeekSort.oldestFirst.toString(), 'PeekSort(startedAt asc)');
    });
  });
}
