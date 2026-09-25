import 'dart:async';
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
    testWidgets('shows JSON as a tree, or as it arrived', (tester) async {
      await pumpBody(
        tester,
        PeekBody.text('{"id": 1}', contentType: PeekMediaType.json),
      );
      expect(find.byType(PeekJsonTreeView), findsOneWidget);
      expect(find.byType(PeekTextBodyView), findsNothing);

      // One button, showing the way it would switch to.
      await tester.tap(find.byTooltip(const PeekStrings().raw));
      await tester.pump();
      expect(find.byType(PeekTextBodyView), findsOneWidget);
      expect(find.byType(PeekJsonTreeView), findsNothing);

      await tester.tap(find.byTooltip(const PeekStrings().tree));
      await tester.pump();
      expect(find.byType(PeekJsonTreeView), findsOneWidget);
    });

    testWidgets('offers the choice only where there is one', (tester) async {
      await pumpBody(
        tester,
        PeekBody.text('plain', contentType: PeekMediaType.plainText),
      );
      expect(find.byTooltip(const PeekStrings().raw), findsNothing);
      expect(find.byTooltip(const PeekStrings().tree), findsNothing);
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

  final remoteCall = PeekEntry(
    id: const PeekId('remote'),
    request: PeekRequest(
      method: 'GET',
      uri: Uri.parse('https://api.example.com/catalog'),
    ),
    startedAt: fixtureStart,
    source: 'dio',
    response: PeekResponse(
      statusCode: 200,
      body: const PeekBody.remote(size: 2048, contentType: PeekMediaType.json),
    ),
    completedAt: fixtureStart,
  );

  Future<FakePeekStore> pumpRemote(
    WidgetTester tester, {
    PeekBodyLoader? loader,
    Brightness brightness = Brightness.light,
  }) async {
    final (:peek, :store, :clock) = fakePeek(entries: [remoteCall]);
    final controller = PeekController(peek);
    addTearDown(controller.dispose);
    addTearDown(peek.dispose);
    await pumpPeek(
      tester,
      PeekScope(
        controller: controller,
        bodyLoader: loader,
        child: PeekBodyView(
          remoteCall.response!.body,
          entryId: remoteCall.id,
          side: PeekBodySide.response,
        ),
      ),
      brightness: brightness,
      size: const Size(420, 400),
    );
    await tester.pump();
    return store;
  }

  group('PeekRemoteBodyView', () {
    const strings = PeekStrings();

    testWidgets('loads the body, shows it and keeps it in the store', (
      tester,
    ) async {
      final asked = <(PeekId, PeekBodySide)>[];
      final store = await pumpRemote(
        tester,
        loader: PeekBodyLoader.from((id, side) async {
          asked.add((id, side));
          return PeekBody.text('{"items":[]}', contentType: PeekMediaType.json);
        }),
      );
      expect(find.text(strings.remoteBody), findsOneWidget);
      expect(find.text('application/json · 2 KB'), findsOneWidget);

      await tester.tap(find.text(strings.loadBody));
      await tester.pump();
      await tester.pump();

      expect(asked, [(remoteCall.id, PeekBodySide.response)]);
      expect(find.byType(PeekRemoteBodyView), findsOneWidget);
      expect(find.byType(PeekJsonTreeView), findsOneWidget);
      expect(
        store.find(remoteCall.id)!.response!.body,
        PeekBody.text('{"items":[]}', contentType: PeekMediaType.json),
      );
    });

    testWidgets('says it is loading and takes no second tap', (tester) async {
      final pending = Completer<PeekBody>();
      var calls = 0;
      await pumpRemote(
        tester,
        loader: PeekBodyLoader.from((id, side) {
          calls++;
          return pending.future;
        }),
      );
      await tester.tap(find.text(strings.loadBody));
      await tester.pump();
      expect(find.text(strings.loadingBody), findsOneWidget);
      await tester.tap(find.text(strings.loadingBody));
      await tester.pump();
      expect(calls, 1);

      pending.complete(PeekBody.text('done'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(PeekTextBodyView), findsOneWidget);
      expect(find.text(strings.loadingBody), findsNothing);
    });

    testWidgets('offers to retry when loading fails', (tester) async {
      var attempts = 0;
      final store = await pumpRemote(
        tester,
        loader: PeekBodyLoader.from((id, side) async {
          attempts++;
          if (attempts == 1) throw StateError('device offline');
          return PeekBody.text('second time');
        }),
      );
      await tester.tap(find.text(strings.loadBody));
      await tester.pump();
      await tester.pump();
      expect(find.text(strings.loadBodyFailed), findsOneWidget);
      expect(find.text(strings.retry), findsOneWidget);
      expect(store.find(remoteCall.id)!.response!.body, isA<PeekRemoteBody>());

      await tester.tap(find.text(strings.retry));
      await tester.pump();
      await tester.pump();
      expect(attempts, 2);
      expect(
        store.find(remoteCall.id)!.response!.body,
        PeekBody.text('second time'),
      );
    });

    testWidgets('treats the marker coming back as a failure', (tester) async {
      await pumpRemote(
        tester,
        loader: PeekBodyLoader.from(
          (id, side) async => const PeekBody.remote(size: 2048),
        ),
      );
      await tester.tap(find.text(strings.loadBody));
      await tester.pump();
      await tester.pump();
      expect(find.text(strings.loadBodyFailed), findsOneWidget);
    });

    testWidgets('without a loader shows what it knows and no button', (
      tester,
    ) async {
      await pumpRemote(tester);
      expect(find.text(strings.remoteBody), findsOneWidget);
      expect(find.text('application/json · 2 KB'), findsOneWidget);
      expect(find.byType(PeekFilledButton), findsNothing);
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

      testWidgets('a body on the device in ${brightness.name}', (tester) async {
        await pumpRemote(
          tester,
          loader: PeekBodyLoader.from((id, side) async => PeekBody.text('')),
          brightness: brightness,
        );
        expect(tester.takeException(), isNull);
        await expectGolden(
          find.byType(PeekRemoteBodyView),
          'body-remote-${brightness.name}',
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
