import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peek/peek.dart';

import '../../support/entries.dart';
import '../../support/fake_store.dart';
import '../../support/pump.dart';

const String _json = '''
{
  "id": 7,
  "name": "Ann",
  "active": true,
  "deleted": null,
  "repos": [
    {"name": "peek", "stars": 12},
    {"name": "peek_dio", "stars": 3}
  ]
}''';

void main() {
  group('PeekJsonNode', () {
    test('builds a tree with paths that read like code', () {
      final root = PeekJsonNode.tryParse(_json)!;
      expect(root.kind, PeekJsonKind.object);
      expect(root.count, 5);
      expect(root.path, isEmpty);

      final repos = root.children.firstWhere((node) => node.name == 'repos');
      expect(repos.kind, PeekJsonKind.array);
      expect(repos.path, 'repos');

      final second = repos.children[1];
      expect(second.path, 'repos[1]');
      expect(second.index, 1);

      final stars = second.children.firstWhere((node) => node.name == 'stars');
      expect(stars.path, 'repos[1].stars');
      expect(stars.kind, PeekJsonKind.number);
      expect(stars.text, '3');
    });

    test('names the kind of every value', () {
      final root = PeekJsonNode.tryParse(_json)!;
      PeekJsonNode child(String name) =>
          root.children.firstWhere((node) => node.name == name);

      expect(child('id').kind, PeekJsonKind.number);
      expect(child('name').kind, PeekJsonKind.string);
      expect(child('name').text, '"Ann"');
      expect(child('active').kind, PeekJsonKind.boolean);
      expect(child('deleted').kind, PeekJsonKind.nothing);
      expect(child('deleted').text, 'null');
    });

    test('draws only the branches that are open', () {
      final root = PeekJsonNode.tryParse(_json)!;
      expect(root.rows(const {}), hasLength(1));
      expect(root.rows(const {''}), hasLength(6));
      expect(root.rows({'', 'repos'}), hasLength(8));
      expect(root.branchPaths, {'', 'repos', 'repos[0]', 'repos[1]'});
    });

    test('opens the way to what a search found', () {
      final root = PeekJsonNode.tryParse(_json)!;
      expect(root.pathsTo('peek_dio'), {'', 'repos', 'repos[1]'});
      expect(root.pathsTo('stars'), {'', 'repos', 'repos[0]', 'repos[1]'});
      expect(root.pathsTo('nothing at all'), isEmpty);
      expect(root.pathsTo('  '), isEmpty);
    });

    test('gives a subtree back as JSON', () {
      final root = PeekJsonNode.tryParse(_json)!;
      final repos = root.children.firstWhere((node) => node.name == 'repos');
      expect(repos.toPrettyJson(), startsWith('[\n'));
      expect(repos.toPrettyJson(), contains('"name": "peek"'));
    });

    test('says when it is not JSON', () {
      expect(PeekJsonNode.tryParse('<html></html>'), isNull);
      expect(PeekJsonNode.tryParse(''), isNull);
    });
  });

  Future<void> pumpTree(
    WidgetTester tester,
    Widget child, {
    Brightness brightness = Brightness.light,
    Size size = const Size(420, 600),
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
    await tester.pump();
  }

  group('PeekJsonTreeView', () {
    testWidgets('opens far enough to show the shape', (tester) async {
      await pumpTree(tester, const PeekJsonTreeView(source: _json));
      expect(find.textContaining('name: "Ann"'), findsOneWidget);
      expect(find.textContaining('repos: […]'), findsOneWidget);
      // The array and both objects in it hold two values each.
      expect(find.textContaining('2 items'), findsNWidgets(3));
      expect(find.textContaining('stars: 12'), findsNothing);
    });

    testWidgets('opens and closes a branch on tap', (tester) async {
      await pumpTree(tester, const PeekJsonTreeView(source: _json));
      expect(find.textContaining('name: "peek"'), findsNothing);

      await tester.tap(find.textContaining('0: {…}'));
      await tester.pump();
      expect(find.textContaining('name: "peek"'), findsOneWidget);

      await tester.tap(find.textContaining('0: {…}'));
      await tester.pump();
      expect(find.textContaining('name: "peek"'), findsNothing);
    });

    testWidgets('opens everything and closes everything', (tester) async {
      await pumpTree(tester, const PeekJsonTreeView(source: _json));
      await tester.tap(find.byTooltip('Expand all'));
      await tester.pump();
      expect(find.textContaining('stars: 12'), findsOneWidget);
      expect(find.textContaining('stars: 3'), findsOneWidget);

      await tester.tap(find.byTooltip('Collapse all'));
      await tester.pump();
      expect(find.textContaining('name: "Ann"'), findsNothing);
    });

    testWidgets('a search opens the way to what it found', (tester) async {
      // The field itself holds the word too, so look only at the rows.
      final inTree = find.descendant(
        of: find.byType(ListView),
        matching: find.textContaining('peek_dio'),
      );

      await pumpTree(tester, const PeekJsonTreeView(source: _json));
      expect(inTree, findsNothing);

      await tester.enterText(find.byType(CupertinoSearchTextField), 'peek_dio');
      await tester.pump();
      expect(inTree, findsOneWidget);
    });

    testWidgets('copies a value and a path from a held row', (tester) async {
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

      await pumpTree(tester, const PeekJsonTreeView(source: _json));
      await tester.longPress(find.textContaining('repos: […]'));
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(find.text('repos'), findsOneWidget);

      await tester.tap(find.text('Copy path'));
      for (var frame = 0; frame < 8; frame++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(copied.single, 'repos');
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('falls back to text when it is not JSON', (tester) async {
      await pumpTree(
        tester,
        const PeekJsonTreeView(source: '<html>not json</html>'),
      );
      expect(find.text('This is not valid JSON'), findsOneWidget);
      expect(find.byType(PeekTextBodyView), findsOneWidget);
      expect(find.textContaining('not json'), findsOneWidget);
    });

    testWidgets('survives large text', (tester) async {
      await pumpTree(
        tester,
        const PeekJsonTreeView(source: _json),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('goldens', () {
    for (final brightness in Brightness.values) {
      testWidgets('a tree in ${brightness.name}', (tester) async {
        await pumpTree(
          tester,
          const PeekJsonTreeView(source: _json),
          brightness: brightness,
        );
        await tester.tap(find.byTooltip('Expand all'));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await expectGolden(
          find.byType(PeekJsonTreeView),
          'body-json-${brightness.name}',
        );
      });
    }
  });
}
