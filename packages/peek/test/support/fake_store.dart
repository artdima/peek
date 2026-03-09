import 'dart:async';

import 'package:peek/core.dart';

/// A [PeekStore] the tests drive by hand.
///
/// Unlike the real store it never evicts and records what it was asked to
/// do, so a widget test can assert that a tap reached the store.
final class FakePeekStore implements PeekStore {
  /// Creates a store holding [entries].
  FakePeekStore([Iterable<PeekEntry> entries = const []]) {
    for (final entry in entries) {
      _entries[entry.id] = entry;
    }
  }

  final Map<PeekId, PeekEntry> _entries = {};
  final StreamController<PeekStoreChange> _changes =
      StreamController.broadcast();

  /// Every change this store emitted, oldest first.
  final List<PeekStoreChange> emitted = [];

  /// Whether [dispose] has run.
  bool disposed = false;

  @override
  List<PeekEntry> get entries => List.unmodifiable(_entries.values);

  @override
  int get length => _entries.length;

  @override
  Stream<PeekStoreChange> get changes => _changes.stream;

  @override
  PeekEntry? find(PeekId id) => _entries[id];

  @override
  void upsert(PeekEntry entry) {
    final existed = _entries.containsKey(entry.id);
    _entries[entry.id] = entry;
    _emit(existed ? PeekEntryUpdated(entry) : PeekEntryAdded(entry));
  }

  @override
  bool remove(PeekId id) {
    final removed = _entries.remove(id);
    if (removed == null) return false;
    _emit(PeekEntryRemoved(removed));
    return true;
  }

  @override
  void clear() {
    if (_entries.isEmpty) return;
    _entries.clear();
    _emit(const PeekStoreCleared());
  }

  @override
  void dispose() {
    if (disposed) return;
    disposed = true;
    unawaited(_changes.close());
  }

  void _emit(PeekStoreChange change) {
    emitted.add(change);
    if (!_changes.isClosed) _changes.add(change);
  }
}

/// A [Peek] wired to a [FakePeekStore], with a clock that stands still.
///
/// Returns the instance; its `store` is the fake, already typed.
({Peek peek, FakePeekStore store, PeekFakeClock clock}) fakePeek({
  Iterable<PeekEntry> entries = const [],
  PeekOptions? options,
}) {
  final store = FakePeekStore(entries);
  final clock = PeekFakeClock();
  final peek = Peek(
    store: store,
    options: (options ?? const PeekOptions()).copyWith(clock: clock),
  );
  return (peek: peek, store: store, clock: clock);
}
