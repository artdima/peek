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

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(PeekPill, label));
    await tester.pump();
  }

  group('PeekEntryView', () {
    testWidgets('summarises the call above the tabs', (tester) async {
      await pumpView(tester, e1);
      expect(find.text('GET'), findsOneWidget);
      // The code is on the label and again as the overview's status.
      expect(find.widgetWithText(PeekStatusLabel, '200'), findsOneWidget);
      expect(find.widgetWithText(PeekListRow, '200'), findsOneWidget);
      expect(find.text('https://api.example.com/users'), findsOneWidget);
      expect(find.text('Sent'), findsOneWidget);
      expect(find.text('Received'), findsOneWidget);
      expect(find.widgetWithText(PeekListRow, 'dio'), findsOneWidget);
    });

    testWidgets('offers only the tabs the call has something for', (
      tester,
    ) async {
      await pumpView(tester, e1);
      expect(find.byType(PeekPill), findsNWidgets(3));
      expect(find.widgetWithText(PeekPill, 'Error'), findsNothing);
      expect(find.widgetWithText(PeekPill, 'Timing'), findsNothing);

      await pumpView(tester, e5);
      expect(find.widgetWithText(PeekPill, 'Error'), findsOneWidget);

      await pumpView(
        tester,
        e1.copyWith(
          timings: const PeekTimings(
            dns: Duration(milliseconds: 12),
            connect: Duration(milliseconds: 30),
            wait: Duration(milliseconds: 60),
          ),
        ),
      );
      expect(find.widgetWithText(PeekPill, 'Timing'), findsOneWidget);
    });

    testWidgets('moves between the tabs', (tester) async {
      await pumpView(tester, e1);
      expect(find.widgetWithText(PeekListRow, 'Started'), findsOneWidget);

      await openTab(tester, 'Request');
      expect(find.widgetWithText(PeekListRow, 'Method'), findsOneWidget);
      expect(find.widgetWithText(PeekListRow, 'Started'), findsNothing);

      await openTab(tester, 'Response');
      expect(find.widgetWithText(PeekListRow, 'Content type'), findsOneWidget);
      expect(
        find.widgetWithText(PeekListRow, 'application/json; charset=utf-8'),
        findsNothing,
      );
      expect(
        find.widgetWithText(PeekListRow, 'application/json'),
        findsOneWidget,
      );
    });

    testWidgets('says the response is not there yet', (tester) async {
      await pumpView(tester, e4);
      await openTab(tester, 'Response');
      expect(find.text('No response yet'), findsOneWidget);
    });

    testWidgets('names what stopped the call', (tester) async {
      await pumpView(tester, e5);
      await openTab(tester, 'Error');
      expect(find.widgetWithText(PeekListRow, 'Timed out'), findsOneWidget);
      expect(find.widgetWithText(PeekListRow, 'slow'), findsOneWidget);
    });

    testWidgets('lists where the time went', (tester) async {
      await pumpView(
        tester,
        e1.copyWith(
          timings: const PeekTimings(
            dns: Duration(milliseconds: 12),
            wait: Duration(milliseconds: 60),
          ),
        ),
      );
      await openTab(tester, 'Timing');
      expect(find.widgetWithText(PeekListRow, 'DNS'), findsOneWidget);
      expect(find.widgetWithText(PeekListRow, 'Waiting'), findsOneWidget);
      expect(find.widgetWithText(PeekListRow, '60 ms'), findsOneWidget);
    });

    testWidgets('fills itself in when the call comes back', (tester) async {
      await pumpView(tester, e4);
      expect(find.widgetWithText(PeekStatusLabel, 'Pending'), findsOneWidget);
      expect(find.widgetWithText(PeekPill, 'Error'), findsNothing);

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

      expect(find.widgetWithText(PeekStatusLabel, '200 OK'), findsOneWidget);
      expect(find.widgetWithText(PeekListRow, '250 ms'), findsOneWidget);
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
