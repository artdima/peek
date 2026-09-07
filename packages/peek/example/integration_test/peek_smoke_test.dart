import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:peek/peek.dart';
import 'package:peek_example/main.dart' as app;

/// Walks the example the way a reader would: fill the log, open Peek, read
/// a call, come back.
///
/// The offline calls are used rather than the network ones, so the test
/// says something about Peek rather than about the connection.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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

    await tester.tap(find.byType(PeekEntryTile).first);
    await tester.pumpAndSettle();

    expect(find.byType(PeekEntryView), findsOneWidget);
    expect(find.widgetWithText(PeekPill, 'Overview'), findsOneWidget);

    await tester.tap(find.widgetWithText(PeekPill, 'Response'));
    await tester.pumpAndSettle();
    expect(find.byType(PeekEntryView), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(PeekEntryTile), findsWidgets);
  });
}
