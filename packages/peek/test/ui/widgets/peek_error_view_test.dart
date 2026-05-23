import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peek/peek.dart';

import '../../support/entries.dart';
import '../../support/fake_store.dart';
import '../../support/pump.dart';

void main() {
  Future<void> pumpError(
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
      PeekScope(
        controller: controller,
        child: SingleChildScrollView(child: child),
      ),
      brightness: brightness,
      size: size,
      textScale: textScale,
    );
  }

  group('PeekErrorView', () {
    testWidgets('names the failure and shows its message', (tester) async {
      await pumpError(
        tester,
        const PeekErrorView(
          PeekFailure(
            kind: PeekFailureKind.timeout,
            message: 'Connection timed out after 30 s',
          ),
        ),
      );

      expect(find.text('ERROR'), findsOneWidget);
      expect(find.text('Timed out'), findsOneWidget);
      expect(find.text('Connection timed out after 30 s'), findsOneWidget);
      expect(find.text('DETAILS'), findsNothing);
      expect(find.text('STACK TRACE'), findsNothing);
    });

    testWidgets('shows the details an adapter attached', (tester) async {
      await pumpError(
        tester,
        const PeekErrorView(
          PeekFailure(
            kind: PeekFailureKind.badResponse,
            message: 'Unexpected status',
            details: {'status': 500},
          ),
        ),
      );

      expect(find.text('DETAILS'), findsOneWidget);
      expect(find.text('{status: 500}'), findsOneWidget);
    });

    testWidgets('leads to the answer a failed call still got', (tester) async {
      var shown = 0;
      await pumpError(
        tester,
        PeekErrorView(
          const PeekFailure(
            kind: PeekFailureKind.badResponse,
            message: 'Unexpected status',
          ),
          hasResponse: true,
          onShowResponse: () => shown++,
        ),
      );

      await tester.tap(find.widgetWithText(PeekListRow, 'Response'));
      await tester.pump();
      expect(shown, 1);
    });

    testWidgets('cuts a runaway stack trace short, copies it whole', (
      tester,
    ) async {
      final trace = StackTrace.fromString(
        List.generate(140, (index) => '#$index  someFrame()').join('\n'),
      );
      await pumpError(
        tester,
        PeekErrorView(
          PeekFailure(
            kind: PeekFailureKind.unknown,
            message: 'Boom',
            stackTrace: trace,
          ),
        ),
      );

      expect(find.text('STACK TRACE'), findsOneWidget);
      expect(find.textContaining('#0  someFrame()'), findsOneWidget);
      expect(find.text('40 more lines'), findsOneWidget);
      expect(
        tester
            .widget<PeekCopyButton>(find.byType(PeekCopyButton))
            .text
            ?.split('\n'),
        hasLength(140),
      );
    });

    testWidgets('survives large text', (tester) async {
      await pumpError(
        tester,
        const PeekErrorView(
          PeekFailure(
            kind: PeekFailureKind.connection,
            message: 'Host unreachable',
          ),
        ),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('goldens', () {
    for (final kind in PeekFailureKind.values) {
      testWidgets('a ${kind.name} failure', (tester) async {
        await pumpError(
          tester,
          PeekErrorView(
            PeekFailure(kind: kind, message: 'Something went wrong'),
          ),
          size: const Size(420, 240),
        );
        expect(tester.takeException(), isNull);
        await expectGolden(find.byType(PeekErrorView), 'error-${kind.name}');
      });
    }

    testWidgets('a failure in dark', (tester) async {
      await pumpError(
        tester,
        const PeekErrorView(
          PeekFailure(
            kind: PeekFailureKind.timeout,
            message: 'Connection timed out',
          ),
        ),
        brightness: Brightness.dark,
        size: const Size(420, 240),
      );
      expect(tester.takeException(), isNull);
      await expectGolden(find.byType(PeekErrorView), 'error-dark');
    });
  });
}
