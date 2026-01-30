import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';

void main() {
  final started = DateTime.utc(2026, 9, 10, 12);
  final request = PeekRequest(
    method: 'GET',
    uri: Uri.parse('https://example.com/'),
  );

  PeekEntry pending(String id) => PeekEntry(
    id: PeekId(id),
    request: request,
    startedAt: started,
    source: 'test',
  );

  PeekEntry completed(String id) => pending(id).complete(
    PeekResponse(statusCode: 200),
    at: started.add(const Duration(milliseconds: 10)),
  );

  List<String> ids(PeekStore store) =>
      store.entries.map((entry) => entry.id.value).toList();

  late InMemoryPeekStore store;
  late List<PeekStoreChange> changes;

  setUp(() {
    store = InMemoryPeekStore(maxEntries: 3);
    addTearDown(store.dispose);
    changes = [];
    store.changes.listen(changes.add);
  });

  group('InMemoryPeekStore', () {
    test('adds entries in insertion order and finds them by id', () {
      store.upsert(completed('a'));
      store.upsert(pending('b'));
      expect(ids(store), ['a', 'b']);
      expect(store.length, 2);
      expect(store.find(const PeekId('b')), pending('b'));
      expect(store.find(const PeekId('zzz')), isNull);
    });

    test('replaces an entry in place when the id repeats', () {
      store.upsert(pending('a'));
      store.upsert(pending('b'));
      store.upsert(completed('a'));
      expect(ids(store), ['a', 'b']);
      expect(store.find(const PeekId('a'))?.state, PeekEntryState.completed);
      expect(store.length, 2);
    });

    test('delivers changes asynchronously, in order', () async {
      store.upsert(pending('a'));
      store.upsert(completed('a'));
      store.remove(const PeekId('a'));
      expect(changes, isEmpty);

      await pumpEventQueue();
      expect(changes, [
        PeekEntryAdded(pending('a')),
        PeekEntryUpdated(completed('a')),
        PeekEntryRemoved(completed('a')),
      ]);
    });

    test('evicts the oldest completed entry when full', () async {
      store.upsert(completed('a'));
      store.upsert(completed('b'));
      store.upsert(completed('c'));
      store.upsert(completed('d'));
      expect(ids(store), ['b', 'c', 'd']);
      expect(store.length, 3);

      await pumpEventQueue();
      expect(changes.sublist(3), [
        PeekEntryRemoved(completed('a')),
        PeekEntryAdded(completed('d')),
      ]);
    });

    test('keeps pending entries and evicts a completed one instead', () {
      store.upsert(pending('a'));
      store.upsert(completed('b'));
      store.upsert(completed('c'));
      store.upsert(completed('d'));
      expect(ids(store), ['a', 'c', 'd']);
    });

    test('evicts the oldest pending entry only when all are pending', () {
      store.upsert(pending('a'));
      store.upsert(pending('b'));
      store.upsert(pending('c'));
      store.upsert(pending('d'));
      expect(ids(store), ['b', 'c', 'd']);
    });

    test('does not evict when updating an entry of a full store', () {
      store.upsert(completed('a'));
      store.upsert(completed('b'));
      store.upsert(completed('c'));
      store.upsert(completed('b'));
      expect(ids(store), ['a', 'b', 'c']);
    });

    test('removes by id and says whether it did', () async {
      store.upsert(completed('a'));
      expect(store.remove(const PeekId('a')), isTrue);
      expect(store.remove(const PeekId('a')), isFalse);
      expect(store.length, 0);

      await pumpEventQueue();
      expect(changes.last, PeekEntryRemoved(completed('a')));
      expect(changes.whereType<PeekEntryRemoved>(), hasLength(1));
    });

    test('clears with one change, only when there is something', () async {
      store.clear();
      store.upsert(completed('a'));
      store.upsert(pending('b'));
      store.clear();
      expect(store.entries, isEmpty);

      await pumpEventQueue();
      expect(changes.whereType<PeekStoreCleared>(), hasLength(1));
      expect(changes.last, const PeekStoreCleared());
    });

    test('hands out unmodifiable snapshots', () {
      store.upsert(completed('a'));
      final snapshot = store.entries;
      store.upsert(completed('b'));
      expect(snapshot, hasLength(1));
      expect(snapshot.clear, throwsUnsupportedError);
    });

    test('closes its stream on dispose and refuses further writes', () async {
      var done = false;
      store.changes.listen(null, onDone: () => done = true);
      store.dispose();
      store.dispose();
      await pumpEventQueue();
      expect(done, isTrue);
      expect(() => store.upsert(completed('a')), throwsStateError);
      expect(() => store.remove(const PeekId('a')), throwsStateError);
      expect(store.clear, throwsStateError);
    });

    test('rejects a non-positive limit', () {
      expect(() => InMemoryPeekStore(maxEntries: 0), throwsArgumentError);
      expect(() => InMemoryPeekStore(maxEntries: -5), throwsArgumentError);
      expect(InMemoryPeekStore().maxEntries, 1000);
    });
  });

  group('PeekStoreChange', () {
    test('compares by kind and entry', () {
      final entry = completed('a');
      expect(PeekEntryAdded(entry), PeekEntryAdded(completed('a')));
      expect(PeekEntryAdded(entry).hashCode, PeekEntryAdded(entry).hashCode);
      expect(PeekEntryAdded(entry), isNot(PeekEntryUpdated(entry)));
      expect(PeekEntryUpdated(entry), isNot(PeekEntryRemoved(entry)));
      expect(const PeekStoreCleared(), const PeekStoreCleared());
      expect(PeekEntryAdded(entry).toString(), 'PeekEntryAdded(a)');
      expect(PeekEntryUpdated(entry).toString(), 'PeekEntryUpdated(a)');
      expect(PeekEntryRemoved(entry).toString(), 'PeekEntryRemoved(a)');
      expect(const PeekStoreCleared().toString(), 'PeekStoreCleared()');
    });
  });
}
