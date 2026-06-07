import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peek/peek.dart';

import '../support/entries.dart';
import '../support/fake_store.dart';

void main() {
  final button = find.byIcon(Icons.visibility);

  Future<Peek> pumpOverlay(
    WidgetTester tester, {
    Iterable<PeekEntry> entries = const [],
    bool enabled = true,
    Alignment alignment = Alignment.bottomRight,
  }) async {
    final built = fakePeek(entries: entries);
    addTearDown(built.peek.dispose);
    await tester.pumpWidget(
      MaterialApp(
        builder:
            (context, child) => PeekOverlay(
              peek: built.peek,
              enabled: enabled,
              alignment: alignment,
              child: child!,
            ),
        home: Scaffold(
          body: Center(
            child: TextButton(onPressed: () {}, child: const Text('app')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return built.peek;
  }

  testWidgets('floats over the app without swallowing its taps', (
    tester,
  ) async {
    await pumpOverlay(tester);

    expect(button, findsOneWidget);
    await tester.tap(find.text('app'));
    await tester.pump();
    expect(find.byType(PeekScreen), findsNothing);
  });

  testWidgets('is not there at all when it is turned off', (tester) async {
    await pumpOverlay(tester, enabled: false);

    expect(button, findsNothing);
    expect(find.byType(PeekOverlay), findsOneWidget);
  });

  testWidgets('counts failures, and pending calls when nothing failed', (
    tester,
  ) async {
    final peek = await pumpOverlay(tester, entries: [e1, e4]);
    expect(find.text('1'), findsOneWidget);

    peek.store.upsert(e2);
    await tester.pump();
    peek.store.upsert(e6);
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('shows no badge over a quiet store', (tester) async {
    await pumpOverlay(tester, entries: [e1, e3]);

    // Nothing but the app's own label: no badge over the button.
    expect(find.byType(Text), findsOneWidget);
    expect(find.text('app'), findsOneWidget);
  });

  testWidgets('can be dragged out of the way', (tester) async {
    await pumpOverlay(tester);

    final before = tester.getCenter(button);
    await tester.drag(button, const Offset(-120, -200));
    await tester.pump();
    final after = tester.getCenter(button);

    expect(after.dx, lessThan(before.dx));
    expect(after.dy, lessThan(before.dy));
  });

  testWidgets('stays on screen however far it is dragged', (tester) async {
    await pumpOverlay(tester, alignment: Alignment.topLeft);

    await tester.drag(button, const Offset(-500, -500));
    await tester.pump();

    final rect = tester.getRect(find.byType(PeekOverlay));
    expect(rect.contains(tester.getCenter(button)), isTrue);
  });

  testWidgets('opens Peek and steps aside while it is open', (tester) async {
    await pumpOverlay(tester, entries: [e1, e2]);

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byType(PeekScreen), findsOneWidget);
    expect(button, findsNothing);

    await tester.tap(find.byTooltip(const PeekStrings().close));
    await tester.pumpAndSettle();
    expect(find.byType(PeekScreen), findsNothing);
    expect(button, findsOneWidget);
  });
}
