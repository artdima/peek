import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peek/peek.dart';

import '../../support/entries.dart';
import '../../support/fake_store.dart';
import '../../support/pump.dart';

void main() {
  const strings = PeekStrings();

  late Peek peek;
  late PeekController controller;

  setUp(() {
    peek = fakePeek(entries: fixtures).peek;
    controller = PeekController(peek);
  });

  tearDown(() {
    controller.dispose();
    peek.dispose();
  });

  Future<void> pumpFilters(WidgetTester tester, PeekFilter filter) async {
    controller.filter = filter;
    await pumpPeek(
      tester,
      PeekScope(
        controller: controller,
        child: const Align(
          alignment: Alignment.topCenter,
          child: PeekActiveFilters(),
        ),
      ),
      size: const Size(420, 400),
    );
    await tester.pump();
  }

  group('PeekActiveFilters', () {
    testWidgets('shows nothing while nothing is filtered', (tester) async {
      await pumpFilters(tester, PeekFilter.none);
      expect(find.byType(PeekPill), findsNothing);
    });

    testWidgets('names every value the list is narrowed by', (tester) async {
      await pumpFilters(
        tester,
        PeekFilter(
          onlyErrors: true,
          onlyPinned: true,
          statusClasses: const {PeekStatusClass.serverError},
          statusCodes: const {401},
          methods: const {'GET'},
          hosts: const {'api.example.com'},
          contentTypes: const {'application/json'},
          states: const {PeekEntryState.failed},
          sources: const {'dio'},
          duration: const PeekDurationRange(min: Duration(seconds: 1)),
          dates: PeekDateRange(from: fixtureStart),
        ),
      );

      for (final label in [
        strings.errorsOnly,
        strings.pinnedOnly,
        strings.statusClassName(PeekStatusClass.serverError),
        '401',
        'GET',
        'api.example.com',
        'application/json',
        strings.entryState(PeekEntryState.failed),
        'dio',
      ]) {
        expect(
          find.widgetWithText(PeekPill, label),
          findsOneWidget,
          reason: 'no chip for $label',
        );
      }
      expect(find.byType(PeekPill), findsNWidgets(11));
    });

    testWidgets('a chip drops its own value and leaves the rest', (
      tester,
    ) async {
      await pumpFilters(
        tester,
        const PeekFilter(methods: {'GET', 'POST'}, statusCodes: {401}),
      );

      await tester.tap(find.widgetWithText(PeekPill, 'GET'));
      await tester.pump();

      expect(controller.filter.methods, {'POST'});
      expect(controller.filter.statusCodes, {401});
      expect(find.widgetWithText(PeekPill, 'GET'), findsNothing);
      expect(find.widgetWithText(PeekPill, 'POST'), findsOneWidget);
    });

    testWidgets('a range chip says what it bounds and drops it', (
      tester,
    ) async {
      final dates = PeekDateRange(from: fixtureStart);
      await pumpFilters(
        tester,
        PeekFilter(
          duration: const PeekDurationRange(min: Duration(seconds: 1)),
          dates: dates,
        ),
      );

      expect(find.text(strings.dateFilter(dates)), findsOneWidget);
      await tester.tap(find.text(strings.dateFilter(dates)));
      await tester.pump();
      expect(controller.filter.dates.isUnbounded, isTrue);
      expect(controller.filter.duration.isUnbounded, isFalse);
    });

    testWidgets('a long value does not stretch the row', (tester) async {
      await pumpFilters(
        tester,
        const PeekFilter(hosts: {'a-very-long-host-name.example.com'}),
      );

      expect(tester.getSize(find.byType(PeekPill)).width, lessThan(220));
    });
  });
}
