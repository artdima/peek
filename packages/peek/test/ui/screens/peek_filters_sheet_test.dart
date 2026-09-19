import 'dart:async';

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

  Future<void> settle(WidgetTester tester) async {
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  /// Opens the sheet [title] names and waits for it.
  Future<void> openRow(WidgetTester tester, String title) async {
    await tester.ensureVisible(find.widgetWithText(PeekListRow, title));
    await tester.pump();
    await tester.tap(find.text(title));
    await settle(tester);
  }

  /// Taps a row of the picker that is open.
  Future<void> tapRow(WidgetTester tester, String label) async {
    final row = find.widgetWithText(PeekListRow, label).last;
    await tester.ensureVisible(row);
    await tester.pump();
    await tester.tap(row);
    await settle(tester);
  }

  /// What the row for [title] says it is narrowed to.
  String valueOf(WidgetTester tester, String title) {
    final row = tester.widget<PeekListRow>(
      find.widgetWithText(PeekListRow, title).first,
    );
    return row.value ?? '';
  }

  group('PeekFiltersSheet', () {
    testWidgets('names every criterion and says what is set', (tester) async {
      await pumpSheet(tester);

      for (final title in [
        'Status',
        'Method',
        'Host',
        'Content type',
        'State',
        'Source',
        'Duration',
        'Started',
      ]) {
        expect(
          find.widgetWithText(PeekListRow, title),
          findsOneWidget,
          reason: title,
        );
        expect(valueOf(tester, title), 'Any', reason: title);
      }

      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('picks values from a criterion of its own', (tester) async {
      await pumpSheet(tester);
      await openRow(tester, 'Method');

      expect(find.text('GET'), findsOneWidget);
      await tapRow(tester, 'GET');
      expect(controller.filter.methods, {'GET'});

      await tapRow(tester, 'Any');
      expect(controller.filter.methods, isEmpty);
    });

    testWidgets('shows the chosen value on the row and drops it', (
      tester,
    ) async {
      await pumpSheet(tester);
      controller.filter = const PeekFilter(methods: {'GET', 'POST'});
      await tester.pump();

      expect(find.text('GET +1'), findsOneWidget);
      await tester.tap(find.text('GET +1'));
      await tester.pump();
      expect(controller.filter.methods, isEmpty);
      expect(valueOf(tester, 'Method'), 'Any');
    });

    testWidgets('offers classes and codes under status', (tester) async {
      await pumpSheet(tester);
      await openRow(tester, 'Status');

      expect(find.text('CLASS'), findsOneWidget);
      expect(find.text('CODE'), findsOneWidget);
      expect(find.text('2xx'), findsOneWidget);
      expect(find.text('200'), findsOneWidget);

      await tapRow(tester, '4xx');
      expect(controller.filter.statusClasses, {PeekStatusClass.clientError});
      expect(idsOf(controller.entries), ['e2']);
    });

    testWidgets('narrows by how long a call took', (tester) async {
      await pumpSheet(tester);
      await openRow(tester, 'Duration');

      await tester.tap(find.text('Over 1 s'));
      await settle(tester);

      expect(controller.filter.duration.min, const Duration(seconds: 1));
      expect(idsOf(controller.entries), ['e5']);
      expect(valueOf(tester, 'Duration'), '');
      expect(find.text('Over 1 s'), findsOneWidget);
    });

    testWidgets('looks back over a window', (tester) async {
      await pumpSheet(tester);
      await openRow(tester, 'Started');
      await tester.tap(find.text('Last 5 min'));
      await settle(tester);
      expect(controller.entries, isEmpty);

      await openRow(tester, 'Started');
      expect(find.text('Last 5 min'), findsOneWidget);
      await tester.tap(find.text('Last 15 min'));
      await settle(tester);
      expect(controller.entries, hasLength(6));
    });

    testWidgets('says how many are left once something is set', (tester) async {
      await pumpSheet(tester);
      controller.filter = const PeekFilter(onlyErrors: true);
      await tester.pump();

      expect(idsOf(controller.entries), ['e6', 'e5', 'e2']);
      expect(find.text('Show 3 requests'), findsOneWidget);
      expect(find.text('Close'), findsNothing);
    });

    testWidgets('closes with the button', (tester) async {
      late BuildContext host;
      final wired = fakePeek(entries: fixtures);
      controller = PeekController(wired.peek);
      addTearDown(controller.dispose);
      addTearDown(wired.peek.dispose);

      await pumpPeek(
        tester,
        PeekScope(
          controller: controller,
          child: Builder(
            builder: (context) {
              host = context;
              return const SizedBox.expand();
            },
          ),
        ),
      );

      unawaited(showPeekFilters(host));
      await settle(tester);
      expect(find.byType(PeekFiltersSheet), findsOneWidget);

      await tester.tap(find.text('Close'));
      await settle(tester);
      expect(find.byType(PeekFiltersSheet), findsNothing);
    });

    testWidgets('clears everything at once', (tester) async {
      await pumpSheet(tester);
      controller.filter = const PeekFilter(onlyErrors: true, methods: {'GET'});
      await tester.pump();
      expect(controller.filter.activeCount, 2);

      await tester.tap(find.text('Clear filters'));
      await tester.pump();
      expect(controller.filter.isEmpty, isTrue);
      expect(controller.entries, hasLength(6));
    });

    testWidgets('has nothing to clear until something is set', (tester) async {
      await pumpSheet(tester);
      final reset = find.widgetWithText(PeekTextButton, 'Clear filters');
      expect(tester.widget<PeekTextButton>(reset).onPressed, isNull);

      controller.filter = const PeekFilter(onlyErrors: true);
      await tester.pump();
      expect(tester.widget<PeekTextButton>(reset).onPressed, isNotNull);
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
