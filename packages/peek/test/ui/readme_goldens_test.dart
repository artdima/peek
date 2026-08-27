import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peek/peek.dart';

import '../support/entries.dart';
import '../support/fake_store.dart';
import '../support/pump.dart';

/// The frames the documentation shows.
///
/// They are goldens so the screenshots in the README cannot drift from
/// what Peek draws: change the look and this suite says so. The pending
/// call is left out — the only thing on these screens that moves.
void main() {
  final shown = [e1, e2, e3, e5, e6];

  late Peek peek;
  late PeekController controller;

  setUp(() {
    peek = fakePeek(entries: shown).peek;
    controller = PeekController(peek);
  });

  tearDown(() {
    controller.dispose();
    peek.dispose();
  });

  Future<void> pumpScreen(
    WidgetTester tester,
    Widget child, {
    required Brightness brightness,
    Size size = const Size(390, 780),
  }) async {
    await pumpPeek(tester, child, brightness: brightness, size: size);
    await tester.pumpAndSettle();
  }

  for (final brightness in Brightness.values) {
    final name = brightness.name;

    testWidgets('the list, in $name', (tester) async {
      await pumpScreen(
        tester,
        PeekScreen(peek: peek, controller: controller),
        brightness: brightness,
      );

      expect(find.byType(PeekEntryTile), findsNWidgets(shown.length));
      await expectGolden(find.byType(PeekScreen), 'readme-list-$name');
    });

    testWidgets('a call, in $name', (tester) async {
      await pumpScreen(
        tester,
        PeekScope(controller: controller, child: PeekEntryScreen(e2.id)),
        brightness: brightness,
      );

      expect(find.byType(PeekEntryView), findsOneWidget);
      await expectGolden(find.byType(PeekEntryScreen), 'readme-call-$name');
    });

    testWidgets('a searched list, in $name', (tester) async {
      await pumpScreen(
        tester,
        PeekScreen(peek: peek, controller: controller),
        brightness: brightness,
      );
      controller.searchFor('users');
      await tester.pump(PeekController.searchDebounce);
      await tester.pumpAndSettle();

      await expectGolden(find.byType(PeekScreen), 'readme-search-$name');
    });
  }

  testWidgets('a response body, as a tree', (tester) async {
    await pumpScreen(
      tester,
      PeekScope(controller: controller, child: PeekEntryScreen(e1.id)),
      brightness: Brightness.light,
    );
    await tester.tap(
      find.widgetWithText(PeekListRow, const PeekStrings().responseBody),
    );
    await tester.pumpAndSettle();

    await expectGolden(find.byType(PeekBodyView), 'readme-body');
  });

  testWidgets('the list and a call, side by side', (tester) async {
    controller.select(e2.id);
    await pumpScreen(
      tester,
      PeekScreen(peek: peek, controller: controller),
      brightness: Brightness.light,
      size: const Size(1000, 680),
    );

    expect(find.byType(PeekEntryView), findsOneWidget);
    await expectGolden(find.byType(PeekScreen), 'readme-wide');
  });
}
