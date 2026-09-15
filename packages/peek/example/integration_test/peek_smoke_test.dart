import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:peek/peek.dart';
import 'package:peek_example/main.dart' as app;

/// Walks the example the way a reader would: fill the log, open Peek, read
/// a call, come back — and switches routes, since each adapter reaches the
/// same screens by a different way.
///
/// The offline calls are used rather than the network ones, so the test
/// says something about Peek rather than about the connection. A real call
/// is made once, for the Chopper route, and only to see that it turns into
/// an entry: whether it comes back or not, it is reported either way.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const strings = PeekStrings();

  // Peek opens over the example's own list, so a scroll has to say which of
  // the two it means.
  Finder listOf(Type screen) =>
      find
          .descendant(
            of: find.byType(screen),
            matching: find.byType(Scrollable),
          )
          .first;

  testWidgets('fills the log, opens Peek and reads a call', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    final offline = find.text('Add calls without a network');
    await tester.scrollUntilVisible(offline, 240);
    await tester.pumpAndSettle();
    await tester.tap(offline);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open Peek'));
    await tester.pumpAndSettle();

    expect(find.byType(PeekScreen), findsOneWidget);
    expect(find.byType(PeekEntryTile), findsWidgets);

    // A call that came back with a body, rather than whichever is newest:
    // the top of the list is a call still in flight.
    final call = find.text('/v1/users');
    await tester.scrollUntilVisible(call, 240, scrollable: listOf(PeekScreen));
    await tester.pumpAndSettle();
    await tester.tap(call);
    await tester.pumpAndSettle();

    expect(find.byType(PeekEntryView), findsOneWidget);

    // A part of a call opens as a screen of its own, not as a tab.
    final body = find.widgetWithText(PeekListRow, strings.responseBody);
    await tester.scrollUntilVisible(
      body,
      240,
      scrollable: listOf(PeekEntryView),
    );
    await tester.pumpAndSettle();
    await tester.tap(body);
    await tester.pumpAndSettle();
    expect(find.byType(PeekBodyView), findsOneWidget);

    await tester.tap(find.byTooltip(strings.back));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(strings.back));
    await tester.pumpAndSettle();
    expect(find.byType(PeekEntryTile), findsWidgets);
  });

  testWidgets('the Chopper route brings its own scenarios', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    expect(find.text('Timeout'), findsOneWidget);
    expect(find.text('Called off'), findsNothing);

    await tester.tap(find.text('peek_chopper'));
    await tester.pumpAndSettle();

    expect(find.text('Timeout'), findsNothing);
    expect(find.text('Called off'), findsOneWidget);
  });

  testWidgets('a call made through Chopper reaches the list', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    await tester.tap(find.text('peek_chopper'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('GET JSON'));
    // The row spins while the call is in flight, so the frames are pumped by
    // hand: `pumpAndSettle` would wait for an animation that is the point.
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    await tester.tap(find.text('Open Peek'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(PeekScreen), findsOneWidget);
    expect(find.byType(PeekEntryTile), findsWidgets);
  });
}
