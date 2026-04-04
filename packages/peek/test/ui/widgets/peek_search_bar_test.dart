import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peek/peek.dart';

import '../../support/entries.dart';
import '../../support/fake_store.dart';
import '../../support/pump.dart';

void main() {
  late PeekController controller;

  Future<void> pumpBar(WidgetTester tester, {double textScale = 1}) async {
    final peek = fakePeek(entries: fixtures).peek;
    controller = PeekController(peek);
    addTearDown(controller.dispose);
    addTearDown(peek.dispose);
    await pumpPeek(
      tester,
      PeekScope(
        controller: controller,
        child: const Column(
          children: [PeekSearchBar(), Expanded(child: PeekEntryList())],
        ),
      ),
      size: const Size(420, 700),
      textScale: textScale,
    );
  }

  /// Types [text] and waits out the controller's debounce.
  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
    await tester.pump(PeekController.searchDebounce);
    await tester.pump();
  }

  String fieldText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  group('PeekSearchBar', () {
    testWidgets('filters the list once typing pauses', (tester) async {
      await pumpBar(tester);
      expect(find.byType(PeekEntryTile), findsNWidgets(6));

      await tester.enterText(find.byType(TextField), 'login');
      await tester.pump();
      expect(controller.searchText, 'login');
      expect(controller.isSearchPending, isTrue);
      expect(find.byType(PeekEntryTile), findsNWidgets(6));

      await tester.pump(PeekController.searchDebounce);
      await tester.pump();
      expect(controller.isSearchPending, isFalse);
      expect(find.byType(PeekEntryTile), findsOneWidget);
    });

    testWidgets('empties the field and the search', (tester) async {
      await pumpBar(tester);
      await search(tester, 'users');
      expect(find.byType(PeekEntryTile), findsNWidgets(2));

      await tester.tap(find.byTooltip('Clear search'));
      await tester.pump(PeekController.searchDebounce);
      await tester.pump();
      expect(fieldText(tester), isEmpty);
      expect(controller.searchText, isEmpty);
      expect(find.byType(PeekEntryTile), findsNWidgets(6));
    });

    testWidgets('offers the scopes only while there is a search', (
      tester,
    ) async {
      await pumpBar(tester);
      expect(find.byType(FilterChip), findsNothing);

      await search(tester, 'users');
      expect(find.byType(FilterChip), findsNWidgets(4));
      expect(find.text('URL'), findsOneWidget);
      expect(find.text('Headers'), findsOneWidget);
      expect(find.text('Body'), findsOneWidget);
      expect(find.text('Error'), findsOneWidget);
    });

    testWidgets('narrows where the search looks', (tester) async {
      await pumpBar(tester);
      await search(tester, 'users');

      await tester.tap(find.widgetWithText(FilterChip, 'Body'));
      await tester.pump();
      expect(
        controller.filter.query.scopes,
        isNot(contains(PeekSearchScope.requestBody)),
      );
      expect(
        controller.filter.query.scopes,
        isNot(contains(PeekSearchScope.responseBody)),
      );

      await tester.tap(find.widgetWithText(FilterChip, 'Body'));
      await tester.pump();
      expect(
        controller.filter.query.scopes,
        containsAll([
          PeekSearchScope.requestBody,
          PeekSearchScope.responseBody,
        ]),
      );
    });

    testWidgets('will not turn off the last scope left', (tester) async {
      await pumpBar(tester);
      await search(tester, 'users');

      for (final label in ['Headers', 'Body', 'Error']) {
        await tester.tap(find.widgetWithText(FilterChip, label));
        await tester.pump();
      }
      expect(controller.filter.query.scopes, {PeekSearchScope.url});

      final url = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, 'URL'),
      );
      expect(url.selected, isTrue);
      expect(url.onSelected, isNull);
    });

    testWidgets('marks what matched, and only where it looked', (tester) async {
      String marked() =>
          tester
              .widget<PeekEntryTile>(find.byType(PeekEntryTile).first)
              .highlight;

      // Matches a body, so the row survives the URL scope being turned off.
      await pumpBar(tester);
      await search(tester, 'e1');
      expect(marked(), 'e1');

      await tester.tap(find.widgetWithText(FilterChip, 'URL'));
      await tester.pump();
      expect(find.byType(PeekEntryTile), findsOneWidget);
      expect(marked(), isEmpty);
    });

    testWidgets('follows a query cleared elsewhere', (tester) async {
      await pumpBar(tester);
      await search(tester, 'users');
      expect(fieldText(tester), 'users');

      controller.resetFilter();
      await tester.pump();
      expect(fieldText(tester), isEmpty);
      expect(find.byType(PeekEntryTile), findsNWidgets(6));
    });

    testWidgets('survives large text', (tester) async {
      await pumpBar(tester, textScale: 2);
      await search(tester, 'users');
      expect(tester.takeException(), isNull);
    });
  });
}
