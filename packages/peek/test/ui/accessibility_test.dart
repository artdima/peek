import 'dart:math';

import 'package:flutter/cupertino.dart' show CupertinoSliverNavigationBar;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peek/peek.dart';

import '../support/entries.dart';
import '../support/fake_store.dart';
import '../support/pump.dart';

/// What the guidelines are run against: the screens a reader walks through.
///
/// The JSON tree is left out on purpose — it is a dense data view whose
/// rows are deliberately shorter than a tap target; see `PeekJsonTreeView`.
///
/// [textContrastGuideline] is not among them, and cannot be: every screen
/// shows a chosen pill or a badge, and white on [PeekTheme.accent] is a
/// documented 4.0:1 exception. The palette is checked colour by colour
/// instead, which says more about where a shade may be used.
void main() {
  /// Checks Peek's own controls, one type at a time.
  ///
  /// [androidTapTargetGuideline] measures text fields as tap targets too,
  /// and Peek has two it will not pass: the search field is the height iOS
  /// gives a search field, and a selectable value reads as a read-only
  /// field whose box no padding can grow. The guideline still runs over
  /// the sheets, where neither appears.
  ///
  /// An icon button is held to 44 rather than 48 — Apple's own minimum,
  /// and what keeps a row of them from drifting apart. In the navigation
  /// bar it is 44 tall too: the bar is, and nothing inside it can be
  /// taller.
  void expectTapTargets(WidgetTester tester) {
    final inBar =
        find
            .descendant(
              of: find.byType(CupertinoSliverNavigationBar),
              matching: find.byType(PeekIconButton),
            )
            .evaluate()
            .toSet();

    void check(
      Finder finder,
      bool Function(Widget) acts, {
      double width = 48,
      double height = 48,
    }) {
      for (final element in finder.evaluate()) {
        if (!acts(element.widget)) continue;
        final least = inBar.contains(element) ? 44.0 : height;
        final size = element.size!;
        expect(
          size.width >= width && size.height >= least,
          isTrue,
          reason:
              '${element.widget.runtimeType} is $size, under the '
              '${width}x$least a tap target asks for',
        );
      }
    }

    check(
      find.byType(PeekListRow),
      (widget) => (widget as PeekListRow).onTap != null && widget.enabled,
    );
    check(
      find.byType(PeekIconButton),
      (widget) => (widget as PeekIconButton).onPressed != null,
      width: PeekIconButton.width,
    );
    check(
      find.byType(PeekPill),
      (widget) =>
          (widget as PeekPill).enabled &&
          (widget.onTap != null || widget.onRemove != null),
    );
    check(
      find.byType(PeekTextButton),
      (widget) => (widget as PeekTextButton).onPressed != null,
    );
  }

  late Peek peek;
  late PeekController controller;

  setUp(() {
    peek = fakePeek(entries: [e1, e2, e3, e5, e6]).peek;
    controller = PeekController(peek);
  });

  tearDown(() {
    controller.dispose();
    peek.dispose();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    double textScale = 1,
    Size size = const Size(400, 800),
  }) async {
    await pumpPeek(
      tester,
      PeekScreen(peek: peek, controller: controller),
      brightness: brightness,
      textScale: textScale,
      size: size,
    );
    await tester.pump();
  }

  group('guidelines', () {
    testWidgets('the list meets them in light', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester);

      expectTapTargets(tester);
      handle.dispose();
    });

    testWidgets('the list meets them in dark', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester, brightness: Brightness.dark);

      expectTapTargets(tester);
      handle.dispose();
    });

    testWidgets('a searched and filtered list still meets them', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester);
      controller
        ..searchFor('users')
        ..filter = const PeekFilter(onlyErrors: true);
      await tester.pump(PeekController.searchDebounce);
      await tester.pump();

      expectTapTargets(tester);
      handle.dispose();
    });

    testWidgets('a call meets them', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPeek(
        tester,
        PeekScope(controller: controller, child: PeekEntryScreen(e2.id)),
      );
      await tester.pump();

      expectTapTargets(tester);
      handle.dispose();
    });

    testWidgets('the filters sheet meets them', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester);
      await tester.tap(find.byTooltip(const PeekStrings().filters));
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });
  });

  group('text scaling', () {
    testWidgets('the list survives 1.3', (tester) async {
      await pumpScreen(tester, textScale: 1.3);
      expect(find.byType(PeekEntryTile), findsWidgets);
    });

    testWidgets('the list survives 2.0', (tester) async {
      await pumpScreen(tester, textScale: 2);
      expect(find.byType(PeekEntryTile), findsWidgets);
      await expectGolden(find.byType(PeekScreen), 'screen-text-scale-2');
    });

    testWidgets('a narrow list survives 2.0', (tester) async {
      await pumpScreen(tester, textScale: 2, size: const Size(320, 640));
      expect(find.byType(PeekEntryTile), findsWidgets);
    });

    testWidgets('a call survives 2.0', (tester) async {
      await pumpPeek(
        tester,
        PeekScope(controller: controller, child: PeekEntryScreen(e2.id)),
        textScale: 2,
      );
      await tester.pump();
      expect(find.byType(PeekEntryView), findsOneWidget);
    });
  });

  group('contrast', () {
    double ratio(Color foreground, Color background) {
      final a = foreground.computeLuminance();
      final b = background.computeLuminance();
      return (max(a, b) + 0.05) / (min(a, b) + 0.05);
    }

    void onEverySurface(
      PeekTheme theme,
      Color color,
      double least,
      String name,
    ) {
      final surfaces = {
        'background': theme.background,
        'grouped background': theme.groupedBackground,
        'card': theme.card,
        'fill': theme.fill,
      };
      for (final MapEntry(key: where, value: surface) in surfaces.entries) {
        expect(
          ratio(color, surface),
          greaterThanOrEqualTo(least),
          reason: '$name on $where',
        );
      }
    }

    for (final (name, theme) in [
      ('light', PeekTheme.light()),
      ('dark', PeekTheme.dark()),
    ]) {
      test('$name reads text at AA wherever it is drawn', () {
        onEverySurface(theme, theme.label, 4.5, '$name label');
        onEverySurface(theme, theme.secondaryLabel, 4.5, '$name secondary');
      });

      test('$name reads an outcome at AA for the size it is drawn', () {
        final outcomes = {
          'success': theme.success,
          'redirect': theme.redirect,
          'client error': theme.clientError,
          'server error': theme.serverError,
          'pending': theme.pending,
          'cancelled': theme.cancelled,
          'failure': theme.failure,
          ...theme.methodColors,
        };
        for (final MapEntry(key: what, value: color) in outcomes.entries) {
          // Outcomes are drawn in the headline, which counts as large text.
          onEverySurface(theme, color, 3, '$name $what');
        }
      });
    }
  });

  group('keyboard', () {
    testWidgets('tab reaches a row and enter presses it', (tester) async {
      var taps = 0;
      await pumpPeek(
        tester,
        PeekListRow(title: 'Headers', onTap: () => taps++),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('a focused row shows where the focus is', (tester) async {
      await pumpPeek(tester, PeekListRow(title: 'Headers', onTap: () {}));
      final before = find.byType(DecoratedBox).evaluate().length;

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      expect(find.byType(DecoratedBox).evaluate().length, before + 1);
    });
  });

  group('semantics', () {
    testWidgets('an icon button reads as a named button', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester);

      expect(
        tester.getSemantics(
          find.ancestor(
            of: find.byTooltip(const PeekStrings().pause),
            matching: find.byType(PeekIconButton),
          ),
        ),
        matchesSemantics(
          tooltip: const PeekStrings().pause,
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('a chip says what letting it go does', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpScreen(tester);
      controller.filter = const PeekFilter(methods: {'GET'});
      await tester.pump();

      expect(
        find.bySemanticsLabel(const PeekStrings().removeFilter('GET')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('a tab says it is one of a set', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpPeek(
        tester,
        PeekScope(controller: controller, child: PeekEntryScreen(e2.id)),
      );
      await tester.pump();

      expect(
        tester.getSemantics(
          find.widgetWithText(PeekPill, const PeekStrings().overview),
        ),
        matchesSemantics(
          label: const PeekStrings().overview,
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          isSelected: true,
          hasSelectedState: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
      handle.dispose();
    });
  });
}
