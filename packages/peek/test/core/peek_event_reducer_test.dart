import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';

typedef _Row = (PeekEntryState?, PeekEvent, PeekReduction, PeekEntryState);

void main() {
  const id = PeekId('call');
  final t0 = DateTime.utc(2026, 9, 10, 12);
  final t1 = t0.add(const Duration(milliseconds: 120));
  final request = PeekRequest(
    method: 'GET',
    uri: Uri.parse('https://example.com/items'),
  );
  final response = PeekResponse(statusCode: 200);
  const failure = PeekFailure(kind: PeekFailureKind.timeout, message: 'slow');
  const timings = PeekTimings(wait: Duration(milliseconds: 100));

  final started = PeekRequestStarted(
    id: id,
    timestamp: t0,
    request: request,
    source: 'dio',
  );
  final received = PeekResponseReceived(
    id: id,
    timestamp: t1,
    response: response,
    timings: timings,
  );
  final failed = PeekRequestFailed(
    id: id,
    timestamp: t1,
    failure: failure,
    response: PeekResponse(statusCode: 500),
  );
  final recorded = PeekEntryRecorded(
    PeekEntry(
      id: id,
      request: request,
      startedAt: t0,
      source: 'history',
      response: response,
      completedAt: t1,
    ),
  );

  const reducer = PeekEventReducer();
  late InMemoryPeekStore store;

  setUp(() {
    store = InMemoryPeekStore();
    addTearDown(store.dispose);
  });

  PeekEntry entry() => store.find(id)!;

  group('PeekEventReducer', () {
    test('a start creates a pending entry', () {
      expect(reducer.apply(store, started), PeekReduction.applied);
      expect(entry().state, PeekEntryState.pending);
      expect(entry().request, request);
      expect(entry().startedAt, t0);
      expect(entry().source, 'dio');
      expect(entry().completedAt, isNull);
    });

    test('a response completes the pending entry', () {
      reducer.apply(store, started);
      expect(reducer.apply(store, received), PeekReduction.applied);
      expect(entry().state, PeekEntryState.completed);
      expect(entry().response, response);
      expect(entry().completedAt, t1);
      expect(entry().duration, const Duration(milliseconds: 120));
      expect(entry().timings, timings);
      expect(entry().source, 'dio');
      expect(store.length, 1);
    });

    test('a failure fails the pending entry and keeps its response', () {
      reducer.apply(store, started);
      expect(reducer.apply(store, failed), PeekReduction.applied);
      expect(entry().state, PeekEntryState.failed);
      expect(entry().failure, failure);
      expect(entry().response?.statusCode, 500);
      expect(entry().completedAt, t1);
      expect(entry().timings, isNull);
    });

    test('an ending for an unknown id records an unobserved request', () {
      expect(reducer.apply(store, received), PeekReduction.applied);
      expect(entry().state, PeekEntryState.completed);
      expect(entry().request.method, PeekEventReducer.unobserved);
      expect(entry().request.uri.host, 'unobserved');
      expect(entry().source, PeekEventReducer.unobserved);
      expect(entry().startedAt, t1);
      expect(entry().completedAt, t1);
      expect(entry().duration, Duration.zero);

      expect(reducer.apply(store, started), PeekReduction.duplicateStart);
      expect(entry().request.method, PeekEventReducer.unobserved);
    });

    test('a failure for an unknown id does the same', () {
      expect(reducer.apply(store, failed), PeekReduction.applied);
      expect(entry().state, PeekEntryState.failed);
      expect(entry().request.method, PeekEventReducer.unobserved);
    });

    test('drops a second start for the same id', () {
      reducer.apply(store, started);
      final again = PeekRequestStarted(
        id: id,
        timestamp: t1,
        request: request.copyWith(method: 'POST'),
        source: 'other',
      );
      expect(reducer.apply(store, again), PeekReduction.duplicateStart);
      expect(entry().request.method, 'GET');
      expect(entry().source, 'dio');
      expect(store.length, 1);
    });

    test('drops an ending for a call that already ended', () {
      reducer.apply(store, started);
      reducer.apply(store, received);
      final before = entry();

      expect(reducer.apply(store, received), PeekReduction.alreadyEnded);
      expect(reducer.apply(store, failed), PeekReduction.alreadyEnded);
      expect(entry(), before);

      store.clear();
      reducer.apply(store, started);
      reducer.apply(store, failed);
      expect(reducer.apply(store, received), PeekReduction.alreadyEnded);
      expect(entry().state, PeekEntryState.failed);
    });

    test('a recorded entry is stored as is', () {
      expect(reducer.apply(store, recorded), PeekReduction.applied);
      expect(entry(), recorded.entry);
    });

    test('a recorded entry replaces an existing one but keeps its pin', () {
      reducer.apply(store, started);
      store.upsert(entry().copyWith(isPinned: true));

      expect(reducer.apply(store, recorded), PeekReduction.applied);
      expect(entry().state, PeekEntryState.completed);
      expect(entry().source, 'history');
      expect(entry().isPinned, isTrue);

      final unpinned = PeekEntryRecorded(recorded.entry.copyWith(source: 'x'));
      store.upsert(entry().copyWith(isPinned: false));
      reducer.apply(store, unpinned);
      expect(entry().isPinned, isFalse);
      expect(entry().source, 'x');
    });

    test('follows the transition table', () {
      PeekEntry seed(PeekEntryState state) => switch (state) {
        PeekEntryState.pending => PeekEntry(
          id: id,
          request: request,
          startedAt: t0,
          source: 'dio',
        ),
        PeekEntryState.completed => PeekEntry(
          id: id,
          request: request,
          startedAt: t0,
          source: 'dio',
          response: response,
          completedAt: t1,
        ),
        PeekEntryState.failed => PeekEntry(
          id: id,
          request: request,
          startedAt: t0,
          source: 'dio',
          failure: failure,
          completedAt: t1,
        ),
      };

      final table = <_Row>[
        (null, started, PeekReduction.applied, PeekEntryState.pending),
        (null, received, PeekReduction.applied, PeekEntryState.completed),
        (null, failed, PeekReduction.applied, PeekEntryState.failed),
        (null, recorded, PeekReduction.applied, PeekEntryState.completed),
        (
          PeekEntryState.pending,
          started,
          PeekReduction.duplicateStart,
          PeekEntryState.pending,
        ),
        (
          PeekEntryState.pending,
          received,
          PeekReduction.applied,
          PeekEntryState.completed,
        ),
        (
          PeekEntryState.pending,
          failed,
          PeekReduction.applied,
          PeekEntryState.failed,
        ),
        (
          PeekEntryState.completed,
          started,
          PeekReduction.duplicateStart,
          PeekEntryState.completed,
        ),
        (
          PeekEntryState.completed,
          received,
          PeekReduction.alreadyEnded,
          PeekEntryState.completed,
        ),
        (
          PeekEntryState.completed,
          failed,
          PeekReduction.alreadyEnded,
          PeekEntryState.completed,
        ),
        (
          PeekEntryState.failed,
          received,
          PeekReduction.alreadyEnded,
          PeekEntryState.failed,
        ),
        (
          PeekEntryState.failed,
          recorded,
          PeekReduction.applied,
          PeekEntryState.completed,
        ),
      ];

      for (final (initial, event, outcome, state) in table) {
        store.clear();
        if (initial != null) store.upsert(seed(initial));
        expect(reducer.apply(store, event), outcome, reason: '$initial $event');
        expect(entry().state, state, reason: '$initial $event');
      }
    });
  });
}
