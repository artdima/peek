import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:flutter_test/flutter_test.dart';
import 'package:peek/peek.dart';

import '../../support/entries.dart';
import '../../support/fake_store.dart';
import '../../support/pump.dart';

void main() {
  Future<void> pumpInScope(
    WidgetTester tester,
    Widget child, {
    Brightness brightness = Brightness.light,
    Size size = const Size(400, 300),
    double textScale = 1,
  }) async {
    final peek = fakePeek(entries: fixtures).peek;
    final controller = PeekController(peek);
    addTearDown(controller.dispose);
    addTearDown(peek.dispose);
    await pumpPeek(
      tester,
      PeekScope(controller: controller, child: child),
      brightness: brightness,
      size: size,
      textScale: textScale,
    );
  }

  group('PeekTappable', () {
    testWidgets('answers taps and washes while held', (tester) async {
      var taps = 0;
      await pumpInScope(
        tester,
        PeekTappable(
          onTap: () => taps++,
          child: const SizedBox(width: 100, height: 44),
        ),
      );

      final wash = find.descendant(
        of: find.byType(PeekTappable),
        matching: find.byType(ColoredBox),
      );
      expect(wash, findsNothing);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PeekTappable)),
      );
      await tester.pump();
      expect(wash, findsOneWidget);

      await gesture.up();
      await tester.pump();
      expect(taps, 1);
      expect(wash, findsNothing);
    });

    testWidgets('is inert without a callback', (tester) async {
      await pumpInScope(
        tester,
        const PeekTappable(child: SizedBox(width: 100, height: 44)),
      );
      expect(
        find.descendant(
          of: find.byType(PeekTappable),
          matching: find.byType(GestureDetector),
        ),
        findsNothing,
      );
    });
  });

  group('PeekListRow', () {
    testWidgets('shows what it holds and where it leads', (tester) async {
      var taps = 0;
      await pumpInScope(
        tester,
        PeekListRow(
          title: 'Response Headers',
          value: '3',
          chevron: true,
          onTap: () => taps++,
        ),
      );

      expect(find.text('Response Headers'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(
        tester.getSize(find.byType(PeekListRow)).height,
        greaterThanOrEqualTo(44),
      );

      await tester.tap(find.byType(PeekListRow));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('a disabled row is greyed and inert', (tester) async {
      var taps = 0;
      await pumpInScope(
        tester,
        PeekListRow(
          title: 'Request Body',
          value: 'Empty',
          enabled: false,
          onTap: () => taps++,
        ),
      );

      await tester.tap(find.byType(PeekListRow), warnIfMissed: false);
      await tester.pump();
      expect(taps, 0);

      final context = tester.element(find.text('Request Body'));
      final theme = PeekTheme.of(context);
      final style = tester.widget<Text>(find.text('Request Body')).style;
      expect(style?.color, theme.secondaryLabel);
    });
  });

  group('PeekListSection', () {
    testWidgets('groups rows under a heading, hairlines between', (
      tester,
    ) async {
      await pumpInScope(
        tester,
        const PeekListSection(
          title: 'Request',
          footer: 'Captured before redaction.',
          children: [
            PeekListRow(title: 'Headers', value: '4'),
            PeekListRow(title: 'Body', value: 'Empty'),
            PeekListRow(title: 'Cookies', value: '0'),
          ],
        ),
      );

      expect(find.text('REQUEST'), findsOneWidget);
      expect(find.text('Captured before redaction.'), findsOneWidget);
      expect(find.byType(PeekSeparator), findsNWidgets(2));
    });

    testWidgets('a narrow row still starts at the left edge', (tester) async {
      await pumpInScope(
        tester,
        const PeekListSection(children: [Text('GET https://example.com')]),
      );

      final card = tester.getRect(find.byType(ClipRRect).first);
      final text = tester.getRect(find.text('GET https://example.com'));
      expect(text.left, card.left);
    });

    testWidgets('shows nothing without rows', (tester) async {
      await pumpInScope(
        tester,
        const PeekListSection(title: 'Empty', children: []),
      );
      expect(find.text('EMPTY'), findsNothing);
    });
  });

  group('PeekSegmented', () {
    testWidgets('marks the chosen one and reports taps', (tester) async {
      var chosen = 'all';
      await pumpInScope(
        tester,
        StatefulBuilder(
          builder:
              (context, setState) => PeekSegmented<String>(
                selected: chosen,
                onChanged: (value) => setState(() => chosen = value),
                segments: const [
                  PeekSegment(value: 'all', label: 'All', count: 6),
                  PeekSegment(value: 'errors', label: 'Errors', count: 3),
                ],
              ),
        ),
      );

      expect(find.text('All'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);

      const onAccent = Color(0xFFFFFFFF);
      final theme = PeekTheme.of(tester.element(find.text('All')));
      expect(tester.widget<Text>(find.text('All')).style?.color, onAccent);
      expect(
        tester.widget<Text>(find.text('Errors')).style?.color,
        theme.label,
      );

      await tester.tap(find.text('Errors'));
      await tester.pump();
      expect(chosen, 'errors');
      expect(tester.widget<Text>(find.text('Errors')).style?.color, onAccent);
    });
  });

  group('PeekSearchField', () {
    testWidgets('types, clears and cancels', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      var typed = '';
      var cancelled = 0;

      await pumpInScope(
        tester,
        PeekSearchField(
          controller: controller,
          placeholder: 'Search',
          cancelLabel: 'Cancel',
          onCancel: () => cancelled++,
          onChanged: (value) => typed = value,
          onClear: controller.clear,
        ),
      );

      expect(find.text('Search'), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsNothing);

      await tester.enterText(find.byType(CupertinoSearchTextField), 'users');
      await tester.pump();
      expect(typed, 'users');
      expect(find.byIcon(Icons.cancel), findsOneWidget);

      await tester.tap(find.byIcon(Icons.cancel));
      await tester.pump();
      expect(controller.text, isEmpty);
      expect(find.byIcon(Icons.cancel), findsNothing);

      await tester.tap(find.text('Cancel'));
      expect(cancelled, 1);
    });
  });

  group('PeekIconButton', () {
    testWidgets('carries a badge and greys out when disabled', (tester) async {
      await pumpInScope(
        tester,
        const Row(
          children: [
            PeekIconButton(
              icon: Icons.filter_list,
              tooltip: 'Filters',
              badgeCount: 2,
            ),
            PeekIconButton(icon: Icons.pause, tooltip: 'Pause'),
          ],
        ),
      );

      expect(find.byTooltip('Filters'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);

      final context = tester.element(find.byIcon(Icons.pause));
      final theme = PeekTheme.of(context);
      expect(
        tester.widget<Icon>(find.byIcon(Icons.pause)).color,
        theme.tertiaryLabel,
      );
      expect(
        tester.getSize(find.byIcon(Icons.pause).first).width,
        lessThanOrEqualTo(44),
      );
    });

    testWidgets('wears a disc while the mode it toggles is on', (tester) async {
      bool isDisc(Widget widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).shape == BoxShape.circle;

      await pumpInScope(
        tester,
        const PeekIconButton(icon: Icons.pause, tooltip: 'Pause'),
      );
      expect(find.byWidgetPredicate(isDisc), findsNothing);

      await pumpInScope(
        tester,
        const PeekIconButton(
          icon: Icons.pause,
          tooltip: 'Resume',
          selected: true,
        ),
      );
      expect(find.byWidgetPredicate(isDisc), findsOneWidget);
      expect(
        tester.getSize(find.byWidgetPredicate(isDisc)),
        const Size(36, 36),
      );
    });
  });

  group('PeekScaffold', () {
    testWidgets('wears a large name over the screen', (tester) async {
      await pumpInScope(
        tester,
        const PeekScaffold(
          title: 'Requests',
          trailingTitle: Text('6'),
          actions: [
            PeekIconButton(icon: Icons.filter_list, tooltip: 'Filters'),
          ],
          child: Center(child: Text('body')),
        ),
        size: const Size(400, 400),
      );

      expect(find.text('Requests'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(find.byTooltip('Filters'), findsOneWidget);
      expect(find.text('body'), findsOneWidget);

      final title = tester.widget<Text>(find.text('Requests'));
      final theme = PeekTheme.of(tester.element(find.text('Requests')));
      expect(title.style, theme.largeTitle);
    });

    testWidgets('wears an inline name between its buttons', (tester) async {
      await pumpInScope(
        tester,
        const PeekScaffold(
          title: 'api.example.com',
          titleStyle: PeekTitleStyle.inline,
          leading: PeekIconButton(
            icon: Icons.arrow_back_ios_new,
            tooltip: 'Back',
          ),
          child: SizedBox.shrink(),
        ),
        size: const Size(400, 200),
      );

      expect(find.byTooltip('Back'), findsOneWidget);
      final theme = PeekTheme.of(tester.element(find.text('api.example.com')));
      expect(
        tester.widget<Text>(find.text('api.example.com')).style,
        theme.headline,
      );
    });
  });

  group('goldens', () {
    for (final brightness in Brightness.values) {
      testWidgets('the primitives in ${brightness.name}', (tester) async {
        await pumpInScope(
          tester,
          const _Gallery(),
          brightness: brightness,
          size: const Size(420, 560),
        );
        expect(tester.takeException(), isNull);
        await expectGolden(
          find.byType(_Gallery),
          'primitives-${brightness.name}',
        );
      });
    }

    testWidgets('the primitives survive large text', (tester) async {
      await pumpInScope(
        tester,
        const _Gallery(),
        size: const Size(420, 900),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });
  });
}

class _Gallery extends StatelessWidget {
  const _Gallery();

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    return ColoredBox(
      color: theme.groupedBackground,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: theme.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: theme.gutter),
              child: PeekSegmented<int>(
                selected: 0,
                onChanged: (_) {},
                segments: const [
                  PeekSegment(value: 0, label: 'Network', count: 8),
                  PeekSegment(value: 1, label: 'Logs', count: 5),
                  PeekSegment(value: 2, label: 'All', count: 13),
                ],
              ),
            ),
            PeekListSection(
              title: 'Request',
              children: [
                PeekListRow(
                  title: 'Headers',
                  value: '4',
                  chevron: true,
                  leading: PeekStatusDot(theme.success),
                  onTap: () {},
                ),
                const PeekListRow(
                  title: 'Body',
                  value: 'Empty',
                  enabled: false,
                ),
                const PeekListRow(
                  title: 'api.example.com',
                  subtitle: 'GET /users',
                  value: '200',
                  chevron: true,
                ),
              ],
            ),
            const PeekListSection(
              title: 'Response',
              footer: 'Redacted by policy.',
              children: [PeekListRow(title: 'Body', value: '53 bytes')],
            ),
          ],
        ),
      ),
    );
  }
}
