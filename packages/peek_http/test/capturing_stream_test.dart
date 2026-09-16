import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:peek_http/src/capturing_stream.dart';

final class Recorder {
  final List<String> outcomes = [];
  Uint8List? captured;
  int? received;
  Object? error;
  StackTrace? stackTrace;

  CapturingStream wrap(Stream<List<int>> source, {int limit = 1024}) =>
      CapturingStream(
        source,
        limit: limit,
        onDone: (captured, received) => _record('done', captured, received),
        onError: (error, stackTrace, captured, received) {
          this.error = error;
          this.stackTrace = stackTrace;
          _record('error', captured, received);
        },
        onCancel: (captured, received) => _record('cancel', captured, received),
      );

  void _record(String outcome, Uint8List captured, int received) {
    outcomes.add(outcome);
    this.captured = captured;
    this.received = received;
  }
}

void main() {
  late Recorder recorder;

  setUp(() => recorder = Recorder());

  group('passing the body on', () {
    test('hands over the same chunks, in order', () async {
      final first = [1, 2];
      final second = [3];

      final seen =
          await recorder.wrap(Stream.fromIterable([first, second])).toList();

      expect(seen, hasLength(2));
      expect(seen.first, same(first));
      expect(seen.last, same(second));
      expect(recorder.outcomes, ['done']);
      expect(recorder.captured, [1, 2, 3]);
      expect(recorder.received, 3);
    });

    test('is single-subscription when the source is', () {
      final stream = recorder.wrap(Stream.value([1]));
      final first = stream.listen(null);
      addTearDown(first.cancel);

      expect(stream.isBroadcast, isFalse);
      expect(() => stream.listen(null), throwsStateError);
    });

    test('lets pause and resume reach the source', () async {
      var paused = 0;
      var resumed = 0;
      final source = StreamController<List<int>>(
        onPause: () => paused++,
        onResume: () => resumed++,
      );
      addTearDown(() => unawaited(source.close()));
      final subscription = recorder.wrap(source.stream).listen((_) {});

      subscription.pause();
      expect(subscription.isPaused, isTrue);
      expect(paused, 1);

      subscription.resume();
      expect(subscription.isPaused, isFalse);
      expect(resumed, 1);

      await subscription.cancel();
    });

    test('lets cancel reach the source and waits for it', () async {
      final sourceCancelled = Completer<void>();
      final source = StreamController<List<int>>(
        onCancel: () => sourceCancelled.future,
      );
      addTearDown(() => unawaited(source.close()));
      final subscription = recorder.wrap(source.stream).listen((_) {});
      source.add([1, 2]);
      await pumpEventQueue();

      final cancelling = subscription.cancel();
      var finished = false;
      unawaited(cancelling.then((_) => finished = true));
      await pumpEventQueue();

      expect(recorder.outcomes, ['cancel']);
      expect(recorder.captured, [1, 2]);
      expect(recorder.received, 2);
      expect(finished, isFalse);

      sourceCancelled.complete();
      await cancelling;
      expect(finished, isTrue);
    });
  });

  group('keeping a prefix', () {
    test('stops at the limit, even mid-chunk, and counts the rest', () async {
      await recorder
          .wrap(
            Stream.fromIterable([
              [1, 2],
              [3, 4, 5],
              [6],
            ]),
            limit: 3,
          )
          .drain<void>();

      expect(recorder.captured, [1, 2, 3]);
      expect(recorder.received, 6);
    });

    test('keeps nothing at a limit of zero, but still counts', () async {
      await recorder.wrap(Stream.value([1, 2, 3]), limit: 0).drain<void>();

      expect(recorder.captured, isEmpty);
      expect(recorder.received, 3);
    });

    test('copies what it keeps', () async {
      final chunk = Uint8List.fromList([1, 2]);

      await recorder.wrap(Stream.value(chunk)).drain<void>();
      chunk[0] = 9;

      expect(recorder.captured, [1, 2]);
    });
  });

  group('errors', () {
    test(
      'the first one ends the capture; the listener sees them all',
      () async {
        final source = StreamController<List<int>>();
        final errors = <Object>[];
        final traces = <StackTrace>[];
        final done = Completer<void>();
        recorder
            .wrap(source.stream)
            .listen(
              (_) {},
              onError: (Object error, StackTrace stackTrace) {
                errors.add(error);
                traces.add(stackTrace);
              },
              onDone: done.complete,
            );
        final trace = StackTrace.current;

        source
          ..add([1])
          ..addError(StateError('cut'), trace)
          ..addError(StateError('again'))
          ..add([2]);
        unawaited(source.close());
        await done.future;

        expect(errors, hasLength(2));
        expect(traces.first, same(trace));
        expect(recorder.outcomes, ['error']);
        expect(recorder.error, same(errors.first));
        expect(recorder.stackTrace, same(trace));
        expect(recorder.captured, [1]);
        expect(recorder.received, 1);
      },
    );

    test('reach a handler that takes the error alone', () async {
      final errors = <Object>[];
      final done = Completer<void>();

      recorder
          .wrap(Stream<List<int>>.error(StateError('cut')))
          .listen(null, onError: errors.add, onDone: done.complete);
      await done.future;

      expect(errors, [isA<StateError>()]);
    });

    test('with cancelOnError, end the subscription at the first', () async {
      var sourceCancelled = false;
      final source = StreamController<List<int>>(
        onCancel: () => sourceCancelled = true,
      );
      addTearDown(() => unawaited(source.close()));
      recorder
          .wrap(source.stream)
          .listen(
            (_) {},
            onError: (Object _) {},
            onDone: () => fail('a cancelled subscription is not done'),
            cancelOnError: true,
          );

      source.addError(StateError('cut'));
      await pumpEventQueue();

      expect(sourceCancelled, isTrue);
      expect(recorder.outcomes, ['error']);
    });

    test('without a handler, go to the zone the listener was in', () async {
      final caught = <Object>[];
      final done = Completer<void>();

      runZonedGuarded(
        () => recorder
            .wrap(Stream<List<int>>.error(StateError('cut')))
            .listen(null, onDone: done.complete),
        (error, _) => caught.add(error),
      );
      await done.future;

      expect(caught, [isA<StateError>()]);
      expect(recorder.outcomes, ['error']);
    });
  });

  group('asFuture', () {
    test('completes with the value when the body ends', () async {
      final value = await recorder
          .wrap(Stream.value([1]))
          .listen(null)
          .asFuture<int>(7);

      expect(value, 7);
      expect(recorder.outcomes, ['done']);
    });

    test('fails with the first error', () async {
      await expectLater(
        recorder
            .wrap(Stream<List<int>>.error(StateError('cut')))
            .listen(null)
            .asFuture<void>(),
        throwsStateError,
      );

      expect(recorder.outcomes, ['error']);
    });
  });

  test('settles once, whatever happens after', () async {
    final subscription = recorder.wrap(Stream.value([1])).listen(null);

    await subscription.asFuture<void>();
    await subscription.cancel();

    expect(recorder.outcomes, ['done']);
  });
}
