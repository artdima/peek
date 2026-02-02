import '../model/peek_entry.dart';
import '../model/peek_request.dart';
import '../sink/peek_event.dart';
import 'peek_store.dart';

/// What a [PeekEventReducer] did with an event.
enum PeekReduction {
  /// The store changed.
  applied,

  /// A start arrived for an id the store already holds; the event was
  /// dropped. Adapters must not reuse ids.
  duplicateStart,

  /// An ending arrived for a call that had already ended; the event was
  /// dropped. A call ends exactly once.
  alreadyEnded,
}

/// Folds adapter events into a [PeekStore].
///
/// A start creates a pending entry; a response or failure completes the
/// pending entry with that id. An ending for an id the store has never seen
/// becomes an entry whose request is marked as unobserved — adapters that
/// can reconstruct the request should report [PeekEntryRecorded] instead.
/// A recorded entry replaces whatever the store holds, keeping the pin.
final class PeekEventReducer {
  /// Creates a reducer.
  const PeekEventReducer();

  /// The method and source of an entry whose request was never observed.
  static const String unobserved = 'UNOBSERVED';

  /// Applies [event] to [store] and says whether it did.
  PeekReduction apply(PeekStore store, PeekEvent event) {
    final existing = store.find(event.id);
    switch (event) {
      case PeekRequestStarted():
        if (existing != null) return PeekReduction.duplicateStart;
        store.upsert(
          PeekEntry(
            id: event.id,
            request: event.request,
            startedAt: event.timestamp,
            source: event.source,
          ),
        );
      case PeekResponseReceived():
        if (existing != null && existing.state != PeekEntryState.pending) {
          return PeekReduction.alreadyEnded;
        }
        store.upsert(
          (existing ?? _unobserved(event))
              .complete(event.response, at: event.timestamp)
              .copyWith(timings: event.timings),
        );
      case PeekRequestFailed():
        if (existing != null && existing.state != PeekEntryState.pending) {
          return PeekReduction.alreadyEnded;
        }
        store.upsert(
          (existing ?? _unobserved(event))
              .fail(
                event.failure,
                at: event.timestamp,
                response: event.response,
              )
              .copyWith(timings: event.timings),
        );
      case PeekEntryRecorded():
        store.upsert(
          existing == null || !existing.isPinned
              ? event.entry
              : event.entry.copyWith(isPinned: true),
        );
    }
    return PeekReduction.applied;
  }

  static PeekEntry _unobserved(PeekEvent event) => PeekEntry(
    id: event.id,
    request: PeekRequest(
      method: unobserved,
      uri: Uri(scheme: 'peek', host: 'unobserved'),
    ),
    startedAt: event.timestamp,
    source: unobserved,
  );
}
