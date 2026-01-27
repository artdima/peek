import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';

final class _RecordingSink implements PeekSink {
  final List<PeekEvent> events = [];
  final List<Object> errors = [];

  @override
  void report(PeekEvent event) => events.add(event);

  @override
  void reportAdapterError(Object error, StackTrace stackTrace) =>
      errors.add(error);
}

final class _FakeAdapter implements PeekAdapter {
  _FakeAdapter(this.sink);

  final PeekSink sink;
  int disposed = 0;

  @override
  String get name => 'fake';

  @override
  void dispose() => disposed++;
}

void main() {
  const id = PeekId('call-1');
  final at = DateTime.utc(2026, 9, 10, 12);
  final request = PeekRequest(
    method: 'GET',
    uri: Uri.parse('https://example.com/a'),
  );
  final response = PeekResponse(statusCode: 200);
  const failure = PeekFailure(
    kind: PeekFailureKind.connection,
    message: 'refused',
  );

  group('PeekEvent', () {
    test('request started compares by value', () {
      final event = PeekRequestStarted(
        id: id,
        timestamp: at,
        request: request,
        source: 'dio',
      );
      expect(
        event,
        PeekRequestStarted(
          id: id,
          timestamp: at,
          request: request,
          source: 'dio',
        ),
      );
      expect(
        event.hashCode,
        PeekRequestStarted(
          id: id,
          timestamp: at,
          request: request,
          source: 'dio',
        ).hashCode,
      );
      expect(
        event,
        isNot(
          PeekRequestStarted(
            id: id,
            timestamp: at,
            request: request,
            source: 'talker',
          ),
        ),
      );
      expect(event.toString(), 'PeekRequestStarted(call-1 GET)');
    });

    test('response received carries optional timings', () {
      const timings = PeekTimings(wait: Duration(milliseconds: 40));
      final event = PeekResponseReceived(
        id: id,
        timestamp: at,
        response: response,
        timings: timings,
      );
      expect(
        event,
        PeekResponseReceived(
          id: id,
          timestamp: at,
          response: response,
          timings: timings,
        ),
      );
      expect(
        event,
        isNot(PeekResponseReceived(id: id, timestamp: at, response: response)),
      );
      expect(event.toString(), 'PeekResponseReceived(call-1 200)');
    });

    test('request failed may carry the response that came with it', () {
      final bare = PeekRequestFailed(id: id, timestamp: at, failure: failure);
      final withResponse = PeekRequestFailed(
        id: id,
        timestamp: at,
        failure: failure,
        response: response,
      );
      expect(bare, PeekRequestFailed(id: id, timestamp: at, failure: failure));
      expect(bare, isNot(withResponse));
      expect(withResponse.response, response);
      expect(bare.toString(), 'PeekRequestFailed(call-1 connection)');
    });

    test('entry recorded takes id and timestamp from the entry', () {
      final entry = PeekEntry(
        id: id,
        request: request,
        startedAt: at,
        source: 'history',
      );
      final event = PeekEntryRecorded(entry);
      expect(event.id, id);
      expect(event.timestamp, at);
      expect(event, PeekEntryRecorded(entry));
      expect(event.hashCode, PeekEntryRecorded(entry).hashCode);
      expect(event, isNot(PeekEntryRecorded(entry.copyWith(isPinned: true))));
      expect(event.toString(), 'PeekEntryRecorded($entry)');
    });

    test('is exhaustively switchable', () {
      String describe(PeekEvent event) => switch (event) {
        PeekRequestStarted() => 'started',
        PeekResponseReceived() => 'received',
        PeekRequestFailed() => 'failed',
        PeekEntryRecorded() => 'recorded',
      };

      expect(
        describe(
          PeekRequestStarted(
            id: id,
            timestamp: at,
            request: request,
            source: 'dio',
          ),
        ),
        'started',
      );
      expect(
        describe(
          PeekResponseReceived(id: id, timestamp: at, response: response),
        ),
        'received',
      );
      expect(
        describe(PeekRequestFailed(id: id, timestamp: at, failure: failure)),
        'failed',
      );
      expect(
        describe(
          PeekEntryRecorded(
            PeekEntry(
              id: id,
              request: request,
              startedAt: at,
              source: 'history',
            ),
          ),
        ),
        'recorded',
      );
    });
  });

  group('PeekSink and PeekAdapter', () {
    test('can be implemented and driven by an adapter', () {
      final sink = _RecordingSink();
      final adapter = _FakeAdapter(sink);

      final callId = PeekId.generate();
      adapter.sink.report(
        PeekRequestStarted(
          id: callId,
          timestamp: at,
          request: request,
          source: adapter.name,
        ),
      );
      adapter.sink.report(
        PeekResponseReceived(id: callId, timestamp: at, response: response),
      );
      adapter.sink.reportAdapterError(StateError('oops'), StackTrace.empty);
      adapter.dispose();
      adapter.dispose();

      expect(sink.events, hasLength(2));
      expect(sink.events.map((event) => event.id), everyElement(callId));
      expect(sink.events.first, isA<PeekRequestStarted>());
      expect(sink.events.last, isA<PeekResponseReceived>());
      expect(sink.errors.single, isA<StateError>());
      expect(adapter.disposed, 2);
    });
  });
}
