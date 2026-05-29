import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peek/peek.dart';

import '../../support/entries.dart';
import '../../support/fake_store.dart';

void main() {
  late PeekController controller;

  Future<void> pumpScreen(
    WidgetTester tester, {
    PeekShareDelegate? share,
    List<PeekEntry> entries = const [],
  }) async {
    final wired = fakePeek(entries: entries.isEmpty ? fixtures : entries);
    controller = PeekController(wired.peek);
    addTearDown(controller.dispose);
    addTearDown(wired.peek.dispose);

    tester.view
      ..physicalSize = const Size(420, 760)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: PeekScreen(
          peek: wired.peek,
          controller: controller,
          share: share,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester) async {
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  List<String> mockClipboard(WidgetTester tester) {
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
    return copied;
  }

  group('entry actions', () {
    testWidgets('copies a call four ways', (tester) async {
      final copied = mockClipboard(tester);

      for (final (label, check) in [
        ('Copy URL', 'https://api.example.com/users'),
        ('Copy as cURL', 'curl '),
        ('Copy as text', 'GET'),
        ('Copy as Markdown', '#'),
        ('Export HAR', '"log"'),
      ]) {
        await pumpScreen(tester, entries: [e1]);
        await tester.longPress(find.byType(PeekEntryTile));
        await settle(tester);
        await tester.tap(find.text(label));
        await settle(tester);

        expect(copied.last, contains(check), reason: label);
        await tester.pump(const Duration(seconds: 2));
      }
    });

    testWidgets('hands an export to the delegate', (tester) async {
      final shared = <PeekShareContent>[];
      await pumpScreen(
        tester,
        entries: [e1],
        share: PeekShareDelegate.from((content) async => shared.add(content)),
      );

      await tester.longPress(find.byType(PeekEntryTile));
      await settle(tester);
      await tester.tap(find.text('Share as HAR'));
      await settle(tester);

      expect(shared.single.filename, endsWith('.har'));
      expect(shared.single.mimeType, 'application/json');
      expect(shared.single.text, contains('api.example.com/users'));
    });

    testWidgets('pins from the menu', (tester) async {
      await pumpScreen(tester, entries: [e1]);
      await tester.longPress(find.byType(PeekEntryTile));
      await settle(tester);
      await tester.tap(find.text('Pin'));
      await settle(tester);

      expect(controller.peek.store.find(e1.id)?.isPinned, isTrue);
    });
  });

  group('list actions', () {
    testWidgets('exports what the list shows, not what it holds', (
      tester,
    ) async {
      final copied = mockClipboard(tester);
      await pumpScreen(tester);
      controller.filter = const PeekFilter(methods: {'POST'});
      await tester.pump();

      await tester.tap(find.byTooltip('More'));
      await settle(tester);
      await tester.tap(find.text('Export HAR'));
      await settle(tester);

      expect(copied.single, contains('/login'));
      expect(copied.single, isNot(contains('/users')));
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('offers sharing only with a delegate', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.byTooltip('More'));
      await settle(tester);
      expect(find.text('Export HAR'), findsOneWidget);
      expect(find.text('Share as HAR'), findsNothing);
    });
  });
}
