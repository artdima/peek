import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';

void main() {
  final started = DateTime.utc(2026, 9, 10, 12);
  final later = started.add(const Duration(milliseconds: 250));
  final request = PeekRequest(
    method: 'GET',
    uri: Uri.parse('https://api.example.com/items?page=1'),
    body: PeekBody.text('{}'),
  );

  PeekEntry pending() => PeekEntry(
    id: const PeekId('e1'),
    request: request,
    startedAt: started,
    source: 'test',
  );

  PeekResponse response(int statusCode) =>
      PeekResponse(statusCode: statusCode, body: PeekBody.text('body'));

  const failure = PeekFailure(
    kind: PeekFailureKind.timeout,
    message: 'timed out',
  );

  group('PeekEntry', () {
    test('derives its state from what is attached', () {
      expect(pending().state, PeekEntryState.pending);
      expect(
        pending().complete(response(200), at: later).state,
        PeekEntryState.completed,
      );
      expect(pending().fail(failure, at: later).state, PeekEntryState.failed);
      expect(
        pending().fail(failure, at: later, response: response(503)).state,
        PeekEntryState.failed,
      );
    });

    test('knows its duration once complete, never negative', () {
      expect(pending().duration, isNull);
      expect(
        pending().complete(response(200), at: later).duration,
        const Duration(milliseconds: 250),
      );
      expect(
        pending().fail(failure, at: later).duration,
        const Duration(milliseconds: 250),
      );
      final skewed = pending().complete(
        response(200),
        at: started.subtract(const Duration(seconds: 1)),
      );
      expect(skewed.duration, Duration.zero);
    });

    test('counts failures and 4xx/5xx answers as errors', () {
      expect(pending().isError, isFalse);
      expect(pending().complete(response(200), at: later).isError, isFalse);
      expect(pending().complete(response(304), at: later).isError, isFalse);
      expect(pending().complete(response(404), at: later).isError, isTrue);
      expect(pending().complete(response(500), at: later).isError, isTrue);
      expect(pending().fail(failure, at: later).isError, isTrue);
      expect(
        pending().fail(failure, at: later, response: response(200)).isError,
        isTrue,
      );
    });

    test('passes status through from the response', () {
      expect(pending().statusCode, isNull);
      expect(pending().statusClass, isNull);
      final completed = pending().complete(response(201), at: later);
      expect(completed.statusCode, 201);
      expect(completed.statusClass, PeekStatusClass.success);
    });

    test('adds up the sizes it knows', () {
      expect(pending().requestSize, 2);
      expect(pending().responseSize, isNull);
      expect(pending().totalSize, 2);

      final completed = pending().complete(response(200), at: later);
      expect(completed.responseSize, 4);
      expect(completed.totalSize, 6);

      final unknown = PeekEntry(
        id: const PeekId('e2'),
        request: PeekRequest(
          method: 'POST',
          uri: Uri.parse('https://example.com/'),
          body: PeekBody.form(fields: const [PeekFormField('a', '1')]),
        ),
        startedAt: started,
        source: 'test',
      );
      expect(unknown.totalSize, isNull);
    });

    test('keeps identity, request and source across transitions', () {
      final entry = pending().copyWith(
        isPinned: true,
        timings: const PeekTimings(dns: Duration(milliseconds: 1)),
      );
      final completed = entry.complete(response(200), at: later);
      expect(completed.id, entry.id);
      expect(completed.request, entry.request);
      expect(completed.source, entry.source);
      expect(completed.startedAt, entry.startedAt);
      expect(completed.completedAt, later);
      expect(completed.isPinned, isTrue);
      expect(completed.timings, entry.timings);

      final failed = entry.fail(failure, at: later, response: response(500));
      expect(failed.failure, failure);
      expect(failed.response, response(500));
      expect(failed.completedAt, later);
      expect(failed.isPinned, isTrue);
    });

    test('copies with replaced fields and nothing else', () {
      final entry = pending();
      final copy = entry.copyWith(source: 'other', isPinned: true);
      expect(copy.source, 'other');
      expect(copy.isPinned, isTrue);
      expect(copy.id, entry.id);
      expect(copy.state, PeekEntryState.pending);
      expect(entry.copyWith(), entry);
    });

    test('compares by value', () {
      final entry = pending().complete(response(200), at: later);
      final same = pending().complete(response(200), at: later);
      expect(entry, same);
      expect(entry.hashCode, same.hashCode);
      expect(entry, isNot(pending()));
      expect(entry, isNot(entry.copyWith(isPinned: true)));
      expect(entry, isNot(entry.copyWith(source: 'other')));
      expect(entry, isNot(pending().complete(response(201), at: later)));
    });

    test('insists on completedAt going with a response or failure', () {
      expect(
        () => PeekEntry(
          id: const PeekId('e3'),
          request: request,
          startedAt: started,
          source: 'test',
          response: response(200),
        ),
        throwsAssertionError,
      );
      expect(
        () => PeekEntry(
          id: const PeekId('e3'),
          request: request,
          startedAt: started,
          source: 'test',
          completedAt: later,
        ),
        throwsAssertionError,
      );
    });

    test('prints id, method, location and outcome', () {
      expect(
        pending().toString(),
        'PeekEntry(e1 GET api.example.com/items pending)',
      );
      expect(
        pending().complete(response(200), at: later).toString(),
        'PeekEntry(e1 GET api.example.com/items 200)',
      );
      expect(
        pending().fail(failure, at: later).toString(),
        'PeekEntry(e1 GET api.example.com/items failed: timeout)',
      );
    });
  });
}
