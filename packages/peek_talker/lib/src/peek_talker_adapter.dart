import 'dart:async';

import 'package:peek/core.dart';
import 'package:talker/talker.dart';

import 'peek_talker_log_mapper.dart';

/// Reports what Talker already logged to Peek.
///
/// ```dart
/// final peek = Peek();
/// peek.attach(PeekTalkerAdapter(peek, talker: talker));
/// ```
///
/// The adapter listens to `talker.stream` and hands every entry to the
/// first mapper that claims it. Nothing is logged twice: an app that
/// already reports its calls through Talker does not also need Peek's own
/// interceptor.
///
/// A mapper that raises hands the error to [PeekSink.reportAdapterError]
/// rather than back into Talker, which would log Peek's own failure as if
/// it were the app's.
final class PeekTalkerAdapter implements PeekAdapter {
  /// Creates an adapter reporting [talker]'s entries into [sink].
  ///
  /// [replayHistory] reports what Talker recorded before the adapter
  /// existed, oldest first: an app that opens Peek after a failure wants to
  /// see the failure.
  PeekTalkerAdapter(
    this.sink, {
    required this.talker,
    this.mappers = defaultMappers,
    bool replayHistory = true,
  }) : _context = PeekTalkerContext(source: source) {
    if (replayHistory) _replay();
    _subscription = talker.stream.listen(_onData);
  }

  /// The name this adapter reports itself under.
  static const String source = 'talker';

  /// The mappers an adapter uses when it is not told otherwise.
  static const List<PeekTalkerLogMapper> defaultMappers = [];

  /// Where the calls are reported.
  final PeekSink sink;

  /// The logger being watched.
  final Talker talker;

  /// The mappers, tried in order; the first to claim an entry maps it.
  final List<PeekTalkerLogMapper> mappers;

  final PeekTalkerContext _context;

  StreamSubscription<TalkerData>? _subscription;

  @override
  String get name => source;

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _subscription = null;
  }

  void _replay() {
    final history = [...talker.history]
      ..sort((a, b) => a.time.compareTo(b.time));
    history.forEach(_onData);
  }

  void _onData(TalkerData data) {
    try {
      for (final mapper in mappers) {
        if (!mapper.canMap(data)) continue;
        final event = mapper.map(data, _context);
        if (event != null) sink.report(event);
        return;
      }
    } on Object catch (error, stackTrace) {
      sink.reportAdapterError(error, stackTrace);
    }
  }
}
