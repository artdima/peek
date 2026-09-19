import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peek/peek.dart';

import '../../support/entries.dart';
import '../../support/fake_store.dart';
import '../../support/pump.dart';

void main() {
  /// Drives animations frame by frame. `pumpAndSettle` is out: a pending
  /// call's spinner never stops, and a route that finished leaving needs
  /// the frame after its last one.
  Future<void> settle(WidgetTester tester) async {
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  /// What the filter button's badge reads, or zero when it has none.
  int badgeOf(WidgetTester tester) =>
      tester
          .widget<PeekIconButton>(
            find.ancestor(
              of: find.byIcon(Icons.filter_list),
              matching: find.byType(PeekIconButton),
            ),
          )
          .badgeCount;

  /// The bar's pause button.
  PeekIconButton pauseButton(WidgetTester tester) =>
      tester.widget<PeekIconButton>(
        find.ancestor(
          of: find.byIcon(Icons.pause),
          matching: find.byType(PeekIconButton),
        ),
      );

  late Peek peek;
  late FakePeekStore store;
  late PeekController controller;

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<PeekEntry> entries = const [],
    Brightness brightness = Brightness.light,
    Size size = const Size(420, 700),
    double textScale = 1,
    EdgeInsets padding = EdgeInsets.zero,
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
            padding: padding,
            viewPadding: padding,
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
      // The collapsing bar draws the name twice: large, and small for
      // when it has been scrolled under.
      expect(find.text('Console'), findsNWidgets(2));
      expect(find.byType(PeekEntryTile), findsNWidgets(6));
      expect(find.text('/users'), findsOneWidget);

      // Unfiltered, the count lives only on the All pill.
      expect(
        find.descendant(
          of: find.byType(PeekQuickBar),
          matching: find.text('6'),
        ),
        findsOneWidget,
      );
      expect(find.text('6'), findsOneWidget);
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
      await tester.enterText(find.byType(CupertinoSearchTextField), 'login');
      await tester.pump(PeekController.searchDebounce);
      await tester.pump();

      expect(find.byType(PeekEntryTile), findsOneWidget);
      expect(find.text('1 of 6'), findsOneWidget);
    });

    testWidgets('keeps the search field over an empty result', (tester) async {
      await pumpScreen(tester, entries: fixtures);
      await tester.enterText(
        find.byType(CupertinoSearchTextField),
        'nothing-matches-this',
      );
      await tester.pump(PeekController.searchDebounce);
      await tester.pump();

      expect(find.text('Nothing matches'), findsOneWidget);
      expect(find.byType(PeekSearchBar), findsOneWidget);

      await tester.tap(find.text('Clear filters'));
      await tester.pump();
      expect(find.byType(PeekEntryTile), findsNWidgets(6));
    });

    testWidgets('opens the filters sheet from the app bar', (tester) async {
      await pumpScreen(tester, entries: fixtures);
      await tester.tap(find.byTooltip('Filters'));
      await settle(tester);

      expect(find.byType(PeekFiltersSheet), findsOneWidget);
      await tester.tap(find.widgetWithText(PeekPill, '4xx'));
      await settle(tester);
      expect(controller.entries, hasLength(1));
    });

    testWidgets('badges the filter button with what is set', (tester) async {
      await pumpScreen(tester, entries: fixtures);
      expect(badgeOf(tester), 0);

      controller.filter = const PeekFilter(
        onlyErrors: true,
        methods: {'GET'},
        query: PeekSearchQuery('users'),
      );
      await tester.pump();

      expect(badgeOf(tester), 2);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('leaves the last row clear of the home indicator', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        entries: uiFixtures,
        size: const Size(420, 400),
        padding: const EdgeInsets.only(bottom: 34),
      );

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -4000));
      await tester.pump();

      final last = tester.getRect(find.byType(PeekEntryTile).last);
      expect(last.bottom, lessThanOrEqualTo(400 - 34));
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

    testWidgets('pauses and resumes recording from the bar', (tester) async {
      await pumpScreen(tester, entries: fixtures);
      expect(find.text('Recording is paused'), findsNothing);
      expect(find.byTooltip('Resume'), findsNothing);
      expect(pauseButton(tester).selected, isFalse);

      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      expect(peek.isPaused, isTrue);
      expect(find.byTooltip('Pause'), findsNothing);
      expect(pauseButton(tester).selected, isTrue);
      expect(find.text('Recording is paused'), findsOneWidget);

      await tester.tap(find.byTooltip('Resume'));
      await tester.pump();
      expect(peek.isPaused, isFalse);
      expect(find.byTooltip('Pause'), findsOneWidget);
      expect(pauseButton(tester).selected, isFalse);
      expect(find.text('Recording is paused'), findsNothing);
    });

    testWidgets('resumes from the banner too', (tester) async {
      await pumpScreen(tester, entries: fixtures);
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      expect(peek.isPaused, isTrue);

      await tester.tap(find.text('Resume'));
      await tester.pump();
      expect(peek.isPaused, isFalse);
      expect(find.text('Recording is paused'), findsNothing);
    });

    testWidgets('says so when the app paused recording itself', (tester) async {
      await pumpScreen(tester, entries: fixtures);

      peek.pause();
      await tester.pump();
      await tester.pump();
      expect(find.text('Recording is paused'), findsOneWidget);
      expect(find.byTooltip('Resume'), findsOneWidget);

      peek.resume();
      await tester.pump();
      await tester.pump();
      expect(find.text('Recording is paused'), findsNothing);
      expect(find.byTooltip('Pause'), findsOneWidget);
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
      await tester.tap(find.text('Clear').last);
      await settle(tester);
      expect(store.length, 0);
      expect(find.text('No requests yet'), findsOneWidget);
    });

    testWidgets('cannot clear an empty store', (tester) async {
      await pumpScreen(tester);
      final button = tester.widget<PeekIconButton>(
        find.ancestor(
          of: find.byIcon(Icons.delete_outline),
          matching: find.byType(PeekIconButton),
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
      await tester.pump(const Duration(seconds: 2));
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
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
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

    testWidgets('the paused screen', (tester) async {
      await pumpScreen(tester, entries: uiFixtures, size: const Size(420, 720));
      controller.pause();
      await tester.pump();
      expect(tester.takeException(), isNull);
      await expectGolden(find.byType(PeekScreen), 'screen-paused');
    });
  });
}
