import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peek/peek.dart';

import '../../support/fake_store.dart';
import '../../support/pump.dart';

void main() {
  Future<BuildContext> pumpHost(WidgetTester tester) async {
    final peek = fakePeek().peek;
    final controller = PeekController(peek);
    addTearDown(controller.dispose);
    addTearDown(peek.dispose);

    late BuildContext host;
    await pumpPeek(
      tester,
      PeekScope(
        controller: controller,
        child: Builder(
          builder: (context) {
            host = context;
            return const SizedBox.expand();
          },
        ),
      ),
    );
    return host;
  }

  // A route or an overlay builds above the app's own content, where the
  // inherited style is the one Flutter draws mistakes in: 48px red with a
  // yellow double underline. Anything Peek's own styles leave unsaid —
  // the decoration above all — would come from there.
  void expectOwnStyle(WidgetTester tester) {
    final texts = tester.widgetList<RichText>(
      find.descendant(
        of: find.byType(PeekSurface),
        matching: find.byType(RichText),
      ),
    );
    expect(texts, isNotEmpty);
    for (final text in texts) {
      final style = text.text.style;
      expect(style?.decoration ?? TextDecoration.none, TextDecoration.none);
      expect(style?.fontFamily, isNot('monospace'));
    }
  }

  testWidgets('the actions sheet reads in Peek styles', (tester) async {
    final context = await pumpHost(tester);

    final picked = showPeekActions<String>(
      context,
      title: 'Entry',
      actions: const [
        PeekAction(value: 'har', label: 'Export HAR', icon: PeekIcons.braces),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Export HAR'), findsOneWidget);
    expect(find.text('Entry'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.byType(PeekIcon), findsOneWidget);
    expectOwnStyle(tester);

    await tester.tap(find.text('Export HAR'));
    await tester.pumpAndSettle();
    expect(await picked, 'har');
  });

  testWidgets('the actions sheet groups neighbours by section', (
    tester,
  ) async {
    final context = await pumpHost(tester);

    final picked = showPeekActions<String>(
      context,
      header: const Text('About this'),
      actions: const [
        PeekAction(value: 'a', label: 'First', section: 'Copy'),
        PeekAction(value: 'b', label: 'Second', section: 'Copy'),
        PeekAction(value: 'c', label: 'Third', section: 'Share'),
        PeekAction(value: 'd', label: 'Alone'),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('About this'), findsOneWidget);
    expect(find.text('COPY'), findsOneWidget);
    expect(find.text('SHARE'), findsOneWidget);
    // First and Second share a card, so one hairline sits between them;
    // Third and Alone each stand alone.
    expect(find.byType(PeekSeparator), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await picked, isNull);
  });

  testWidgets('the alert reads in Peek styles', (tester) async {
    final context = await pumpHost(tester);

    final confirmed = showPeekAlert(
      context,
      title: 'Clear',
      message: 'This cannot be taken back.',
      confirmLabel: 'Clear all',
    );
    await tester.pumpAndSettle();

    expectOwnStyle(tester);

    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    expect(await confirmed, isTrue);
  });

  testWidgets('the toast reads in Peek styles', (tester) async {
    final context = await pumpHost(tester);

    showPeekToast(context, 'Copied');
    await tester.pump();

    expect(find.text('Copied'), findsOneWidget);
    expectOwnStyle(tester);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Copied'), findsNothing);
  });
}
