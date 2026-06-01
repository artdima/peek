import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peek/peek.dart';

import '../../support/entries.dart';
import '../../support/fake_store.dart';
import '../../support/pump.dart';

void main() {
  Future<void> pumpView(
    WidgetTester tester,
    Widget child, {
    Brightness brightness = Brightness.light,
    Size size = const Size(420, 700),
    double textScale = 1,
  }) async {
    final peek = fakePeek(entries: fixtures).peek;
    final controller = PeekController(peek);
    addTearDown(controller.dispose);
    addTearDown(peek.dispose);
    await pumpPeek(
      tester,
      PeekScope(
        controller: controller,
        child: SingleChildScrollView(child: child),
      ),
      brightness: brightness,
      size: size,
      textScale: textScale,
    );
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

  final headers = PeekHeaders.fromMap({
    'Content-Type': 'application/json',
    'Authorization': '*****',
    'X-Request-Id': 'abc-123',
  });

  group('PeekHeadersView', () {
    testWidgets('lists the headers and marks what was masked', (tester) async {
      await pumpView(tester, PeekHeadersView(headers));
      expect(find.text('HEADERS'), findsOneWidget);
      expect(find.text('Content-Type'), findsOneWidget);
      expect(find.text('application/json'), findsOneWidget);

      final masked = tester.widget<PeekKeyValueRow>(
        find.widgetWithText(PeekKeyValueRow, 'Authorization'),
      );
      expect(masked.emphasised, isTrue);
      final plain = tester.widget<PeekKeyValueRow>(
        find.widgetWithText(PeekKeyValueRow, 'X-Request-Id'),
      );
      expect(plain.emphasised, isFalse);
    });

    testWidgets('copies one row and the whole block', (tester) async {
      final copied = mockClipboard(tester);
      await pumpView(tester, PeekHeadersView(headers));

      await tester.tap(find.byTooltip('Copy all'));
      await tester.pump();
      expect(copied.single, contains('Content-Type: application/json'));
      expect(copied.single.split('\n'), hasLength(3));

      copied.clear();
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(PeekKeyValueRow, 'X-Request-Id'),
          matching: find.byType(PeekCopyButton),
        ),
      );
      await tester.pump();
      expect(copied.single, 'X-Request-Id: abc-123');

      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('orders by name on request', (tester) async {
      await pumpView(tester, PeekHeadersView(headers));
      expect(_names(tester), ['Content-Type', 'Authorization', 'X-Request-Id']);

      await tester.tap(find.byTooltip('Sort by name'));
      await tester.pump();
      expect(_names(tester), ['Authorization', 'Content-Type', 'X-Request-Id']);
    });

    testWidgets('offers a filter once the table is long', (tester) async {
      await pumpView(tester, PeekHeadersView(headers));
      expect(find.byType(PeekSearchField), findsNothing);

      final many = PeekHeaders.fromMap({
        for (var index = 0; index < 8; index++) 'X-Header-$index': '$index',
      });
      await pumpView(tester, PeekHeadersView(many));
      expect(find.byType(PeekSearchField), findsOneWidget);

      await tester.enterText(find.byType(CupertinoSearchTextField), 'header-3');
      await tester.pump();
      expect(_names(tester), ['X-Header-3']);
    });

    testWidgets('says so when there is nothing to show', (tester) async {
      await pumpView(tester, const PeekHeadersView(PeekHeaders.empty));
      expect(find.text('Empty'), findsOneWidget);
      expect(
        tester.widget<PeekCopyButton>(find.byType(PeekCopyButton)).text,
        isNull,
      );
    });
  });

  group('PeekCookiesView', () {
    testWidgets('shows a cookie with its attributes', (tester) async {
      final cookies =
          PeekHeaders.fromMap({
            'Set-Cookie': 'session=abc; Path=/; HttpOnly',
          }).setCookies;

      await pumpView(tester, PeekCookiesView(cookies));
      expect(find.text('COOKIES'), findsOneWidget);
      expect(find.text('session'), findsOneWidget);
      expect(find.textContaining('path=/'), findsOneWidget);
    });
  });

  group('PeekQueryParamsView', () {
    testWidgets('decodes the values and repeats a repeated key', (
      tester,
    ) async {
      final uri = Uri.parse('https://x.test/s?q=a%20b&tag=one&tag=two');
      await pumpView(tester, PeekQueryParamsView(uri.queryParametersAll));

      expect(find.text('QUERY'), findsOneWidget);
      expect(find.text('a b'), findsOneWidget);
      expect(find.text('one'), findsOneWidget);
      expect(find.text('two'), findsOneWidget);
      expect(_names(tester), ['q', 'tag', 'tag']);
    });
  });

  group('goldens', () {
    for (final brightness in Brightness.values) {
      testWidgets('a table of headers in ${brightness.name}', (tester) async {
        await pumpView(
          tester,
          PeekHeadersView(headers),
          brightness: brightness,
          size: const Size(420, 340),
        );
        expect(tester.takeException(), isNull);
        await expectGolden(
          find.byType(PeekHeadersView),
          'headers-${brightness.name}',
        );
      });
    }

    testWidgets('a table survives large text', (tester) async {
      await pumpView(
        tester,
        PeekHeadersView(headers),
        size: const Size(360, 700),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });
  });
}

List<String> _names(WidgetTester tester) =>
    tester
        .widgetList<PeekKeyValueRow>(find.byType(PeekKeyValueRow))
        .map((row) => row.name)
        .toList();
