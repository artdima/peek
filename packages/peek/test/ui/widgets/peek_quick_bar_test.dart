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
      PeekScope(controller: controller, child: const PeekQuickBar()),
      size: const Size(420, 300),
      textScale: textScale,
    );
  }

  Future<void> tapMode(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(ChoiceChip, label));
    await tester.pump();
  }

  bool isSelected(WidgetTester tester, String label) =>
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, label))
          .selected;

  group('PeekQuickBar', () {
    testWidgets('starts on all and switches between the modes', (tester) async {
      await pumpBar(tester);
      expect(isSelected(tester, 'All'), isTrue);

      await tapMode(tester, 'Errors');
      expect(idsOf(controller.entries), ['e6', 'e5', 'e2']);
      expect(isSelected(tester, 'Errors'), isTrue);
      expect(isSelected(tester, 'All'), isFalse);

      await tapMode(tester, 'Pending');
      expect(controller.filter.onlyErrors, isFalse);
      expect(idsOf(controller.entries), ['e4']);

      await tapMode(tester, 'Pinned');
      expect(controller.filter.states, isEmpty);
      expect(idsOf(controller.entries), ['e5']);

      await tapMode(tester, 'All');
      expect(controller.filter.isEmpty, isTrue);
      expect(controller.entries, hasLength(6));
    });

    testWidgets('leaves criteria it does not own alone', (tester) async {
      await pumpBar(tester);
      controller.filter = const PeekFilter(hosts: {'api.example.com'});
      await tester.pump();

      await tapMode(tester, 'Errors');
      expect(controller.filter.hosts, {'api.example.com'});
      expect(idsOf(controller.entries), ['e5', 'e2']);
    });

    testWidgets('claims no mode for a filter none of them names', (
      tester,
    ) async {
      await pumpBar(tester);
      controller.filter = const PeekFilter(onlyErrors: true, onlyPinned: true);
      await tester.pump();

      for (final label in ['All', 'Errors', 'Pending', 'Pinned']) {
        expect(isSelected(tester, label), isFalse, reason: label);
      }
    });

    testWidgets('reorders the list from the sort menu', (tester) async {
      await pumpBar(tester);
      expect(controller.sort, PeekSort.newestFirst);

      await tester.tap(find.byTooltip('Sort'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Slowest first').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(controller.sort, PeekSort.slowestFirst);
      expect(idsOf(controller.entries), ['e5', 'e6', 'e2', 'e1', 'e3', 'e4']);
    });

    testWidgets('survives large text', (tester) async {
      await pumpBar(tester, textScale: 2);
      expect(tester.takeException(), isNull);
    });
  });
}
