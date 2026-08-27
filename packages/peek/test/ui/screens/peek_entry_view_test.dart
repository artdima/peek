import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peek/peek.dart';

import '../../support/entries.dart';
import '../../support/fake_store.dart';
import '../../support/pump.dart';

void main() {
  late FakePeekStore store;

  Future<void> pumpView(
    WidgetTester tester,
    PeekEntry entry, {
    Brightness brightness = Brightness.light,
    Size size = const Size(420, 760),
    double textScale = 1,
  }) async {
    final wired = fakePeek(entries: [entry]);
    store = wired.store;
    final controller = PeekController(wired.peek);
    addTearDown(controller.dispose);
    addTearDown(wired.peek.dispose);

    await pumpPeek(
      tester,
      PeekScope(controller: controller, child: PeekEntryScreen(entry.id)),
      brightness: brightness,
      size: size,
      textScale: textScale,
    );
  }

  Future<void> open(WidgetTester tester, String row) async {
    await tester.tap(find.widgetWithText(PeekListRow, row));
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
  }

  group('PeekEntryView', () {
    testWidgets('summarises the call above its cards', (tester) async {
      await pumpView(tester, e1);
      expect(find.widgetWithText(PeekListRow, '200'), findsOneWidget);
      expect(
        find.text('GET https://api.example.com/users', findRichText: true),
        findsOneWidget,
      );
      expect(find.text('Sent'), findsOneWidget);
      expect(find.text('Received'), findsOneWidget);
      expect(find.text('Headers: 1'), findsOneWidget);
      expect(find.widgetWithText(PeekListRow, 'dio'), findsOneWidget);
    });

    testWidgets('reads as one page, with nothing to switch between', (
      tester,
    ) async {
      await pumpView(tester, e1);
      expect(find.byType(PeekPill), findsNothing);
      expect(find.text('REQUEST'), findsOneWidget);
      expect(find.text('RESPONSE'), findsOneWidget);
      expect(find.text('DETAILS'), findsOneWidget);
      expect(find.text('ERROR'), findsNothing);

      await pumpView(tester, e5);
      expect(find.text('ERROR'), findsOneWidget);
    });

    testWidgets('lays the overview out in cards', (tester) async {
      await pumpView(tester, redirected);
      expect(find.text('REQUEST'), findsOneWidget);
      expect(find.text('RESPONSE'), findsOneWidget);
      expect(find.text('REDIRECTS'), findsOneWidget);
      expect(find.text('DETAILS'), findsOneWidget);
      expect(
        find.widgetWithText(PeekListRow, 'Response headers'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(PeekListRow, 'Request cookies'),
        findsOneWidget,
      );
      expect(find.widgetWithText(PeekListRow, '301 GET'), findsOneWidget);
    });

    testWidgets('opens a table of headers on a screen of its own', (
      tester,
    ) async {
      await pumpView(tester, e1);

      await tester.tap(find.widgetWithText(PeekListRow, 'Response headers'));
      await tester.pumpAndSettle();

      // A screen of its own, not the tab behind: the overview is gone.
      expect(find.byType(PeekKeyValuesView), findsOneWidget);
      expect(find.text('Content-Type'), findsOneWidget);
      expect(
        find.widgetWithText(PeekListRow, 'Response headers'),
        findsNothing,
      );

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(PeekListRow, 'Response headers'),
        findsOneWidget,
      );
    });

    testWidgets('leads from the error summary to the error itself', (
      tester,
    ) async {
      await pumpView(tester, e5);
      expect(find.text('ERROR'), findsOneWidget);
      expect(find.widgetWithText(PeekListRow, 'slow'), findsOneWidget);

      await tester.tap(
        find.ancestor(
          of: find.text('slow'),
          matching: find.byType(PeekListRow),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PeekErrorView), findsOneWidget);
      expect(find.widgetWithText(PeekListRow, 'Timed out'), findsOneWidget);
    });

    testWidgets('keeps the redirects card away when there are none', (
      tester,
    ) async {
      await pumpView(tester, e1);
      expect(find.text('REDIRECTS'), findsNothing);
      expect(find.text('ERROR'), findsNothing);
    });

    testWidgets('leads to the body on a screen of its own', (tester) async {
      await pumpView(tester, e1);

      await open(tester, 'Response body');
      expect(find.byType(PeekBodyView), findsOneWidget);
      expect(find.text('RESPONSE'), findsNothing);

      await back(tester);
      expect(find.text('RESPONSE'), findsOneWidget);
    });

    testWidgets('lists where the time went, on the timing screen', (
      tester,
    ) async {
      await pumpView(
        tester,
        e1.copyWith(
          timings: const PeekTimings(
            dns: Duration(milliseconds: 12),
            wait: Duration(milliseconds: 60),
          ),
        ),
      );

      await open(tester, 'Timing');
      expect(find.byType(PeekTimingView), findsOneWidget);
      expect(find.text('DNS'), findsOneWidget);
      expect(find.text('Waiting'), findsOneWidget);
      expect(find.text('60 ms'), findsOneWidget);
      // The times moved here with it.
      expect(find.widgetWithText(PeekListRow, 'Started'), findsOneWidget);
      expect(find.widgetWithText(PeekListRow, 'Finished'), findsOneWidget);
    });

    testWidgets('fills itself in when the call comes back', (tester) async {
      await pumpView(tester, e4);
      expect(find.widgetWithText(PeekListRow, 'Pending'), findsOneWidget);
      expect(find.text('ERROR'), findsNothing);

      // A finish is a new entry, not a copy: completedAt travels with the
      // response, and copyWith deliberately will not set one without it.
      store.upsert(
        PeekEntry(
          id: e4.id,
          request: e4.request,
          startedAt: e4.startedAt,
          source: e4.source,
          response: PeekResponse(statusCode: 200, statusMessage: 'OK'),
          completedAt: e4.startedAt.add(const Duration(milliseconds: 250)),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.widgetWithText(PeekListRow, '200 OK'), findsOneWidget);
      expect(find.widgetWithText(PeekListRow, '250 ms'), findsNWidgets(2));
    });

    testWidgets('survives large text', (tester) async {
      await pumpView(tester, e5, textScale: 2);
      expect(tester.takeException(), isNull);
    });
  });

  group('goldens', () {
    for (final brightness in Brightness.values) {
      testWidgets('a call in ${brightness.name}', (tester) async {
        await pumpView(tester, e2, brightness: brightness);
        expect(tester.takeException(), isNull);
        await expectGolden(
          find.byType(PeekEntryScreen),
          'entry-${brightness.name}',
        );
      });
    }
  });
}
