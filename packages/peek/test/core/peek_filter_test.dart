import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';

import '../support/entries.dart';

void main() {
  List<String> keep(PeekFilter filter) => idsOf(filter.apply(fixtures));

  group('PeekFilter', () {
    test('matches everything by default', () {
      expect(PeekFilter.none.isEmpty, isTrue);
      expect(PeekFilter.none.activeCount, 0);
      expect(keep(PeekFilter.none), idsOf(fixtures));
      expect(identical(PeekFilter.none.apply(fixtures), fixtures), isTrue);
    });

    test('filters by method, ignoring case', () {
      expect(keep(const PeekFilter(methods: {'post'})), ['e2']);
      expect(keep(const PeekFilter(methods: {'GET', 'delete'})), [
        'e1',
        'e3',
        'e4',
        'e5',
        'e6',
      ]);
    });

    test('filters by host, ignoring case', () {
      expect(keep(const PeekFilter(hosts: {'CDN.example.com'})), ['e3']);
      expect(keep(const PeekFilter(hosts: {'other.example.com'})), ['e6']);
    });

    test('filters by status class and code', () {
      expect(keep(const PeekFilter(statusClasses: {PeekStatusClass.success})), [
        'e1',
        'e3',
      ]);
      expect(
        keep(
          const PeekFilter(
            statusClasses: {
              PeekStatusClass.clientError,
              PeekStatusClass.serverError,
            },
          ),
        ),
        ['e2', 'e6'],
      );
      expect(keep(const PeekFilter(statusCodes: {200, 503})), [
        'e1',
        'e3',
        'e6',
      ]);
    });

    test('drops entries without a status when status is filtered', () {
      expect(
        keep(const PeekFilter(statusClasses: {PeekStatusClass.unknown})),
        isEmpty,
      );
      expect(keep(const PeekFilter(statusCodes: {0})), isEmpty);
    });

    test('filters by state, source and pin', () {
      expect(keep(const PeekFilter(states: {PeekEntryState.pending})), ['e4']);
      expect(
        keep(
          const PeekFilter(
            states: {PeekEntryState.completed, PeekEntryState.failed},
          ),
        ),
        ['e1', 'e2', 'e3', 'e5', 'e6'],
      );
      expect(keep(const PeekFilter(sources: {'talker'})), ['e4', 'e5']);
      expect(keep(const PeekFilter(onlyPinned: true)), ['e5']);
    });

    test('filters errors: failures and 4xx/5xx', () {
      expect(keep(const PeekFilter(onlyErrors: true)), ['e2', 'e5', 'e6']);
    });

    test('filters by response media type without parameters', () {
      expect(keep(const PeekFilter(contentTypes: {'application/json'})), [
        'e1',
        'e2',
      ]);
      expect(keep(const PeekFilter(contentTypes: {'IMAGE/PNG'})), ['e3']);
    });

    test('filters by duration and leaves pending calls out', () {
      expect(
        keep(
          const PeekFilter(
            duration: PeekDurationRange(min: Duration(milliseconds: 300)),
          ),
        ),
        ['e2', 'e5', 'e6'],
      );
      expect(
        keep(
          const PeekFilter(
            duration: PeekDurationRange(
              min: Duration(milliseconds: 100),
              max: Duration(milliseconds: 300),
            ),
          ),
        ),
        ['e1', 'e2'],
      );
      expect(
        keep(
          const PeekFilter(
            duration: PeekDurationRange(max: Duration(milliseconds: 50)),
          ),
        ),
        ['e3'],
      );
    });

    test('filters by start time, bounds included', () {
      final from = fixtureStart.add(const Duration(seconds: 2));
      final to = fixtureStart.add(const Duration(seconds: 4));
      expect(keep(PeekFilter(dates: PeekDateRange(from: from, to: to))), [
        'e3',
        'e4',
        'e5',
      ]);
      expect(keep(PeekFilter(dates: PeekDateRange(from: to))), ['e5', 'e6']);
      expect(keep(PeekFilter(dates: PeekDateRange(to: from))), [
        'e1',
        'e2',
        'e3',
      ]);
    });

    test('searches text as one more criterion', () {
      expect(keep(const PeekFilter(query: PeekSearchQuery('users'))), [
        'e1',
        'e5',
      ]);
      expect(
        keep(
          const PeekFilter(query: PeekSearchQuery('users'), onlyErrors: true),
        ),
        ['e5'],
      );
      const filter = PeekFilter(query: PeekSearchQuery('users'));
      expect(filter.matches(e1), isTrue);
      expect(filter.matches(e2), isFalse);
      expect(filter.activeCount, 1);
      expect(filter.copyWith(query: PeekSearchQuery.none).isEmpty, isTrue);
      expect(filter, isNot(const PeekFilter(query: PeekSearchQuery('x'))));
    });

    test('requires every set criterion to hold', () {
      const filter = PeekFilter(
        methods: {'GET'},
        hosts: {'api.example.com'},
        states: {PeekEntryState.completed},
      );
      expect(keep(filter), ['e1']);
      expect(keep(filter.copyWith(onlyErrors: true)), isEmpty);
    });

    test('counts active criteria', () {
      expect(const PeekFilter(methods: {'GET'}).activeCount, 1);
      expect(
        PeekFilter(
          methods: const {'GET'},
          hosts: const {'a'},
          onlyErrors: true,
          duration: const PeekDurationRange(max: Duration.zero),
          dates: PeekDateRange(from: DateTime.utc(2026)),
        ).activeCount,
        5,
      );
      expect(const PeekFilter(onlyPinned: true).isEmpty, isFalse);
    });

    test('copies, clearing criteria with empty sets and open ranges', () {
      final filter = PeekFilter(
        methods: const {'GET'},
        duration: const PeekDurationRange(max: Duration.zero),
        dates: PeekDateRange(from: DateTime.utc(2026)),
      );
      final cleared = filter.copyWith(
        methods: {},
        duration: PeekDurationRange.any,
      );
      expect(cleared.methods, isEmpty);
      expect(cleared.duration, PeekDurationRange.any);
      expect(cleared.activeCount, 1);
      expect(cleared.copyWith(dates: PeekDateRange.any).activeCount, 0);
      expect(filter.copyWith(), filter);
      expect(filter.copyWith(hosts: {'h'}).activeCount, 4);
    });

    test('compares by value regardless of set order', () {
      const one = PeekFilter(methods: {'GET', 'POST'}, statusCodes: {1, 2});
      const two = PeekFilter(methods: {'POST', 'GET'}, statusCodes: {2, 1});
      expect(one, two);
      expect(one.hashCode, two.hashCode);
      expect(one, isNot(one.copyWith(onlyPinned: true)));
      expect(one.toString(), 'PeekFilter(2 active)');
    });
  });

  group('PeekDurationRange and PeekDateRange', () {
    test('contain their bounds and print', () {
      const range = PeekDurationRange(
        min: Duration(seconds: 1),
        max: Duration(seconds: 2),
      );
      expect(range.contains(const Duration(seconds: 1)), isTrue);
      expect(range.contains(const Duration(seconds: 2)), isTrue);
      expect(range.contains(const Duration(milliseconds: 999)), isFalse);
      expect(range.isUnbounded, isFalse);
      expect(PeekDurationRange.any.contains(Duration.zero), isTrue);
      expect(range, isNot(PeekDurationRange.any));
      expect(range.hashCode, isNot(PeekDurationRange.any.hashCode));
      expect(
        range.toString(),
        'PeekDurationRange(0:00:01.000000..0:00:02.000000)',
      );

      final from = DateTime.utc(2026);
      final dates = PeekDateRange(from: from, to: from);
      expect(dates.contains(from), isTrue);
      expect(dates.contains(from.add(const Duration(seconds: 1))), isFalse);
      expect(dates, PeekDateRange(from: from, to: from));
      expect(dates, isNot(PeekDateRange.any));
      expect(PeekDateRange.any.isUnbounded, isTrue);
      expect(dates.toString(), 'PeekDateRange($from..$from)');
    });
  });
}
