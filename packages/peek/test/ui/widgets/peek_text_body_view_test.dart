import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peek/peek.dart';

import '../../support/entries.dart';
import '../../support/fake_store.dart';
import '../../support/pump.dart';

void main() {
  Future<void> pumpBody(
    WidgetTester tester,
    Widget child, {
    Brightness brightness = Brightness.light,
    Size size = const Size(420, 500),
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

  const json =
      '{\n'
      '  "id": 1,\n'
      '  "name": "Ann",\n'
      '  "repos": ["peek", "peek_dio"]\n'
      '}';

  group('PeekTextBodyView', () {
    testWidgets('numbers the lines and shows them all', (tester) async {
      await pumpBody(tester, const PeekTextBodyView(text: json));
      expect(find.text('1'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.textContaining('"name": "Ann"'), findsOneWidget);
    });

    testWidgets('says how much of the body it holds', (tester) async {
      await pumpBody(
        tester,
        const PeekTextBodyView(text: json, capturedSize: 512, totalSize: 5120),
      );
      expect(find.text('Showing 512 B of 5 KB'), findsOneWidget);
    });

    testWidgets('keeps quiet when it holds the whole body', (tester) async {
      await pumpBody(
        tester,
        const PeekTextBodyView(text: json, capturedSize: 64, totalSize: 64),
      );
      expect(find.textContaining('Showing'), findsNothing);
    });

    testWidgets('walks the matches of a search', (tester) async {
      await pumpBody(tester, const PeekTextBodyView(text: json));
      expect(find.textContaining(' of '), findsNothing);

      await tester.enterText(find.byType(CupertinoSearchTextField), 'peek');
      await tester.pump();
      expect(find.text('1 of 2'), findsOneWidget);

      await tester.tap(find.byTooltip('Next match'));
      await tester.pump();
      expect(find.text('2 of 2'), findsOneWidget);

      // Round the corner, back to the first.
      await tester.tap(find.byTooltip('Next match'));
      await tester.pump();
      expect(find.text('1 of 2'), findsOneWidget);
    });

    testWidgets('says plainly when a search finds nothing', (tester) async {
      await pumpBody(tester, const PeekTextBodyView(text: json));
      await tester.enterText(
        find.byType(CupertinoSearchTextField),
        'nothing-here',
      );
      await tester.pump();

      expect(find.text('0 of 0'), findsOneWidget);
      expect(
        tester
            .widget<PeekIconButton>(
              find.ancestor(
                of: find.byTooltip('Next match'),
                matching: find.byType(PeekIconButton),
              ),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('turns wrapping on and off', (tester) async {
      await pumpBody(tester, const PeekTextBodyView(text: json));
      expect(find.byTooltip('Wrap lines'), findsOneWidget);

      await tester.tap(find.byTooltip('Wrap lines'));
      await tester.pump();
      expect(find.byTooltip('Stop wrapping'), findsOneWidget);
    });

    testWidgets('copies the whole body', (tester) async {
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

      await pumpBody(tester, const PeekTextBodyView(text: json));
      await tester.tap(find.byType(PeekCopyButton));
      await tester.pump();
      expect(copied.single, json);
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('renders only what fits, even at 50 000 lines', (tester) async {
      final huge = List.generate(50000, (index) => 'line $index').join('\n');
      await pumpBody(tester, PeekTextBodyView(text: huge));

      expect(find.textContaining('line 0'), findsOneWidget);
      expect(find.textContaining('line 4000'), findsNothing);
      // A handful of lines plus the toolbar, not fifty thousand.
      expect(find.byType(Text).evaluate().length, lessThan(200));
    });

    testWidgets('survives large text', (tester) async {
      await pumpBody(tester, const PeekTextBodyView(text: json), textScale: 2);
      expect(tester.takeException(), isNull);
    });
  });

  group('goldens', () {
    for (final brightness in Brightness.values) {
      testWidgets('a body in ${brightness.name}', (tester) async {
        await pumpBody(
          tester,
          const PeekTextBodyView(
            text: json,
            capturedSize: 512,
            totalSize: 5120,
          ),
          brightness: brightness,
        );
        await tester.enterText(find.byType(CupertinoSearchTextField), 'peek');
        await tester.pump();
        expect(tester.takeException(), isNull);
        await expectGolden(
          find.byType(PeekTextBodyView),
          'body-text-${brightness.name}',
        );
      });
    }
  });
}
