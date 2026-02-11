import 'limits/peek_body_truncator.dart';
import 'peek_options.dart';
import 'redaction/peek_redactor.dart';
import 'sink/peek_adapter.dart';
import 'sink/peek_event.dart';
import 'sink/peek_sink.dart';
import 'store/in_memory_peek_store.dart';
import 'store/peek_event_reducer.dart';
import 'store/peek_store.dart';

/// An event the reducer refused, handed to [PeekOptions.onError].
final class PeekDroppedEventException implements Exception {
  /// Creates the exception.
  const PeekDroppedEventException(this.event, this.reason);

  /// The event that was dropped.
  final PeekEvent event;

  /// Why it was dropped.
  final PeekReduction reason;

  @override
  String toString() => 'PeekDroppedEventException(${reason.name}: $event)';
}

/// The heart of Peek: the sink adapters report into and the store the UI
/// reads from, with redaction and size limits applied in between.
///
/// ```dart
/// final peek = Peek(options: const PeekOptions(enabled: kDebugMode));
/// dio.interceptors.add(PeekDioInterceptor(peek));
/// ```
///
/// [report] never throws: whatever goes wrong inside Peek reaches
/// [PeekOptions.onError] instead of the app. One instance per app is the
/// norm; [Peek.instance] provides a lazily created default for the one-line
/// setup.
final class Peek implements PeekSink {
  /// Creates an instance. Peek owns [store] — its own in-memory one by
  /// default — and disposes it with itself.
  Peek({this.options = const PeekOptions(), PeekStore? store})
    : store = store ?? InMemoryPeekStore(maxEntries: options.limits.maxEntries),
      _redactor = PeekRedactor(options.redaction),
      _truncator = PeekBodyTruncator(options.limits.maxBodyBytes);

  static Peek? _instance;

  /// The default instance, created on first use with default options.
  /// Assign one with custom options before anything reads it.
  static Peek get instance => _instance ??= Peek();

  static set instance(Peek peek) => _instance = peek;

  /// How this instance behaves.
  final PeekOptions options;

  /// Where entries live.
  final PeekStore store;

  final PeekRedactor _redactor;
  final PeekBodyTruncator _truncator;
  final PeekEventReducer _reducer = const PeekEventReducer();
  final List<PeekAdapter> _adapters = [];
  bool _paused = false;
  bool _disposed = false;

  /// Whether events are recorded at all; see [PeekOptions.enabled].
  bool get isEnabled => options.enabled;

  /// Whether recording is paused; events arriving meanwhile are dropped.
  bool get isPaused => _paused;

  /// Whether [dispose] has run.
  bool get isDisposed => _disposed;

  /// Adapters attached with [attach], in order.
  List<PeekAdapter> get adapters => List.unmodifiable(_adapters);

  /// Stops recording until [resume].
  void pause() => _paused = true;

  /// Resumes recording after [pause].
  void resume() => _paused = false;

  /// Registers [adapter] so it shows up in [adapters] and is disposed with
  /// this instance. Returns it, for chaining.
  T attach<T extends PeekAdapter>(T adapter) {
    _adapters.add(adapter);
    return adapter;
  }

  /// Disposes [adapter] and forgets it.
  void detach(PeekAdapter adapter) {
    if (_adapters.remove(adapter)) _guard(adapter.dispose);
  }

  /// Removes every entry.
  void clear() {
    if (_disposed) return;
    _guard(store.clear);
  }

  @override
  void report(PeekEvent event) {
    if (!isEnabled || _paused || _disposed) return;
    _guard(() {
      final reduction = _reducer.apply(store, _sanitize(event));
      if (reduction != PeekReduction.applied) {
        _fail(PeekDroppedEventException(event, reduction), StackTrace.empty);
      }
    });
  }

  @override
  void reportAdapterError(Object error, StackTrace stackTrace) =>
      _fail(error, stackTrace);

  /// Disposes the adapters and the store. Safe to call twice; afterwards
  /// events are ignored and, if this was [instance], a fresh one is created
  /// on next use.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final adapter in _adapters) {
      _guard(adapter.dispose);
    }
    _adapters.clear();
    _guard(store.dispose);
    if (identical(_instance, this)) _instance = null;
  }

  PeekEvent _sanitize(PeekEvent event) => switch (event) {
    PeekRequestStarted() => PeekRequestStarted(
      id: event.id,
      timestamp: event.timestamp,
      request: _truncator.truncateRequest(
        _redactor.redactRequest(event.request),
      ),
      source: event.source,
    ),
    PeekResponseReceived() => PeekResponseReceived(
      id: event.id,
      timestamp: event.timestamp,
      response: _truncator.truncateResponse(
        _redactor.redactResponse(event.response),
      ),
      timings: event.timings,
    ),
    PeekRequestFailed(:final response) => PeekRequestFailed(
      id: event.id,
      timestamp: event.timestamp,
      failure: event.failure,
      response:
          response == null
              ? null
              : _truncator.truncateResponse(_redactor.redactResponse(response)),
      timings: event.timings,
    ),
    PeekEntryRecorded() => PeekEntryRecorded(
      _truncator.truncateEntry(_redactor.redactEntry(event.entry)),
    ),
  };

  void _guard(void Function() action) {
    try {
      action();
    } catch (error, stackTrace) {
      _fail(error, stackTrace);
    }
  }

  void _fail(Object error, StackTrace stackTrace) {
    final onError = options.onError;
    if (onError == null) return;
    try {
      onError(error, stackTrace);
    } catch (_) {
      // A failing error handler has nowhere left to report to.
    }
  }
}
