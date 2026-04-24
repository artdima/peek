import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peek/peek.dart';

import '../../support/entries.dart';
import '../../support/fake_store.dart';
import '../../support/pump.dart';

/// Wraps [child] in the scope the widgets read their strings from.
Future<void> pumpWidgetInScope(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
  Size size = const Size(400, 200),
  double textScale = 1,
}) async {
  final (:peek, :store, :clock) = fakePeek(entries: fixtures);
  final controller = PeekController(peek);
  addTearDown(controller.dispose);
  addTearDown(peek.dispose);
  await pumpPeek(
    tester,
    PeekScope(controller: controller, child: Center(child: child)),
    brightness: brightness,
    size: size,
    textScale: textScale,
  );
}

void main() {
  group('PeekMethodBadge', () {
    testWidgets('shows the method uppercase in its own colour', (tester) async {
      await pumpWidgetInScope(tester, const PeekMethodBadge('post'));
      expect(find.text('POST'), findsOneWidget);

      final context = tester.element(find.text('POST'));
      final theme = PeekTheme.of(context);
      final style = tester.widget<Text>(find.text('POST')).style;
      expect(style?.color, theme.colorForMethod('POST'));
    });

    testWidgets('falls back for an unknown method', (tester) async {
      await pumpWidgetInScope(tester, const PeekMethodBadge('PROPFIND'));
      final context = tester.element(find.text('PROPFIND'));
      final style = tester.widget<Text>(find.text('PROPFIND')).style;
      expect(style?.color, PeekTheme.of(context).pending);
    });
  });

  group('PeekStatusLabel', () {
    testWidgets('shows a code in the colour of its class', (tester) async {
      await pumpWidgetInScope(tester, PeekStatusLabel(e1));
      expect(find.text('200'), findsOneWidget);

      final context = tester.element(find.text('200'));
      final theme = PeekTheme.of(context);
      expect(tester.widget<Text>(find.text('200')).style?.color, theme.success);
      expect(
        tester.widget<PeekStatusDot>(find.byType(PeekStatusDot)).color,
        theme.success,
      );
    });

    testWidgets('says a call is still running', (tester) async {
      await pumpWidgetInScope(tester, PeekStatusLabel(e4));
      expect(find.text('Pending'), findsOneWidget);
      final context = tester.element(find.text('Pending'));
      expect(
        tester.widget<Text>(find.text('Pending')).style?.color,
        PeekTheme.of(context).pending,
      );
    });

    testWidgets('names a failure that has no status', (tester) async {
      await pumpWidgetInScope(tester, PeekStatusLabel(e5));
      expect(find.text('Timed out'), findsOneWidget);
    });

    testWidgets('prefers the status a failed call answered with', (
      tester,
    ) async {
      final failedWith503 = e5.copyWith(
        response: PeekResponse(statusCode: 503),
      );
      await pumpWidgetInScope(tester, PeekStatusLabel(failedWith503));
      expect(find.text('503'), findsOneWidget);

      final context = tester.element(find.text('503'));
      final style = tester.widget<Text>(find.text('503')).style;
      expect(style?.color, PeekTheme.of(context).serverError);
    });
  });

  group('PeekKeyValueRow', () {
    testWidgets('shows a name, a selectable value and a trailing slot', (
      tester,
    ) async {
      await pumpWidgetInScope(
        tester,
        const PeekKeyValueRow(
          name: 'Content-Type',
          value: 'application/json',
          trailing: Icon(Icons.lock_outline),
        ),
      );
      expect(find.text('Content-Type'), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('emphasises a value when asked', (tester) async {
      await pumpWidgetInScope(
        tester,
        const PeekKeyValueRow(
          name: 'Authorization',
          value: '*****',
          emphasised: true,
        ),
      );
      final value = tester.widget<SelectableText>(find.byType(SelectableText));
      expect(value.style?.fontWeight, FontWeight.w700);
    });
  });

  group('PeekSectionHeader', () {
    testWidgets('shouts the title and counts its rows', (tester) async {
      await pumpWidgetInScope(
        tester,
        const Column(
          children: [
            PeekSectionHeader('Headers', count: 4),
            PeekSectionHeader('Body'),
          ],
        ),
      );
      expect(find.text('HEADERS  4'), findsOneWidget);
      expect(find.text('BODY'), findsOneWidget);
    });
  });

  group('PeekCopyButton', () {
    testWidgets('copies and confirms', (tester) async {
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

      await pumpWidgetInScope(
        tester,
        const PeekCopyButton(text: 'https://example.com'),
      );
      await tester.tap(find.byType(PeekCopyButton));
      await tester.pump();
      await tester.pump();

      expect(copied, ['https://example.com']);
      expect(find.text('Copied'), findsOneWidget);

      // The toast takes itself away; leaving its timer pending fails
      // the test on teardown.
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Copied'), findsNothing);
    });

    testWidgets('is disabled without text', (tester) async {
      await pumpWidgetInScope(tester, const PeekCopyButton(text: null));
      expect(
        tester.widget<PeekIconButton>(find.byType(PeekIconButton)).onPressed,
        isNull,
      );
    });
  });

  group('PeekHighlightedText', () {
    testWidgets('stays a plain Text with nothing to mark', (tester) async {
      await pumpWidgetInScope(tester, const PeekHighlightedText('/users'));
      expect(find.text('/users'), findsOneWidget);
      expect(tester.widget<Text>(find.byType(Text)).textSpan, isNull);
    });

    testWidgets('marks every match, ignoring case', (tester) async {
      await pumpWidgetInScope(
        tester,
        const PeekHighlightedText('/Users/user', highlight: ' user '),
      );

      final span = tester.widget<Text>(find.byType(Text)).textSpan! as TextSpan;
      final parts = span.children!.cast<TextSpan>();
      expect(parts.map((part) => part.text), ['/', 'User', 's/', 'user']);

      final context = tester.element(find.byType(PeekHighlightedText));
      final marked = PeekTheme.of(context).highlight;
      expect(
        parts.where((part) => part.style?.backgroundColor == marked).length,
        2,
      );
    });
  });

  group('PeekEmptyState', () {
    testWidgets('shows a title, a message and an action', (tester) async {
      await pumpWidgetInScope(
        tester,
        PeekEmptyState(
          title: 'No requests yet',
          message: 'Send a request and it will show up here.',
          action: TextButton(onPressed: () {}, child: const Text('Reset')),
        ),
        size: const Size(400, 400),
      );
      expect(find.text('No requests yet'), findsOneWidget);
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
      expect(find.byType(TextButton), findsOneWidget);
    });
  });

  group('goldens', () {
    for (final brightness in Brightness.values) {
      testWidgets('shared widgets in ${brightness.name}', (tester) async {
        await pumpWidgetInScope(
          tester,
          const _Gallery(),
          brightness: brightness,
          size: const Size(420, 420),
        );
        expect(tester.takeException(), isNull);
        await expectGolden(find.byType(_Gallery), 'widgets-${brightness.name}');
      });
    }

    testWidgets('shared widgets survive large text', (tester) async {
      await pumpWidgetInScope(
        tester,
        const _Gallery(),
        size: const Size(420, 700),
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
      color: theme.background,
      child: Padding(
        padding: EdgeInsets.all(theme.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final method in ['GET', 'POST', 'PUT', 'DELETE'])
                  PeekMethodBadge(method),
              ],
            ),
            SizedBox(height: theme.rowSpacing),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                PeekStatusLabel(e1),
                PeekStatusLabel(e2),
                PeekStatusLabel(e6),
                PeekStatusLabel(e5),
              ],
            ),
            const PeekSectionHeader('Headers', count: 2),
            const PeekKeyValueRow(
              name: 'Content-Type',
              value: 'application/json',
            ),
            const PeekKeyValueRow(
              name: 'Authorization',
              value: '*****',
              emphasised: true,
              trailing: PeekCopyButton(text: '*****'),
            ),
            SizedBox(height: theme.rowSpacing),
            const Row(
              children: [
                PeekDurationLabel(Duration(milliseconds: 250)),
                SizedBox(width: 12),
                PeekSizeLabel(2048),
                SizedBox(width: 12),
                PeekDurationLabel(null),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
