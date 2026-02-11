import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';

final class _FakeAdapter implements PeekAdapter {
  _FakeAdapter(this.name, {this.throwOnDispose = false});

  @override
  final String name;
  final bool throwOnDispose;
  int disposed = 0;

  @override
  void dispose() {
    disposed++;
    if (throwOnDispose) throw StateError('cannot dispose $name');
  }
}

final class _ThrowingStore implements PeekStore {
  @override
  List<PeekEntry> get entries => const [];

  @override
  int get length => 0;

  @override
  Stream<PeekStoreChange> get changes => const Stream.empty();

  @override
  PeekEntry? find(PeekId id) => null;

  @override
  void upsert(PeekEntry entry) => throw StateError('store is broken');

  @override
  bool remove(PeekId id) => false;

  @override
  void clear() => throw StateError('store is broken');

  @override
  void dispose() {}
}

void main() {
  const id = PeekId('call');
  final t0 = DateTime.utc(2026, 9, 10, 12);
  final t1 = t0.add(const Duration(milliseconds: 80));
  final request = PeekRequest(
    method: 'POST',
    uri: Uri.parse('https://api.example.com/login?token=q'),
    headers: PeekHeaders.fromMap({'Authorization': 'Bearer x'}),
    body: PeekBody.text('{"password":"hunter2","note":"0123456789"}'),
  );
  final response = PeekResponse(
    statusCode: 200,
    headers: PeekHeaders.fromMap({'Set-Cookie': 'sid=1; Path=/'}),
    body: PeekBody.text('{"access_token":"a","payload":"0123456789"}'),
  );
  final started = PeekRequestStarted(
    id: id,
    timestamp: t0,
    request: request,
    source: 'test',
  );
  final received = PeekResponseReceived(
    id: id,
    timestamp: t1,
    response: response,
  );

  late List<Object> errors;
  late Peek peek;

  setUp(() {
    errors = [];
    peek = Peek(
      options: PeekOptions(
        limits: const PeekLimits(maxEntries: 3, maxBodyBytes: 30),
        onError: (error, _) => errors.add(error),
      ),
    );
    addTearDown(peek.dispose);
  });

  group('Peek', () {
    test('sizes its store from the limits', () {
      final store = peek.store;
      expect(store, isA<InMemoryPeekStore>());
      expect((store as InMemoryPeekStore).maxEntries, 3);
    });

    test('redacts, truncates and stores what adapters report', () {
      peek.report(started);
      peek.report(received);

      final entry = peek.store.find(id)!;
      expect(entry.state, PeekEntryState.completed);
      expect(entry.request.uri.query, 'token=*****');
      expect(entry.request.headers['authorization'], '*****');
      final requestBody = entry.request.body as PeekTextBody;
      expect(requestBody.text, startsWith('{"password":"*****"'));
      expect(requestBody.isTruncated, isTrue);
      expect(requestBody.capturedSize, lessThanOrEqualTo(30));

      expect(entry.response?.headers['set-cookie'], 'sid=*****; Path=/');
      final responseBody = entry.response?.body as PeekTextBody;
      expect(responseBody.text, startsWith('{"access_token":"*****"'));
      expect(responseBody.isTruncated, isTrue);
      expect(errors, isEmpty);
    });

    test('sanitises failures with a response and recorded entries', () {
      peek.report(started);
      peek.report(
        PeekRequestFailed(
          id: id,
          timestamp: t1,
          failure: const PeekFailure(
            kind: PeekFailureKind.badResponse,
            message: 'boom',
          ),
          response: response,
        ),
      );
      expect(
        peek.store.find(id)?.response?.headers['set-cookie'],
        'sid=*****; Path=/',
      );

      final recorded = PeekEntry(
        id: const PeekId('history'),
        request: request,
        startedAt: t0,
        source: 'history',
        response: response,
        completedAt: t1,
      );
      peek.report(PeekEntryRecorded(recorded));
      final stored = peek.store.find(const PeekId('history'))!;
      expect(stored.request.headers['authorization'], '*****');
      expect((stored.response?.body as PeekTextBody).isTruncated, isTrue);
      expect(stored.source, 'history');
    });

    test('hands dropped events to onError without touching the store', () {
      peek.report(started);
      peek.report(started);
      peek.report(received);
      peek.report(received);

      expect(errors, hasLength(2));
      expect(errors, everyElement(isA<PeekDroppedEventException>()));
      final dropped = errors.cast<PeekDroppedEventException>();
      expect(dropped.first.reason, PeekReduction.duplicateStart);
      expect(dropped.last.reason, PeekReduction.alreadyEnded);
      expect(dropped.first.event, started);
      expect(
        dropped.first.toString(),
        'PeekDroppedEventException(duplicateStart: $started)',
      );
      expect(peek.store.length, 1);
    });

    test('forwards adapter errors to onError', () {
      final error = StateError('mapper broke');
      peek.reportAdapterError(error, StackTrace.empty);
      expect(errors, [error]);
    });

    test('never throws, even when the store or the handler does', () {
      final broken = Peek(
        store: _ThrowingStore(),
        options: PeekOptions(onError: (error, _) => errors.add(error)),
      );
      addTearDown(broken.dispose);
      expect(() => broken.report(started), returnsNormally);
      expect(broken.clear, returnsNormally);
      expect(errors, hasLength(2));
      expect(errors, everyElement(isA<StateError>()));

      final noisy = Peek(
        store: _ThrowingStore(),
        options: PeekOptions(onError: (_, _) => throw StateError('handler')),
      );
      addTearDown(noisy.dispose);
      expect(() => noisy.report(started), returnsNormally);
      expect(
        () => noisy.reportAdapterError('x', StackTrace.empty),
        returnsNormally,
      );

      final silent = Peek(store: _ThrowingStore());
      addTearDown(silent.dispose);
      expect(() => silent.report(started), returnsNormally);
    });

    test('drops events while paused and records again after resume', () {
      peek.pause();
      expect(peek.isPaused, isTrue);
      peek.report(started);
      expect(peek.store.length, 0);
      expect(errors, isEmpty);

      peek.resume();
      expect(peek.isPaused, isFalse);
      peek.report(started);
      expect(peek.store.length, 1);
    });

    test('records nothing when disabled', () {
      final disabled = Peek(
        options: PeekOptions(
          enabled: false,
          onError: (error, _) => errors.add(error),
        ),
      );
      addTearDown(disabled.dispose);
      expect(disabled.isEnabled, isFalse);
      disabled.report(started);
      disabled.report(received);
      expect(disabled.store.length, 0);
      expect(errors, isEmpty);
    });

    test('clears the store', () {
      peek.report(started);
      peek.clear();
      expect(peek.store.length, 0);
    });

    test('registers adapters and disposes them with itself', () async {
      final first = peek.attach(_FakeAdapter('first', throwOnDispose: true));
      final second = peek.attach(_FakeAdapter('second'));
      final third = peek.attach(_FakeAdapter('third'));
      expect(peek.adapters.map((adapter) => adapter.name), [
        'first',
        'second',
        'third',
      ]);
      expect(peek.adapters.clear, throwsUnsupportedError);

      peek.detach(second);
      expect(second.disposed, 1);
      expect(peek.adapters, [first, third]);
      peek.detach(second);
      expect(second.disposed, 1);

      var done = false;
      peek.store.changes.listen(null, onDone: () => done = true);
      peek.dispose();
      peek.dispose();
      expect(peek.isDisposed, isTrue);
      expect(first.disposed, 1);
      expect(third.disposed, 1);
      expect(peek.adapters, isEmpty);
      expect(errors.single, isA<StateError>());
      expect(() => peek.report(started), returnsNormally);
      expect(peek.clear, returnsNormally);
      await pumpEventQueue();
      expect(done, isTrue);
    });

    test('offers a lazily created default instance that can be replaced', () {
      final first = Peek.instance;
      expect(identical(Peek.instance, first), isTrue);
      expect(first.isEnabled, isTrue);

      first.dispose();
      final second = Peek.instance;
      expect(identical(second, first), isFalse);

      final custom = Peek(options: const PeekOptions(enabled: false));
      Peek.instance = custom;
      expect(identical(Peek.instance, custom), isTrue);
      second.dispose();
      expect(identical(Peek.instance, custom), isTrue);
      custom.dispose();
      expect(identical(Peek.instance, custom), isFalse);
      Peek.instance.dispose();
    });
  });
}
