import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peek/peek.dart';

import '../../support/entries.dart';
import '../../support/fake_store.dart';
import '../../support/pump.dart';

void main() {
  Future<void> pumpBody(
    WidgetTester tester,
    PeekBody body, {
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
      PeekScope(controller: controller, child: PeekBodyView(body)),
      brightness: brightness,
      size: size,
      textScale: textScale,
    );
    await tester.pump();
  }

  group('PeekBodyView', () {
    testWidgets('shows JSON as a tree', (tester) async {
      await pumpBody(
        tester,
        PeekBody.text('{"id": 1}', contentType: PeekMediaType.json),
      );
      expect(find.byType(PeekJsonTreeView), findsOneWidget);
      expect(find.byType(PeekTextBodyView), findsNothing);
    });

    testWidgets('shows other text as numbered lines', (tester) async {
      await pumpBody(
        tester,
        PeekBody.text('<h1>Hi</h1>', contentType: PeekMediaType.html),
      );
      expect(find.byType(PeekTextBodyView), findsOneWidget);
      expect(find.byType(PeekJsonTreeView), findsNothing);
    });

    testWidgets('draws an image', (tester) async {
      await pumpBody(
        tester,
        PeekBody.bytes(
          transparentPixelPng,
          contentType: PeekMediaType.tryParse('image/png'),
        ),
      );
      expect(find.byType(PeekImageBodyView), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('image/png'), findsOneWidget);
      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(
        tester.getSize(find.byType(InteractiveViewer)).height,
        greaterThan(0),
      );
    });

    testWidgets('lays a form out as fields and files', (tester) async {
      await pumpBody(
        tester,
        PeekBody.form(
          fields: const [PeekFormField('title', 'Sunset')],
          files: const [
            PeekFormFile('photo', filename: 'sunset.png', size: 2048),
          ],
          contentType: PeekMediaType.multipartFormData,
        ),
      );

      expect(find.text('FIELDS'), findsOneWidget);
      expect(find.text('FILES'), findsOneWidget);
      expect(find.text('Sunset'), findsOneWidget);
      expect(find.text('sunset.png'), findsOneWidget);
      expect(find.textContaining('2 KB'), findsOneWidget);
    });

    testWidgets('shows bytes as hex, copyable as base64', (tester) async {
      final bytes = Uint8List.fromList(List.generate(20, (index) => index));
      await pumpBody(
        tester,
        PeekBody.bytes(bytes, contentType: PeekMediaType.octetStream),
      );

      expect(find.byType(PeekBinaryBodyView), findsOneWidget);
      expect(find.textContaining('00 01 02'), findsOneWidget);
      expect(find.text('First 20 bytes'.toUpperCase()), findsOneWidget);
      expect(
        tester.widget<PeekCopyButton>(find.byType(PeekCopyButton).first).text,
        base64Encode(bytes),
      );
    });

    testWidgets('says when there is no body', (tester) async {
      await pumpBody(tester, const PeekBody.empty());
      expect(find.text('Empty'), findsOneWidget);
    });

    testWidgets('says why a body is missing', (tester) async {
      await pumpBody(
        tester,
        const PeekBody.unavailable(PeekBodyUnavailableReason.streamed),
      );
      expect(find.text('Body was streamed and not kept'), findsOneWidget);
    });

    testWidgets('survives large text', (tester) async {
      await pumpBody(
        tester,
        PeekBody.form(fields: const [PeekFormField('title', 'Sunset')]),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('goldens', () {
    for (final brightness in Brightness.values) {
      testWidgets('a form body in ${brightness.name}', (tester) async {
        await pumpBody(
          tester,
          PeekBody.form(
            fields: const [
              PeekFormField('title', 'Sunset'),
              PeekFormField('tags', 'sky,sea'),
            ],
            files: const [
              PeekFormFile('photo', filename: 'sunset.png', size: 2048),
            ],
            contentType: PeekMediaType.multipartFormData,
          ),
          brightness: brightness,
          size: const Size(420, 400),
        );
        expect(tester.takeException(), isNull);
        await expectGolden(
          find.byType(PeekFormBodyView),
          'body-form-${brightness.name}',
        );
      });

      testWidgets('a binary body in ${brightness.name}', (tester) async {
        await pumpBody(
          tester,
          PeekBody.bytes(
            Uint8List.fromList(List.generate(40, (index) => index * 3)),
            contentType: PeekMediaType.octetStream,
          ),
          brightness: brightness,
          size: const Size(420, 400),
        );
        expect(tester.takeException(), isNull);
        await expectGolden(
          find.byType(PeekBinaryBodyView),
          'body-binary-${brightness.name}',
        );
      });
    }
  });
}
