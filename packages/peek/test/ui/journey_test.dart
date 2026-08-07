import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peek/peek.dart';

/// The walk a reader takes: a call is reported, shows up, opens, is read
/// tab by tab and copied out. Nothing here reaches past the public API —
/// events go in through [Peek.report], as an adapter would send them.
void main() {
  const strings = PeekStrings();
  const id = PeekId('journey');
  final startedAt = DateTime.utc(2026, 9, 12, 10);

  late Peek peek;
  late List<String> copied;

  setUp(() {
    peek = Peek();
    copied = [];
  });

  tearDown(() => peek.dispose());

  void watchClipboard(WidgetTester tester) {
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
  }

  Future<void> pumpApp(
    WidgetTester tester, {
    Size size = const Size(400, 800),
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: PeekScreen(peek: peek),
        ),
      ),
    );
    await tester.pump();
  }

  /// A store change reaches the list through a stream, so the frame that
  /// shows it is the one after the frame that heard about it.
  Future<void> deliver(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
  }

  void start(String method, String url) => peek.report(
    PeekRequestStarted(
      id: id,
      timestamp: startedAt,
      source: 'dio',
      request: PeekRequest(
        method: method,
        uri: Uri.parse(url),
        headers: PeekHeaders.fromMap({
          'Content-Type': 'application/json',
          'Authorization': 'Bearer secret',
        }),
        body: PeekBody.text('{"sku":"A-1"}', contentType: PeekMediaType.json),
      ),
    ),
  );

  void finish(int status) => peek.report(
    PeekResponseReceived(
      id: id,
      timestamp: startedAt.add(const Duration(milliseconds: 240)),
      response: PeekResponse(
        statusCode: status,
        headers: PeekHeaders.fromMap({'Content-Type': 'application/json'}),
        body: PeekBody.text('{"id":7}', contentType: PeekMediaType.json),
      ),
    ),
  );

  testWidgets('a call arrives, is read and is copied out', (tester) async {
    watchClipboard(tester);
    await pumpApp(tester);
    expect(find.text(strings.noRequests), findsOneWidget);

    start('POST', 'https://api.example.com/orders?page=2');
    await deliver(tester);

    expect(find.byType(PeekEntryTile), findsOneWidget);
    expect(find.text('/orders'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PeekStatusLabel),
        matching: find.textContaining(strings.pending),
      ),
      findsOneWidget,
    );

    finish(201);
    await deliver(tester);
    expect(
      find.descendant(
        of: find.byType(PeekStatusLabel),
        matching: find.textContaining('201'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byType(PeekEntryTile));
    await tester.pumpAndSettle();
    expect(find.byType(PeekEntryView), findsOneWidget);
    expect(find.text('api.example.com'), findsWidgets);

    await tester.tap(find.widgetWithText(PeekPill, strings.request));
    await tester.pumpAndSettle();
    expect(find.text('Authorization'), findsOneWidget);
    // The call as it happened: masking is the app's to ask for.
    expect(find.text('Bearer secret'), findsOneWidget);

    await tester.tap(find.widgetWithText(PeekPill, strings.response));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(PeekListRow, strings.contentType),
      findsOneWidget,
    );
    expect(find.text('Content-Type'), findsWidgets);

    await tester.tap(find.widgetWithText(PeekListRow, strings.responseBody));
    await tester.pumpAndSettle();
    // The tree is parsed off the main isolate, so the screen is what can
    // be asserted here; the tree itself has tests of its own.
    expect(find.byType(PeekBodyView), findsOneWidget);
    expect(find.text(strings.responseBody), findsOneWidget);
    await tester.tap(find.byTooltip(strings.back));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(strings.more));
    await tester.pumpAndSettle();
    await tester.tap(find.text(strings.copyUrl));
    await tester.pumpAndSettle();
    expect(copied.single, 'https://api.example.com/orders?page=2');
    // The 'Copied' toast keeps a timer; let it run out before leaving.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(strings.back));
    await tester.pumpAndSettle();
    expect(find.byType(PeekEntryTile), findsOneWidget);
  });

  testWidgets('a call that fails opens on what went wrong', (tester) async {
    await pumpApp(tester);

    start('GET', 'https://api.example.com/health');
    await deliver(tester);

    peek.report(
      PeekRequestFailed(
        id: id,
        timestamp: startedAt.add(const Duration(seconds: 5)),
        failure: const PeekFailure(
          kind: PeekFailureKind.timeout,
          message: 'Connection timed out',
        ),
      ),
    );
    await deliver(tester);

    await tester.tap(find.byType(PeekEntryTile));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(PeekPill, strings.error));
    await tester.pumpAndSettle();
    expect(find.text('Connection timed out'), findsWidgets);
  });

  testWidgets('a call cleared while open says so', (tester) async {
    await pumpApp(tester);

    start('GET', 'https://api.example.com/health');
    finish(200);
    await deliver(tester);

    await tester.tap(find.byType(PeekEntryTile));
    await tester.pumpAndSettle();
    expect(find.byType(PeekEntryView), findsOneWidget);

    peek.clear();
    await tester.pumpAndSettle();
    expect(find.text(strings.removedEntry), findsOneWidget);
  });

  testWidgets('a wide layout reads the call beside the list', (tester) async {
    await pumpApp(tester, size: const Size(900, 700));

    start('GET', 'https://api.example.com/health');
    finish(200);
    await deliver(tester);

    expect(find.text(strings.noSelection), findsOneWidget);
    await tester.tap(find.byType(PeekEntryTile));
    await tester.pumpAndSettle();

    expect(find.byType(PeekEntryView), findsOneWidget);
    expect(find.byType(PeekEntryScreen), findsNothing);
  });
}
