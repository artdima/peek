import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peek/peek.dart';

import '../../support/entries.dart';
import '../../support/fake_store.dart';
import '../../support/pump.dart';

void main() {
  late PeekController controller;

  Future<void> pumpSheet(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    double textScale = 1,
    Size size = const Size(420, 740),
  }) async {
    final wired = fakePeek(entries: fixtures);
    // Just after the fixtures, so a window reaching back tells them apart.
    wired.clock.advance(
      fixtureStart.difference(DateTime.utc(2026)) + const Duration(minutes: 10),
    );
    controller = PeekController(wired.peek);
    addTearDown(controller.dispose);
    addTearDown(wired.peek.dispose);

    await pumpPeek(
      tester,
      PeekScope(controller: controller, child: const PeekFiltersSheet()),
      brightness: brightness,
      textScale: textScale,
      size: size,
    );
  }

  /// Scrolls [label] into view and taps it.
  Future<void> tapChip(WidgetTester tester, String label) async {
    final chip = find.widgetWithText(FilterChip, label);
    await tester.ensureVisible(chip);
    await tester.pump();
    await tester.tap(chip);
    await tester.pump();
  }

  group('PeekFiltersSheet', () {
    testWidgets('offers what the entries contain, counted', (tester) async {
      await pumpSheet(tester);
      expect(find.text('2xx'), findsOneWidget);
      expect(find.text('4xx'), findsOneWidget);
      expect(find.text('200'), findsOneWidget);
      expect(find.text('GET'), findsOneWidget);
      expect(find.text('api.example.com'), findsOneWidget);
      expect(find.text('application/json'), findsOneWidget);
      expect(find.text('dio'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets('applies a status class as it is picked', (tester) async {
      await pumpSheet(tester);
      await tapChip(tester, '4xx');

      expect(controller.filter.statusClasses, {PeekStatusClass.clientError});
      expect(idsOf(controller.entries), ['e2']);

      await tapChip(tester, '4xx');
      expect(controller.filter.statusClasses, isEmpty);
      expect(controller.entries, hasLength(6));
    });

    testWidgets('keeps only errors, then only pinned', (tester) async {
      await pumpSheet(tester);
      await tapChip(tester, 'Errors');
      expect(controller.filter.onlyErrors, isTrue);
      expect(idsOf(controller.entries), ['e6', 'e5', 'e2']);

      await tapChip(tester, 'Pinned');
      expect(idsOf(controller.entries), ['e5']);
    });

    testWidgets('narrows by how long a call took', (tester) async {
      await pumpSheet(tester);
      await tapChip(tester, 'Over 1 s');

      expect(controller.filter.duration.min, const Duration(seconds: 1));
      expect(idsOf(controller.entries), ['e5']);
    });

    testWidgets('looks back over a window', (tester) async {
      await pumpSheet(tester);
      await tapChip(tester, 'Last 5 min');
      expect(controller.entries, isEmpty);

      await tapChip(tester, 'Last 15 min');
      expect(controller.entries, hasLength(6));
    });

    testWidgets('shows a cut-off it can no longer offer', (tester) async {
      await pumpSheet(tester);
      controller.filter = PeekFilter(dates: PeekDateRange(from: fixtureStart));
      await tester.pump();

      final chip = find.widgetWithText(FilterChip, 'Since 12:00');
      expect(chip, findsOneWidget);
      expect(tester.widget<FilterChip>(chip).selected, isTrue);

      await tapChip(tester, 'Since 12:00');
      expect(controller.filter.dates.isUnbounded, isTrue);
    });

    testWidgets('clears everything at once', (tester) async {
      await pumpSheet(tester);
      await tapChip(tester, 'Errors');
      await tapChip(tester, 'GET');
      expect(controller.filter.activeCount, 2);

      await tester.tap(find.text('Clear filters'));
      await tester.pump();
      expect(controller.filter.isEmpty, isTrue);
      expect(controller.entries, hasLength(6));
    });

    testWidgets('has nothing to clear until something is set', (tester) async {
      await pumpSheet(tester);
      final reset = find.widgetWithText(TextButton, 'Clear filters');
      expect(tester.widget<TextButton>(reset).onPressed, isNull);

      await tapChip(tester, 'Errors');
      expect(tester.widget<TextButton>(reset).onPressed, isNotNull);
    });

    testWidgets('survives large text', (tester) async {
      await pumpSheet(tester, textScale: 2);
      expect(tester.takeException(), isNull);
    });
  });

  group('goldens', () {
    for (final brightness in Brightness.values) {
      testWidgets('the filters sheet in ${brightness.name}', (tester) async {
        await pumpSheet(tester, brightness: brightness);
        expect(tester.takeException(), isNull);
        await expectGolden(
          find.byType(PeekFiltersSheet),
          'filters-${brightness.name}',
        );
      });
    }
  });
}
