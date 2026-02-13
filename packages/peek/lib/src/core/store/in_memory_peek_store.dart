import 'dart:async';

import '../model/peek_entry.dart';
import '../model/peek_id.dart';
import 'peek_store.dart';

/// A [PeekStore] that keeps at most [maxEntries] entries in memory.
///
/// When full, adding an entry evicts the oldest unpinned completed one, so
/// calls still in flight and entries the user pinned are not lost. Only
/// when nothing else is left does the oldest pending, and as a last resort
/// the oldest pinned, entry go — the limit is never exceeded.
final class InMemoryPeekStore implements PeekStore {
  /// Creates a store bounded to [maxEntries], which must be positive.
  InMemoryPeekStore({this.maxEntries = 1000}) {
    if (maxEntries < 1) {
      throw ArgumentError.value(maxEntries, 'maxEntries', 'must be positive');
    }
  }

  /// The most entries the store holds before evicting.
  final int maxEntries;

  final Map<PeekId, PeekEntry> _entries = {};
  final StreamController<PeekStoreChange> _changes =
      StreamController.broadcast();

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
    _checkOpen();
    if (_entries.containsKey(entry.id)) {
      _entries[entry.id] = entry;
      _changes.add(PeekEntryUpdated(entry));
      return;
    }
    if (_entries.length >= maxEntries) {
      _evict();
    }
    _entries[entry.id] = entry;
    _changes.add(PeekEntryAdded(entry));
  }

  @override
  bool remove(PeekId id) {
    _checkOpen();
    final removed = _entries.remove(id);
    if (removed == null) return false;
    _changes.add(PeekEntryRemoved(removed));
    return true;
  }

  @override
  void clear() {
    _checkOpen();
    if (_entries.isEmpty) return;
    _entries.clear();
    _changes.add(const PeekStoreCleared());
  }

  @override
  void dispose() {
    if (_changes.isClosed) return;
    unawaited(_changes.close());
  }

  void _evict() {
    final entries = _entries.values;
    final victim = entries.firstWhere(
      (entry) => !entry.isPinned && entry.state != PeekEntryState.pending,
      orElse:
          () => entries.firstWhere(
            (entry) => !entry.isPinned,
            orElse: () => entries.first,
          ),
    );
    _entries.remove(victim.id);
    _changes.add(PeekEntryRemoved(victim));
  }

  void _checkOpen() {
    if (_changes.isClosed) {
      throw StateError('InMemoryPeekStore was used after dispose');
    }
  }
}
