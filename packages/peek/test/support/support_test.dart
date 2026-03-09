import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';

import 'entries.dart';
import 'fake_store.dart';
import 'pump.dart';

void main() {
  group('fixtures', () {
    test('cover the states, sources and bodies the UI has to draw', () {
      expect(uiFixtures, hasLength(14));
      expect(
        uiFixtures.map((entry) => entry.state).toSet(),
        PeekEntryState.values.toSet(),
      );
      expect(uiFixtures.map((entry) => entry.source).toSet(), {
        'dio',
        'talker',
      });
      expect(
        uiFixtures.map((entry) => entry.request.method).toSet(),
        containsAll(['GET', 'POST', 'DELETE']),
      );
      expect(
        uiFixtures
            .map((entry) => entry.response?.body)
            .whereType<PeekBody>()
            .map((body) => body.runtimeType)
            .toSet(),
        containsAll([PeekTextBody, PeekBytesBody, PeekUnavailableBody]),
      );
      expect(upload.request.body, isA<PeekFormBody>());
      expect(redirected.response?.redirects, hasLength(2));
      expect(bigJson.responseSize, greaterThan(10000));
      expect(longUrl.request.uri.toString().length, greaterThan(120));
      expect(image.response?.body, isA<PeekBytesBody>());
      expect(uiFixtures.map((entry) => entry.id.value).toSet(), hasLength(14));
    });
  });

  group('FakePeekStore', () {
    test('holds entries and records what it emitted', () async {
      final store = FakePeekStore([e1]);
      addTearDown(store.dispose);
      expect(store.length, 1);
      expect(store.find(e1.id), e1);

      store
        ..upsert(e2)
        ..upsert(e2.copyWith(isPinned: true))
        ..remove(e1.id)
        ..clear();
      expect(store.remove(const PeekId('missing')), isFalse);

      expect(store.emitted, [
        PeekEntryAdded(e2),
        PeekEntryUpdated(e2.copyWith(isPinned: true)),
        PeekEntryRemoved(e1),
        const PeekStoreCleared(),
      ]);
      expect(store.entries, isEmpty);
    });

    test('streams changes and closes on dispose', () async {
      final store = FakePeekStore();
      final seen = <PeekStoreChange>[];
      var done = false;
      store.changes.listen(seen.add, onDone: () => done = true);

      store.upsert(e1);
      await pumpEventQueue();
      expect(seen, [PeekEntryAdded(e1)]);

      store.dispose();
      store.dispose();
      await pumpEventQueue();
      expect(done, isTrue);
      expect(store.disposed, isTrue);
    });
  });

  group('fakePeek', () {
    test('wires a Peek to a fake store and a still clock', () {
      final (:peek, :store, :clock) = fakePeek(entries: [e1]);
      addTearDown(peek.dispose);

      expect(peek.store, same(store));
      expect(peek.options.clock, same(clock));
      expect(clock.now(), DateTime.utc(2026));

      peek.report(
        PeekRequestStarted(
          id: const PeekId('new'),
          timestamp: clock.now(),
          request: e1.request,
          source: 'test',
        ),
      );
      expect(store.length, 2);
      expect(store.emitted.last, isA<PeekEntryAdded>());
    });
  });

  group('pumpPeek', () {
    testWidgets('renders a child at the size it was given', (tester) async {
      await pumpPeek(tester, const Placeholder());
      expect(find.byType(Placeholder), findsOneWidget);
      expect(tester.getSize(find.byType(Placeholder)), const Size(400, 800));
    });

    testWidgets('applies brightness and text scale', (tester) async {
      await pumpPeek(
        tester,
        const Text('hi'),
        brightness: Brightness.dark,
        textScale: 2,
        size: const Size(320, 200),
      );
      final context = tester.element(find.text('hi'));
      expect(Theme.of(context).brightness, Brightness.dark);
      expect(MediaQuery.textScalerOf(context).scale(10), 20);
      expect(tester.getSize(find.byType(Scaffold)), const Size(320, 200));
    });

    testWidgets('golden helper is a no-op where goldens are off', (
      tester,
    ) async {
      await pumpPeek(tester, const Placeholder());
      if (!goldensEnabled) {
        await expectGolden(find.byType(Placeholder), 'does-not-exist');
      }
      expect(skipGoldens, goldensEnabled ? isFalse : isA<String>());
    });
  });
}
