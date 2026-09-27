import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peek/peek.dart';

import '../../support/pump.dart';

void main() {
  late List<String> completed;
  late List<String> changes;

  Future<GlobalKey<PeekCodeFieldState>> pumpField(
    WidgetTester tester, {
    bool enabled = true,
  }) async {
    final key = GlobalKey<PeekCodeFieldState>();
    completed = [];
    changes = [];
    await pumpPeek(
      tester,
      Center(
        child: PeekCodeField(
          key: key,
          enabled: enabled,
          semanticLabel: 'Pairing code',
          onCompleted: completed.add,
          onChanged: changes.add,
        ),
      ),
    );
    return key;
  }

  final field = find.descendant(
    of: find.byType(PeekCodeField),
    matching: find.byType(EditableText),
  );

  List<String> cells(WidgetTester tester) => [
    for (final text in tester.widgetList<Text>(
      find.descendant(
        of: find.byType(PeekCodeField),
        matching: find.byType(Text),
      ),
    ))
      text.data ?? '',
  ];

  testWidgets('fills a cell per digit and sends the code with the last', (
    tester,
  ) async {
    await pumpField(tester);
    await tester.enterText(field, '4');
    await tester.pump();
    expect(cells(tester), ['4', '', '', '']);

    await tester.enterText(field, '471');
    await tester.pump();
    expect(cells(tester), ['4', '7', '1', '']);
    expect(completed, isEmpty);

    await tester.enterText(field, '4719');
    await tester.pump();
    expect(cells(tester), ['4', '7', '1', '9']);
    expect(completed, ['4719']);
    expect(changes, ['4', '471', '4719']);
  });

  testWidgets('goes back a cell on Backspace', (tester) async {
    await pumpField(tester);
    await tester.enterText(field, '47');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(cells(tester), ['4', '', '', '']);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(cells(tester), ['', '', '', '']);
  });

  testWidgets('spreads a pasted code over the cells', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async =>
          call.method == 'Clipboard.getData' ? {'text': 'Code: 47-19'} : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpField(tester);
    await tester.showKeyboard(field);
    await tester
        .state<EditableTextState>(field)
        .pasteText(SelectionChangedCause.keyboard);
    await tester.pump();
    expect(cells(tester), ['4', '7', '1', '9']);
    expect(completed, ['4719']);
  });

  testWidgets('takes digits only, and no more than there are cells', (
    tester,
  ) async {
    await pumpField(tester);
    await tester.enterText(field, '4a7 b19 2');
    await tester.pump();
    expect(cells(tester), ['4', '7', '1', '9']);
    expect(completed, ['4719']);
  });

  testWidgets('sends a code once, and again only after it changed', (
    tester,
  ) async {
    await pumpField(tester);
    await tester.enterText(field, '4719');
    await tester.pump();
    await tester.enterText(field, '4719');
    await tester.pump();
    expect(completed, ['4719']);

    await tester.enterText(field, '471');
    await tester.pump();
    await tester.enterText(field, '4718');
    await tester.pump();
    expect(completed, ['4719', '4718']);
  });

  testWidgets('shakes and empties when the code is refused', (tester) async {
    final key = await pumpField(tester);
    await tester.enterText(field, '4719');
    await tester.pump();

    key.currentState!.reject();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(cells(tester), ['', '', '', '']);
    Matrix4 shift() =>
        tester
            .widget<Transform>(
              find
                  .descendant(
                    of: find.byType(PeekCodeField),
                    matching: find.byType(Transform),
                  )
                  .first,
            )
            .transform;
    expect(shift().getTranslation().x, isNot(0));

    await tester.pump(const Duration(milliseconds: 400));
    expect(shift().getTranslation().x, moreOrLessEquals(0));
    expect(key.currentState!.code, isEmpty);
  });

  testWidgets('takes no input while disabled', (tester) async {
    await pumpField(tester, enabled: false);
    await tester.tap(find.byType(PeekCodeField));
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('is one field to a screen reader', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpField(tester);
    expect(find.bySemanticsLabel('Pairing code'), findsOneWidget);
    handle.dispose();
  });

  for (final brightness in Brightness.values) {
    testWidgets('looks the part, ${brightness.name}', (tester) async {
      final refused = GlobalKey<PeekCodeFieldState>();
      await pumpPeek(
        tester,
        brightness: brightness,
        size: const Size(320, 260),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PeekCodeField(onCompleted: (_) {}),
              const SizedBox(height: 16),
              PeekCodeField(onCompleted: (_) {}),
              const SizedBox(height: 16),
              PeekCodeField(key: refused, error: true, onCompleted: (_) {}),
            ],
          ),
        ),
      );
      await tester.enterText(find.byType(EditableText).at(2), '47');
      await tester.enterText(find.byType(EditableText).at(1), '471');
      await tester.pump(const Duration(seconds: 1));
      await expectGolden(
        find.byType(MaterialApp),
        'code-field-${brightness.name}',
      );
    });
  }
}
