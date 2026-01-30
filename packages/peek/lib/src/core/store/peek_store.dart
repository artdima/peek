import 'package:meta/meta.dart';

import '../model/peek_entry.dart';
import '../model/peek_id.dart';

/// Holds the entries Peek shows.
///
/// Entries keep the order they were first added in; sort them for display.
/// [changes] delivers asynchronously, while [entries] and [find] reflect a
/// change the moment it is made.
abstract interface class PeekStore {
  /// A snapshot of every entry, oldest first.
  List<PeekEntry> get entries;

  /// Number of entries held.
  int get length;

  /// Every change, in order, delivered asynchronously.
  Stream<PeekStoreChange> get changes;

  /// The entry with [id], if held.
  PeekEntry? find(PeekId id);

  /// Adds [entry], or replaces the entry with the same id in place.
  void upsert(PeekEntry entry);

  /// Removes the entry with [id]; returns whether there was one.
  bool remove(PeekId id);

  /// Removes every entry.
  void clear();

  /// Closes [changes]. The store must not be used afterwards.
  void dispose();
}

/// What changed in a [PeekStore].
@immutable
sealed class PeekStoreChange {
  const PeekStoreChange();
}

/// A new entry was added.
final class PeekEntryAdded extends PeekStoreChange {
  /// Creates the change.
  const PeekEntryAdded(this.entry);

  /// The entry as added.
  final PeekEntry entry;

  @override
  bool operator ==(Object other) =>
      other is PeekEntryAdded && other.entry == entry;

  @override
  int get hashCode => Object.hash(PeekEntryAdded, entry);

  @override
  String toString() => 'PeekEntryAdded(${entry.id})';
}

/// An existing entry was replaced.
final class PeekEntryUpdated extends PeekStoreChange {
  /// Creates the change.
  const PeekEntryUpdated(this.entry);

  /// The entry as it is now.
  final PeekEntry entry;

  @override
  bool operator ==(Object other) =>
      other is PeekEntryUpdated && other.entry == entry;

  @override
  int get hashCode => Object.hash(PeekEntryUpdated, entry);

  @override
  String toString() => 'PeekEntryUpdated(${entry.id})';
}

/// An entry was removed, by hand or by eviction.
final class PeekEntryRemoved extends PeekStoreChange {
  /// Creates the change.
  const PeekEntryRemoved(this.entry);

  /// The entry as it was.
  final PeekEntry entry;

  @override
  bool operator ==(Object other) =>
      other is PeekEntryRemoved && other.entry == entry;

  @override
  int get hashCode => Object.hash(PeekEntryRemoved, entry);

  @override
  String toString() => 'PeekEntryRemoved(${entry.id})';
}

/// Every entry was removed at once.
final class PeekStoreCleared extends PeekStoreChange {
  /// Creates the change.
  const PeekStoreCleared();

  @override
  bool operator ==(Object other) => other is PeekStoreCleared;

  @override
  int get hashCode => (PeekStoreCleared).hashCode;

  @override
  String toString() => 'PeekStoreCleared()';
}
