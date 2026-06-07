import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peek/peek.dart';

import '../support/entries.dart';
import '../support/fake_store.dart';

void main() {
  const strings = PeekStrings();

  ({Peek peek, FakePeekStore store, PeekFakeClock clock}) harness() {
    final built = fakePeek(entries: [e1, e2]);
    addTearDown(built.peek.dispose);
    return built;
  }

  Future<void> pumpApp(
    WidgetTester tester,
    Future<void> Function(BuildContext context) onOpen,
  ) => tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder:
            (context) => TextButton(
              onPressed: () => onOpen(context),
              child: const Text('open'),
            ),
      ),
    ),
  );

  testWidgets('showPeek opens the screen and the close button leaves it', (
    tester,
  ) async {
    final peek = harness().peek;
    await pumpApp(tester, (context) => showPeek(context, peek: peek));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(PeekScreen), findsOneWidget);
    expect(find.text('/users'), findsOneWidget);

    await tester.tap(find.byTooltip(strings.close));
    await tester.pumpAndSettle();
    expect(find.byType(PeekScreen), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('PeekNavigation.open shows the instance it was called on', (
    tester,
  ) async {
    final peek = harness().peek;
    await pumpApp(tester, peek.open);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final screen = tester.widget<PeekScreen>(find.byType(PeekScreen));
    expect(screen.peek, same(peek));
  });

  testWidgets('a pushed screen goes back rather than closing', (tester) async {
    final peek = harness().peek;
    await pumpApp(
      tester,
      (context) => showPeek(context, peek: peek, fullscreenDialog: false),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byTooltip(strings.back), findsOneWidget);
    expect(find.byTooltip(strings.close), findsNothing);
  });

  testWidgets('PeekRoute serves a named route', (tester) async {
    final peek = harness().peek;
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute:
            (settings) =>
                settings.name == PeekRoute.name
                    ? PeekRoute(peek: peek, settings: settings)
                    : MaterialPageRoute<void>(
                      settings: settings,
                      builder:
                          (context) => TextButton(
                            onPressed:
                                () => Navigator.of(
                                  context,
                                ).pushNamed(PeekRoute.name),
                            child: const Text('open'),
                          ),
                    ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(PeekScreen), findsOneWidget);
  });

  testWidgets('a screen that was not pushed has no way out', (tester) async {
    final peek = harness().peek;
    await tester.pumpWidget(MaterialApp(home: PeekScreen(peek: peek)));
    await tester.pump();

    expect(find.byTooltip(strings.close), findsNothing);
    expect(find.byTooltip(strings.back), findsNothing);
  });
}
