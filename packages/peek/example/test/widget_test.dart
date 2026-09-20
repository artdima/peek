import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peek_example/main.dart';

void main() {
  testWidgets('the theme button offers the brightness that is off', (
    tester,
  ) async {
    await tester.pumpWidget(const PeekExampleApp());
    await tester.pump();

    expect(find.text('Peek example'), findsOneWidget);
    expect(find.byIcon(Icons.dark_mode), findsOneWidget);

    await tester.tap(find.byTooltip('Toggle theme'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.light_mode), findsOneWidget);
  });
}
