import 'package:peek/core.dart';
import 'package:talker/talker.dart';

/// What a mapper is given besides the log: the identity of the call it is
/// about, and the name the adapter reports under.
///
/// A logger tells the story of one call in several entries — it went out,
/// it came back — and Peek needs them under one id. A mapper marks the
/// object those entries share (Dio's `RequestOptions`, say) with [begin]
/// and finds it again with [find].
final class PeekTalkerContext {
  /// Creates a context for an adapter reporting under [source].
  PeekTalkerContext({required this.source});

  /// The name the adapter reports under, such as `talker/dio`.
  final String source;

  final Expando<PeekId> _ids = Expando<PeekId>('peek_talker');

  /// Starts a call on [key] and returns the id it will be reported under.
  PeekId begin(Object key) => _ids[key] = PeekId.generate();

  /// The id [key] was started under, or `null` when this adapter never saw
  /// it start — a log stream joined halfway, or a logger that only reports
  /// what already finished.
  PeekId? find(Object key) => _ids[key];
}

/// Turns one kind of log entry into one of Peek's events.
///
/// A logger carries whatever its integrations put in it: network calls,
/// navigation, an app's own messages. A mapper claims the entries it knows
/// and leaves the rest alone, so a new integration is a new mapper rather
/// than a change to the adapter.
abstract interface class PeekTalkerLogMapper {
  /// Whether this mapper knows what [data] is.
  bool canMap(TalkerData data);

  /// The event [data] stands for, or `null` when it stands for none —
  /// a log this mapper claims but has nothing to report about.
  PeekEvent? map(TalkerData data, PeekTalkerContext context);
}
