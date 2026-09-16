import 'dart:async';
import 'dart:typed_data';

/// Called when a body ends: the bytes kept and the count of all that passed.
typedef CaptureEnd = void Function(Uint8List captured, int received);

/// Called when a body fails: the error, and what had passed until then.
typedef CaptureFailure =
    void Function(
      Object error,
      StackTrace stackTrace,
      Uint8List captured,
      int received,
    );

/// A body stream that hands every chunk on as it came and keeps the first
/// [limit] bytes on the way.
///
/// Pausing, resuming and cancelling reach the source subscription directly,
/// so the listener sets the pace, not this stream. Exactly one of [onDone],
/// [onError] and [onCancel] is called, once; none of them may throw.
final class CapturingStream extends Stream<List<int>> {
  /// Wraps [source], keeping at most [limit] bytes.
  CapturingStream(
    this._source, {
    required this.limit,
    required this.onDone,
    required this.onError,
    required this.onCancel,
  }) : assert(limit >= 0, 'limit must not be negative');

  final Stream<List<int>> _source;

  /// The most bytes kept.
  final int limit;

  /// The body arrived whole.
  final CaptureEnd onDone;

  /// The body failed: the first error the source sent.
  final CaptureFailure onError;

  /// The listener walked away before the end.
  final CaptureEnd onCancel;

  @override
  bool get isBroadcast => _source.isBroadcast;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final subscription = _CapturingSubscription(this, Zone.current)
      ..onData(onData)
      ..onError(onError)
      ..onDone(onDone);
    subscription._source = _source.listen(
      subscription._data,
      onError: subscription._error,
      onDone: subscription._done,
      cancelOnError: cancelOnError,
    );
    return subscription;
  }
}

final class _CapturingSubscription implements StreamSubscription<List<int>> {
  _CapturingSubscription(this._stream, this._zone);

  final CapturingStream _stream;
  final Zone _zone;
  final BytesBuilder _captured = BytesBuilder();
  late final StreamSubscription<List<int>> _source;
  var _received = 0;
  var _settled = false;

  void Function(List<int> event)? _onData;
  Function? _onError;
  void Function()? _onDone;

  void _data(List<int> chunk) {
    final room = _stream.limit - _captured.length;
    if (!_settled && room > 0) {
      _captured.add(chunk.length <= room ? chunk : chunk.sublist(0, room));
    }
    _received += chunk.length;
    _onData?.call(chunk);
  }

  void _error(Object error, StackTrace stackTrace) {
    if (!_settled) {
      _settled = true;
      _stream.onError(error, stackTrace, _captured.toBytes(), _received);
    }
    final handler = _onError;
    if (handler is void Function(Object, StackTrace)) {
      handler(error, stackTrace);
    } else if (handler is void Function(Object)) {
      handler(error);
    } else {
      _zone.handleUncaughtError(error, stackTrace);
    }
  }

  void _done() {
    if (!_settled) {
      _settled = true;
      _stream.onDone(_captured.toBytes(), _received);
    }
    _onDone?.call();
  }

  @override
  void onData(void Function(List<int> data)? handleData) =>
      _onData = handleData;

  @override
  void onError(Function? handleError) {
    if (handleError != null &&
        handleError is! void Function(Object, StackTrace) &&
        handleError is! void Function(Object)) {
      throw ArgumentError.value(
        handleError,
        'handleError',
        'must take an error, or an error and a stack trace',
      );
    }
    _onError = handleError;
  }

  @override
  void onDone(void Function()? handleDone) => _onDone = handleDone;

  @override
  void pause([Future<void>? resumeSignal]) => _source.pause(resumeSignal);

  @override
  void resume() => _source.resume();

  @override
  bool get isPaused => _source.isPaused;

  @override
  Future<void> cancel() {
    if (!_settled) {
      _settled = true;
      _stream.onCancel(_captured.toBytes(), _received);
    }
    return _source.cancel();
  }

  @override
  Future<E> asFuture<E>([E? futureValue]) {
    final completer = Completer<E>();
    _onDone = () => completer.complete(futureValue as E);
    _onError = (Object error, StackTrace stackTrace) {
      unawaited(
        _source.cancel().whenComplete(
          () => completer.completeError(error, stackTrace),
        ),
      );
    };
    return completer.future;
  }
}
