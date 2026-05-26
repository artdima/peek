import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peek/peek.dart';

import '../../support/entries.dart';
import '../../support/fake_store.dart';
import '../../support/pump.dart';

void main() {
  const timings = PeekTimings(
    blocked: Duration(milliseconds: 9),
    dns: Duration(milliseconds: 22),
    connect: Duration(milliseconds: 124),
    ssl: Duration(milliseconds: 102),
    send: Duration(milliseconds: 4),
    wait: Duration(milliseconds: 41),
    receive: Duration(milliseconds: 2),
  );

  Future<void> pumpTiming(
    WidgetTester tester,
    PeekEntry entry, {
    Brightness brightness = Brightness.light,
    Size size = const Size(420, 600),
    double textScale = 1,
  }) async {
    final peek = fakePeek(entries: fixtures).peek;
    final controller = PeekController(peek);
    addTearDown(controller.dispose);
    addTearDown(peek.dispose);
    await pumpPeek(
      tester,
      PeekScope(
        controller: controller,
        child: SingleChildScrollView(child: PeekTimingView(entry)),
      ),
      brightness: brightness,
      size: size,
      textScale: textScale,
    );
  }

  group('PeekTimingView', () {
    testWidgets('accounts for the whole call', (tester) async {
      await pumpTiming(tester, e1.copyWith(timings: timings));

      expect(find.widgetWithText(PeekListRow, 'Duration'), findsOneWidget);
      expect(find.widgetWithText(PeekListRow, '120 ms'), findsOneWidget);
      expect(find.widgetWithText(PeekListRow, 'Started'), findsOneWidget);
      expect(find.widgetWithText(PeekListRow, 'Finished'), findsOneWidget);
    });

    testWidgets('lays the phases out one after another', (tester) async {
      await pumpTiming(tester, e1.copyWith(timings: timings));

      expect(find.text('PHASES'), findsOneWidget);
      expect(find.text('Queued'), findsOneWidget);
      expect(find.text('DNS'), findsOneWidget);
      expect(find.text('Secure'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);
      expect(find.text('124 ms'), findsOneWidget);

      // Each bar starts where the one before it ended.
      final dns = tester.getTopLeft(_barOf(tester, 'DNS'));
      final connect = tester.getTopLeft(_barOf(tester, 'Connect'));
      expect(connect.dx, greaterThan(dns.dx));
    });

    testWidgets('says when a source reports no phases', (tester) async {
      await pumpTiming(tester, e1.copyWith(timings: const PeekTimings()));

      expect(find.text('PHASES'), findsNothing);
      expect(
        find.text('This source does not report where the time went.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(PeekListRow, '120 ms'), findsOneWidget);
    });

    testWidgets('survives large text', (tester) async {
      await pumpTiming(tester, e1.copyWith(timings: timings), textScale: 2);
      expect(tester.takeException(), isNull);
    });
  });

  group('goldens', () {
    for (final brightness in Brightness.values) {
      testWidgets('the phases in ${brightness.name}', (tester) async {
        await pumpTiming(
          tester,
          e1.copyWith(timings: timings),
          brightness: brightness,
          size: const Size(420, 480),
        );
        expect(tester.takeException(), isNull);
        await expectGolden(
          find.byType(PeekTimingView),
          'timing-${brightness.name}',
        );
      });
    }

    testWidgets('a call with no phases at all', (tester) async {
      await pumpTiming(
        tester,
        e1.copyWith(timings: const PeekTimings()),
        size: const Size(420, 260),
      );
      expect(tester.takeException(), isNull);
      await expectGolden(find.byType(PeekTimingView), 'timing-total-only');
    });
  });
}

/// The bar drawn beside the phase called [name].
Finder _barOf(WidgetTester tester, String name) => find.descendant(
  of: find.ancestor(of: find.text(name), matching: find.byType(Row)).first,
  matching: find.byType(DecoratedBox),
);
