import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peek/peek.dart';

import '../../support/entries.dart';
import '../../support/fake_store.dart';
import '../../support/pump.dart';

void main() {
  /// Settles transient animations without waiting for a pending call's
  /// spinner, which never stops.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  late Peek peek;
  late FakePeekStore store;
  late PeekController controller;

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<PeekEntry> entries = const [],
    Brightness brightness = Brightness.light,
    Size size = const Size(420, 700),
    double textScale = 1,
  }) async {
    final wired = fakePeek(entries: entries);
    peek = wired.peek;
    store = wired.store;
    controller = PeekController(peek);
    addTearDown(controller.dispose);
    addTearDown(peek.dispose);

    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: brightness,
          colorSchemeSeed: const Color(0xFF3DDC84),
        ),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: PeekScreen(peek: peek, controller: controller),
        ),
      ),
    );
    await tester.pump();
  }

  group('PeekScreen', () {
    testWidgets('lists what the store holds and counts it', (tester) async {
      await pumpScreen(tester, entries: fixtures);
      expect(find.text('Requests'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(find.byType(PeekEntryTile), findsNWidgets(6));
      expect(find.text('/users'), findsOneWidget);
    });

    testWidgets('shows how many of the total are visible when filtered', (
      tester,
    ) async {
      await pumpScreen(tester, entries: fixtures);
      controller.filter = const PeekFilter(onlyErrors: true);
      await tester.pump();
      expect(find.text('3 of 6'), findsOneWidget);
      expect(find.byType(PeekEntryTile), findsNWidgets(3));
    });

    testWidgets('filters the list from the search field', (tester) async {
      await pumpScreen(tester, entries: fixtures);
      await tester.enterText(find.byType(TextField), 'login');
      await tester.pump(PeekController.searchDebounce);
      await tester.pump();

      expect(find.byType(PeekEntryTile), findsOneWidget);
      expect(find.text('1 of 6'), findsOneWidget);
    });

    testWidgets('keeps the search field over an empty result', (tester) async {
      await pumpScreen(tester, entries: fixtures);
      await tester.enterText(find.byType(TextField), 'nothing-matches-this');
      await tester.pump(PeekController.searchDebounce);
      await tester.pump();

      expect(find.text('Nothing matches'), findsOneWidget);
      expect(find.byType(PeekSearchBar), findsOneWidget);

      await tester.tap(find.text('Clear filters'));
      await tester.pump();
      expect(find.byType(PeekEntryTile), findsNWidgets(6));
    });

    testWidgets('offers an empty state before anything arrives', (
      tester,
    ) async {
      await pumpScreen(tester);
      expect(find.text('No requests yet'), findsOneWidget);
      expect(find.byType(PeekEntryTile), findsNothing);
    });

    testWidgets('offers a different empty state when a filter hides all', (
      tester,
    ) async {
      await pumpScreen(tester, entries: fixtures);
      controller.filter = const PeekFilter(hosts: {'nowhere.example.com'});
      await tester.pump();

      expect(find.text('Nothing matches'), findsOneWidget);
      await tester.tap(find.text('Clear filters'));
      await tester.pump();
      expect(find.byType(PeekEntryTile), findsNWidgets(6));
    });

    testWidgets('follows the store as calls arrive', (tester) async {
      await pumpScreen(tester);
      store.upsert(e1);
      await tester.pump();
      await tester.pump();
      expect(find.byType(PeekEntryTile), findsOneWidget);
      expect(find.text('/users'), findsOneWidget);
    });

    testWidgets('pauses and resumes recording', (tester) async {
      await pumpScreen(tester, entries: fixtures);
      expect(find.text('Recording is paused'), findsNothing);

      await tester.tap(find.byTooltip('Pause recording'));
      await tester.pump();
      expect(peek.isPaused, isTrue);
      expect(find.text('Recording is paused'), findsOneWidget);

      await tester.tap(find.byTooltip('Resume recording'));
      await tester.pump();
      expect(peek.isPaused, isFalse);
      expect(find.text('Recording is paused'), findsNothing);
    });

    testWidgets('asks before clearing and clears when confirmed', (
      tester,
    ) async {
      await pumpScreen(tester, entries: fixtures);
      await tester.tap(find.byTooltip('Clear'));
      await settle(tester);
      expect(find.text('Clear all requests?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await settle(tester);
      expect(find.byType(PeekEntryTile), findsNWidgets(6));

      await tester.tap(find.byTooltip('Clear'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
      await settle(tester);
      expect(store.length, 0);
      expect(find.text('No requests yet'), findsOneWidget);
    });

    testWidgets('cannot clear an empty store', (tester) async {
      await pumpScreen(tester);
      final button = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.delete_outline),
          matching: find.byType(IconButton),
        ),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('pins from a row menu', (tester) async {
      await pumpScreen(tester, entries: [e1]);
      await tester.longPress(find.byType(PeekEntryTile));
      await settle(tester);
      await tester.tap(find.text('Pin'));
      await settle(tester);
      expect(store.find(e1.id)?.isPinned, isTrue);
      expect(find.byIcon(Icons.push_pin), findsOneWidget);
    });

    testWidgets('copies a URL from a row menu', (tester) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await pumpScreen(tester, entries: [e1]);
      await tester.longPress(find.byType(PeekEntryTile));
      await settle(tester);
      await tester.tap(find.text('Copy as cURL'));
      await settle(tester);

      expect(copied.single, startsWith('curl '));
      expect(find.text('Copied'), findsOneWidget);
    });

    testWidgets('creates its own controller when none is given', (
      tester,
    ) async {
      final (:peek, :store, :clock) = fakePeek(entries: [e1]);
      addTearDown(peek.dispose);
      await pumpPeek(tester, PeekScreen(peek: peek));
      expect(find.byType(PeekEntryTile), findsOneWidget);
    });

    testWidgets('survives large text', (tester) async {
      await pumpScreen(tester, entries: fixtures, textScale: 2);
      expect(tester.takeException(), isNull);
    });
  });

  group('PeekEntryList arrivals', () {
    testWidgets('holds still and offers a jump when scrolled away', (
      tester,
    ) async {
      await pumpScreen(tester, entries: uiFixtures, size: const Size(420, 400));
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();
      expect(find.textContaining('new request'), findsNothing);

      store.upsert(
        PeekEntry(
          id: const PeekId('fresh'),
          request: PeekRequest(
            method: 'GET',
            uri: Uri.parse('https://api.example.com/fresh'),
          ),
          startedAt: fixtureStart.add(const Duration(minutes: 1)),
          source: 'dio',
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('1 new request'), findsOneWidget);

      await tester.tap(find.text('1 new request'));
      await settle(tester);
      expect(find.textContaining('new request'), findsNothing);
      expect(
        tester
            .widget<Scrollable>(find.byType(Scrollable).first)
            .controller
            ?.offset,
        0,
      );
    });

    testWidgets('says nothing while the list sits at the top', (tester) async {
      await pumpScreen(tester, entries: [e1], size: const Size(420, 400));
      store.upsert(
        PeekEntry(
          id: const PeekId('fresh'),
          request: PeekRequest(
            method: 'GET',
            uri: Uri.parse('https://api.example.com/fresh'),
          ),
          startedAt: fixtureStart.add(const Duration(minutes: 1)),
          source: 'dio',
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('new request'), findsNothing);
      expect(find.byType(PeekEntryTile), findsNWidgets(2));
    });
  });

  group('goldens', () {
    for (final brightness in Brightness.values) {
      testWidgets('the list screen in ${brightness.name}', (tester) async {
        await pumpScreen(
          tester,
          entries: uiFixtures,
          brightness: brightness,
          size: const Size(420, 720),
        );
        expect(tester.takeException(), isNull);
        await expectGolden(
          find.byType(PeekScreen),
          'screen-${brightness.name}',
        );
      });
    }

    testWidgets('the empty screen', (tester) async {
      await pumpScreen(tester, size: const Size(420, 500));
      await expectGolden(find.byType(PeekScreen), 'screen-empty');
    });
  });
}
