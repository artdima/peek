import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peek/peek.dart';

import '../../support/entries.dart';
import '../../support/fake_store.dart';
import '../../support/pump.dart';

void main() {
  late PeekController controller;

  /// Settles the route and chip animations without waiting for a pending
  /// call's spinner, which never stops.
  /// Drives animations frame by frame, the way a running app does.
  /// `pumpAndSettle` is out: a pending call's spinner never stops, and a
  /// route that finished leaving needs the frame after its last one.
  Future<void> settle(WidgetTester tester) async {
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  Future<void> pumpScreen(
    WidgetTester tester, {
    Size size = const Size(420, 720),
    Brightness brightness = Brightness.light,
  }) async {
    final peek = fakePeek(entries: fixtures).peek;
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
        home: PeekScreen(peek: peek, controller: controller),
      ),
    );
    await tester.pump();
  }

  Future<void> resize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    await settle(tester);
  }

  Future<void> openUsers(WidgetTester tester) async {
    await tester.tap(find.text('/users'));
    await settle(tester);
  }

  group('narrow layout', () {
    testWidgets('opens a call as a screen of its own', (tester) async {
      await pumpScreen(tester);
      expect(find.byType(PeekEntryView), findsNothing);

      await openUsers(tester);
      expect(find.byType(PeekEntryScreen), findsOneWidget);
      expect(
        find.text('GET https://api.example.com/users', findRichText: true),
        findsOneWidget,
      );
      expect(find.widgetWithText(PeekListRow, '200'), findsOneWidget);
      expect(find.widgetWithText(PeekListRow, 'dio'), findsOneWidget);
      expect(find.text('Sent'), findsOneWidget);
      expect(find.text('Received'), findsOneWidget);
      expect(controller.selectedId, e1.id);

      await tester.pageBack();
      await settle(tester);
      expect(find.byType(PeekEntryScreen), findsNothing);
    });

    testWidgets('says so when the call is cleared while open', (tester) async {
      await pumpScreen(tester);
      await openUsers(tester);

      controller.clear();
      await settle(tester);
      expect(find.text('This request is gone'), findsOneWidget);
      expect(find.byType(PeekEntryView), findsNothing);
    });
  });

  group('wide layout', () {
    testWidgets('asks for a call before showing one', (tester) async {
      await pumpScreen(tester, size: const Size(960, 720));
      expect(find.text('Nothing selected'), findsOneWidget);
      expect(find.byType(PeekEntryTile), findsNWidgets(6));
    });

    testWidgets('shows the call beside the list, without a route', (
      tester,
    ) async {
      await pumpScreen(tester, size: const Size(960, 720));
      await openUsers(tester);

      expect(find.byType(PeekEntryScreen), findsNothing);
      expect(find.byType(PeekEntryView), findsOneWidget);
      expect(
        find.text('GET https://api.example.com/users', findRichText: true),
        findsOneWidget,
      );

      final tile = tester.widget<PeekEntryTile>(
        find.ancestor(
          of: find.text('/users'),
          matching: find.byType(PeekEntryTile),
        ),
      );
      expect(tile.selected, isTrue);
    });

    testWidgets('lifts the bar to the line the way out sits on', (
      tester,
    ) async {
      await pumpScreen(tester, size: const Size(960, 720));

      final line = tester.getCenter(find.byTooltip('Filters')).dy;
      for (final tooltip in ['Filters', 'Clear', 'Pause', 'More']) {
        final button = find.byTooltip(tooltip);
        expect(
          tester.getBottomRight(button).dx,
          lessThanOrEqualTo(PeekScreen.listPaneWidth),
          reason: '$tooltip belongs over the list, not over the call',
        );
        expect(
          tester.getCenter(button).dy,
          line,
          reason: '$tooltip belongs on the bar, not beside the name',
        );
      }
      expect(line, lessThan(tester.getTopLeft(find.text('Console')).dy));
    });

    testWidgets('fits the quick bar on one line', (tester) async {
      await pumpScreen(tester, size: const Size(960, 720));

      final line = tester.getCenter(find.text('All')).dy;
      for (final label in ['Errors', 'Pending', 'Pinned']) {
        expect(
          tester.getCenter(find.text(label)).dy,
          line,
          reason: '$label wrapped onto a line of its own',
        );
      }
      expect(tester.getCenter(find.byTooltip('Sort')).dy, line);
    });

    testWidgets('rules the panes apart over the whole window', (tester) async {
      await pumpScreen(tester, size: const Size(960, 720));

      final rule = find.byWidgetPredicate(
        (widget) => widget is PeekSeparator && widget.axis == Axis.vertical,
      );
      expect(tester.getRect(rule).top, 0);
      expect(tester.getRect(rule).bottom, 720);
    });

    testWidgets('gives the call a button of its own', (tester) async {
      await pumpScreen(tester, size: const Size(960, 720));
      expect(find.byTooltip('Request actions'), findsNothing);

      await openUsers(tester);
      final list = tester.getCenter(find.byTooltip('More'));
      final call = tester.getCenter(find.byTooltip('Request actions'));
      expect(list.dx, lessThan(PeekScreen.listPaneWidth));
      expect(call.dx, greaterThan(PeekScreen.listPaneWidth));
      expect(call.dy, list.dy);

      await tester.tap(find.byTooltip('Request actions'));
      await settle(tester);
      expect(find.text('Copy as cURL'), findsOneWidget);
    });

    testWidgets('keeps the selection across a change of layout', (
      tester,
    ) async {
      await pumpScreen(tester, size: const Size(960, 720));
      await openUsers(tester);

      await resize(tester, const Size(420, 720));
      expect(find.byType(PeekEntryView), findsNothing);
      expect(find.byType(PeekEntryScreen), findsNothing);
      expect(controller.selectedId, e1.id);

      await resize(tester, const Size(960, 720));
      expect(find.byType(PeekEntryView), findsOneWidget);
      expect(
        find.text('GET https://api.example.com/users', findRichText: true),
        findsOneWidget,
      );
    });
  });

  group('goldens', () {
    testWidgets('the wide layout with a call open', (tester) async {
      await pumpScreen(tester, size: const Size(960, 720));
      await openUsers(tester);
      expect(tester.takeException(), isNull);
      await expectGolden(find.byType(PeekScreen), 'screen-wide');
    });
  });
}
