import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peek/peek.dart';

import '../../support/entries.dart';
import '../../support/fake_store.dart';
import '../../support/pump.dart';

void main() {
  Future<void> pumpTile(
    WidgetTester tester,
    Widget child, {
    Brightness brightness = Brightness.light,
    Size size = const Size(400, 200),
    double textScale = 1,
  }) async {
    final (:peek, :store, :clock) = fakePeek(entries: uiFixtures);
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

  group('PeekEntryTile', () {
    testWidgets('leads with the outcome, then the call, then the host', (
      tester,
    ) async {
      await pumpTile(tester, PeekEntryTile(e1));
      expect(find.text('200'), findsOneWidget);
      expect(find.text(' · 10 B · 120 ms'), findsOneWidget);
      expect(find.text('GET'), findsOneWidget);
      expect(find.text('/users'), findsOneWidget);
      expect(find.text('api.example.com'), findsOneWidget);
      expect(find.text('12:00:00.000'), findsOneWidget);

      final context = tester.element(find.text('200'));
      final theme = PeekTheme.of(context);
      expect(tester.widget<Text>(find.text('200')).style?.color, theme.success);
      expect(
        tester.widget<PeekStatusDot>(find.byType(PeekStatusDot)).color,
        theme.success,
      );
    });

    testWidgets('gives the code the reason the server sent with it', (
      tester,
    ) async {
      final withReason = e1.copyWith(
        response: e1.response!.copyWith(statusMessage: 'OK'),
      );
      await pumpTile(tester, PeekEntryTile(withReason));
      expect(find.text('200 OK'), findsOneWidget);
    });

    testWidgets('shows a slash for a bare host', (tester) async {
      final root = e1.copyWith(
        request: e1.request.copyWith(uri: Uri.parse('https://example.com')),
      );
      await pumpTile(tester, PeekEntryTile(root));
      expect(find.text('/'), findsOneWidget);
    });

    testWidgets('leaves the metrics out when nothing is known', (tester) async {
      await pumpTile(tester, PeekEntryTile(e4));
      expect(find.textContaining('—'), findsNothing);
      expect(find.textContaining(' · '), findsNothing);
      expect(find.text('Pending'), findsOneWidget);
    });

    testWidgets('names what stopped a call that never got a status', (
      tester,
    ) async {
      await pumpTile(tester, PeekEntryTile(e5));
      expect(find.text('Timed out'), findsOneWidget);
      expect(find.text(' · 5 s'), findsOneWidget);

      final context = tester.element(find.text('Timed out'));
      expect(
        tester.widget<Text>(find.text('Timed out')).style?.color,
        PeekTheme.of(context).failure,
      );
    });

    testWidgets('marks a pinned entry', (tester) async {
      await pumpTile(tester, PeekEntryTile(e1));
      expect(find.byIcon(Icons.push_pin), findsNothing);

      await pumpTile(tester, PeekEntryTile(e1.copyWith(isPinned: true)));
      expect(find.byIcon(Icons.push_pin), findsOneWidget);
    });

    testWidgets('washes the selected row and nothing else', (tester) async {
      final wash = find.descendant(
        of: find.byType(PeekTappable),
        matching: find.byType(ColoredBox),
      );

      await pumpTile(tester, PeekEntryTile(e6, onTap: () {}));
      expect(wash, findsNothing);

      await pumpTile(tester, PeekEntryTile(e6, onTap: () {}, selected: true));
      expect(wash, findsOneWidget);
      final context = tester.element(find.byType(PeekEntryTile));
      expect(tester.widget<ColoredBox>(wash).color, PeekTheme.of(context).fill);
    });

    testWidgets('calls back on tap', (tester) async {
      var taps = 0;
      await pumpTile(tester, PeekEntryTile(e1, onTap: () => taps++));
      await tester.tap(find.byType(PeekEntryTile));
      expect(taps, 1);
    });

    testWidgets('offers a menu on long press', (tester) async {
      final actions = <PeekTileAction>[];
      await pumpTile(
        tester,
        PeekEntryTile(e1, onAction: actions.add),
        size: const Size(400, 600),
      );

      await tester.longPress(find.byType(PeekEntryTile));
      await tester.pumpAndSettle();
      expect(find.text('Pin'), findsOneWidget);
      expect(find.text('Copy URL'), findsOneWidget);
      expect(find.text('Copy as cURL'), findsOneWidget);
      expect(find.text('Share'), findsNothing);

      await tester.tap(find.text('Copy URL'));
      await tester.pumpAndSettle();
      expect(actions, [PeekTileAction.copyUrl]);
    });

    testWidgets('says Unpin for a pinned entry and can offer sharing', (
      tester,
    ) async {
      await pumpTile(
        tester,
        PeekEntryTile(
          e1.copyWith(isPinned: true),
          onAction: (_) {},
          showShare: true,
        ),
        size: const Size(400, 600),
      );
      await tester.longPress(find.byType(PeekEntryTile));
      await tester.pumpAndSettle();
      expect(find.text('Unpin'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
    });

    testWidgets('has no menu without a handler', (tester) async {
      await pumpTile(tester, PeekEntryTile(e1));
      await tester.longPress(find.byType(PeekEntryTile));
      await tester.pumpAndSettle();
      expect(find.text('Copy URL'), findsNothing);
    });

    testWidgets('reads out as one label', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpTile(tester, PeekEntryTile(e1, onTap: () {}));

      expect(
        tester.getSemantics(find.byType(PeekEntryTile)),
        matchesSemantics(
          label: 'GET, api.example.com, /users, Status 200, 120 ms',
          isButton: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('announces a selected row as selected', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpTile(tester, PeekEntryTile(e1, onTap: () {}, selected: true));
      expect(
        tester.getSemantics(find.byType(PeekEntryTile)),
        matchesSemantics(
          label: 'GET, api.example.com, /users, Status 200, 120 ms',
          isButton: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
          hasSelectedState: true,
          isSelected: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('exposes what its menu would copy', (tester) async {
      final tile = PeekEntryTile(e1);
      expect(tile.url(), 'https://api.example.com/users');
      expect(tile.curl(), startsWith('curl '));
    });

    testWidgets('survives a long URL and large text', (tester) async {
      await pumpTile(
        tester,
        PeekEntryTile(longUrl),
        size: const Size(360, 200),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('goldens', () {
    for (final brightness in Brightness.values) {
      testWidgets('a list of tiles in ${brightness.name}', (tester) async {
        await pumpTile(
          tester,
          const _TileList(),
          brightness: brightness,
          size: const Size(420, 560),
        );
        expect(tester.takeException(), isNull);
        await expectGolden(find.byType(_TileList), 'tiles-${brightness.name}');
      });
    }
  });
}

class _TileList extends StatelessWidget {
  const _TileList();

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    return ColoredBox(
      color: theme.background,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PeekEntryTile(e1),
          PeekEntryTile(e2),
          PeekEntryTile(e4),
          PeekEntryTile(e5.copyWith(isPinned: true)),
          PeekEntryTile(e6, selected: true),
          PeekEntryTile(upload),
          PeekEntryTile(longUrl),
        ],
      ),
    );
  }
}
