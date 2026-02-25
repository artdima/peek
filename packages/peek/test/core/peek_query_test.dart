import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';

import 'fixtures.dart';

void main() {
  group('PeekQuery', () {
    test('keeps everything newest first by default', () {
      expect(PeekQuery.none.isEmpty, isTrue);
      expect(PeekQuery.none.filter, PeekFilter.none);
      expect(PeekQuery.none.sort, PeekSort.newestFirst);
      expect(idsOf(PeekQuery.none.run(fixtures)), [
        'e6',
        'e5',
        'e4',
        'e3',
        'e2',
        'e1',
      ]);
    });

    test('filters first, then sorts', () {
      const query = PeekQuery(
        filter: PeekFilter(onlyErrors: true),
        sort: PeekSort.slowestFirst,
      );
      expect(idsOf(query.run(fixtures)), ['e5', 'e6', 'e2']);
      expect(query.isEmpty, isFalse);
    });

    test('combines a search with a sort', () {
      const query = PeekQuery(
        filter: PeekFilter(query: PeekSearchQuery('api.example.com')),
        sort: PeekSort.oldestFirst,
      );
      expect(idsOf(query.run(fixtures)), ['e1', 'e2', 'e4', 'e5']);
    });

    test('returns a fresh list and leaves the input alone', () {
      final input = [e2, e1];
      expect(idsOf(PeekQuery.none.run(input)), ['e2', 'e1']);
      expect(idsOf(input), ['e2', 'e1']);
      expect(PeekQuery.none.run(const []), isEmpty);
    });

    test('counts facets over everything, not the filtered result', () {
      const query = PeekQuery(filter: PeekFilter(onlyErrors: true));
      expect(query.run(fixtures), hasLength(3));
      expect(query.facets(fixtures).total, 6);
      expect(query.facets(query.run(fixtures)).total, 3);
    });

    test('search replaces the text and keeps the scopes', () {
      const query = PeekQuery(
        filter: PeekFilter(
          query: PeekSearchQuery('old', scopes: {PeekSearchScope.url}),
        ),
      );
      final searched = query.search('users');
      expect(searched.filter.query.text, 'users');
      expect(searched.filter.query.scopes, {PeekSearchScope.url});
      expect(idsOf(searched.run(fixtures)), ['e5', 'e1']);
      expect(searched.search('').filter.query.isEmpty, isTrue);
    });

    test('sortBy switches fields and flips a repeated one', () {
      final byDuration = PeekQuery.none.sortBy(PeekSortField.duration);
      expect(byDuration.sort, PeekSort.slowestFirst);

      final flipped = byDuration.sortBy(PeekSortField.duration);
      expect(flipped.sort.field, PeekSortField.duration);
      expect(flipped.sort.descending, isFalse);
      expect(flipped.sortBy(PeekSortField.duration), byDuration);

      final byStatus = flipped.sortBy(PeekSortField.statusCode);
      expect(byStatus.sort.field, PeekSortField.statusCode);
      expect(byStatus.sort.descending, isTrue);
    });

    test('keeps the filter when the sort changes and the other way round', () {
      const query = PeekQuery(filter: PeekFilter(onlyPinned: true));
      expect(query.sortBy(PeekSortField.duration).filter, query.filter);
      expect(query.search('x').sort, query.sort);
      expect(query.copyWith(), query);
    });

    test('compares by value and prints its parts', () {
      const query = PeekQuery(
        filter: PeekFilter(onlyErrors: true),
        sort: PeekSort.slowestFirst,
      );
      expect(
        query,
        const PeekQuery(
          filter: PeekFilter(onlyErrors: true),
          sort: PeekSort.slowestFirst,
        ),
      );
      expect(
        query.hashCode,
        const PeekQuery(
          filter: PeekFilter(onlyErrors: true),
          sort: PeekSort.slowestFirst,
        ).hashCode,
      );
      expect(query, isNot(PeekQuery.none));
      expect(query, isNot(query.copyWith(sort: PeekSort.newestFirst)));
      expect(
        query.toString(),
        'PeekQuery(PeekFilter(1 active), PeekSort(duration desc))',
      );
    });
  });
}
