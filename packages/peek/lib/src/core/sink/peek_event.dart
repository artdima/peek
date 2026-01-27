import 'package:meta/meta.dart';

import '../model/peek_entry.dart';
import '../model/peek_failure.dart';
import '../model/peek_id.dart';
import '../model/peek_request.dart';
import '../model/peek_response.dart';
import '../model/peek_timings.dart';

/// Something an adapter observed about a network call.
///
/// The events of one call share an [id] the adapter drew from
/// [PeekId.generate]; [timestamp] is when the adapter saw the event.
@immutable
sealed class PeekEvent {
  const PeekEvent({required this.id, required this.timestamp});

  /// Identifies the call this event belongs to.
  final PeekId id;

  /// When the event happened, by the adapter's clock.
  final DateTime timestamp;
}

/// A request went out.
final class PeekRequestStarted extends PeekEvent {
  /// Creates the event; [source] names the adapter, such as `dio`.
  const PeekRequestStarted({
    required super.id,
    required super.timestamp,
    required this.request,
    required this.source,
  });

  /// What was sent.
  final PeekRequest request;

  /// The adapter that saw the call.
  final String source;

  @override
  bool operator ==(Object other) =>
      other is PeekRequestStarted &&
      other.id == id &&
      other.timestamp == timestamp &&
      other.request == request &&
      other.source == source;

  @override
  int get hashCode => Object.hash(id, timestamp, request, source);

  @override
  String toString() => 'PeekRequestStarted($id ${request.method})';
}

/// A response came back for a call that started earlier.
final class PeekResponseReceived extends PeekEvent {
  /// Creates the event; [timings] only when the adapter knows the phases.
  const PeekResponseReceived({
    required super.id,
    required super.timestamp,
    required this.response,
    this.timings,
  });

  /// What came back.
  final PeekResponse response;

  /// Phase timings, when known.
  final PeekTimings? timings;

  @override
  bool operator ==(Object other) =>
      other is PeekResponseReceived &&
      other.id == id &&
      other.timestamp == timestamp &&
      other.response == response &&
      other.timings == timings;

  @override
  int get hashCode => Object.hash(id, timestamp, response, timings);

  @override
  String toString() => 'PeekResponseReceived($id ${response.statusCode})';
}

/// A call that started earlier failed.
final class PeekRequestFailed extends PeekEvent {
  /// Creates the event; [response] is the server answer when the failure
  /// came with one, as with a status the client rejects.
  const PeekRequestFailed({
    required super.id,
    required super.timestamp,
    required this.failure,
    this.response,
    this.timings,
  });

  /// What went wrong.
  final PeekFailure failure;

  /// The response that accompanied the failure, if any.
  final PeekResponse? response;

  /// Phase timings, when known.
  final PeekTimings? timings;

  @override
  bool operator ==(Object other) =>
      other is PeekRequestFailed &&
      other.id == id &&
      other.timestamp == timestamp &&
      other.failure == failure &&
      other.response == response &&
      other.timings == timings;

  @override
  int get hashCode => Object.hash(id, timestamp, failure, response, timings);

  @override
  String toString() => 'PeekRequestFailed($id ${failure.kind.name})';
}

/// A whole call, reported at once by a source that only learns about calls
/// after they end — a log history, say.
final class PeekEntryRecorded extends PeekEvent {
  /// Creates the event from [entry], whose id and start time it takes.
  PeekEntryRecorded(this.entry)
    : super(id: entry.id, timestamp: entry.startedAt);

  /// The call, complete or not.
  final PeekEntry entry;

  @override
  bool operator ==(Object other) =>
      other is PeekEntryRecorded && other.entry == entry;

  @override
  int get hashCode => entry.hashCode;

  @override
  String toString() => 'PeekEntryRecorded($entry)';
}
