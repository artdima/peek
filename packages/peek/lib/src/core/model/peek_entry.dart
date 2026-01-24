import 'package:meta/meta.dart';

import 'peek_failure.dart';
import 'peek_id.dart';
import 'peek_request.dart';
import 'peek_response.dart';
import 'peek_status_class.dart';
import 'peek_timings.dart';

/// Where a call is in its life.
enum PeekEntryState {
  /// Sent, nothing back yet.
  pending,

  /// A response arrived.
  completed,

  /// The call failed; a response may still be attached.
  failed,
}

/// One network call as Peek shows it: the request, whatever came back, and
/// when it all happened.
@immutable
final class PeekEntry {
  /// Creates an entry. [completedAt] must be set exactly when a [response]
  /// or [failure] is.
  const PeekEntry({
    required this.id,
    required this.request,
    required this.startedAt,
    required this.source,
    this.response,
    this.failure,
    this.completedAt,
    this.isPinned = false,
    this.timings,
  }) : assert(
         (response == null && failure == null) == (completedAt == null),
         'completedAt goes together with a response or a failure',
       );

  /// Identifies the call across the events that built this entry.
  final PeekId id;

  /// What was sent.
  final PeekRequest request;

  /// What came back, if anything did.
  final PeekResponse? response;

  /// What went wrong, if anything did.
  final PeekFailure? failure;

  /// When the request went out.
  final DateTime startedAt;

  /// When the response or failure arrived; `null` while pending.
  final DateTime? completedAt;

  /// The adapter that reported the call, such as `dio`.
  final String source;

  /// Whether the user pinned the entry so it survives eviction.
  final bool isPinned;

  /// Phase timings, for adapters that know them.
  final PeekTimings? timings;

  /// Where the call is in its life, derived from what is attached.
  PeekEntryState get state {
    if (failure != null) return PeekEntryState.failed;
    if (response != null) return PeekEntryState.completed;
    return PeekEntryState.pending;
  }

  /// Time from start to completion; `null` while pending, never negative.
  Duration? get duration {
    final end = completedAt;
    if (end == null) return null;
    final elapsed = end.difference(startedAt);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }

  /// Whether the call failed or the server answered with 4xx or 5xx.
  bool get isError => failure != null || (statusClass?.isError ?? false);

  /// The response status code, when there is a response.
  int? get statusCode => response?.statusCode;

  /// The class of [statusCode], when there is a response.
  PeekStatusClass? get statusClass => response?.statusClass;

  /// Request body size, when known.
  int? get requestSize => request.contentLength;

  /// Response body size, when known.
  int? get responseSize => response?.contentLength;

  /// Request and response sizes added up; `null` when neither is known.
  int? get totalSize {
    final sizes = [requestSize, responseSize].nonNulls;
    return sizes.isEmpty ? null : sizes.fold<int>(0, (sum, size) => sum + size);
  }

  /// The entry once [response] has arrived at [at].
  PeekEntry complete(PeekResponse response, {required DateTime at}) =>
      PeekEntry(
        id: id,
        request: request,
        startedAt: startedAt,
        source: source,
        response: response,
        completedAt: at,
        isPinned: isPinned,
        timings: timings,
      );

  /// The entry once it failed with [failure] at [at]; [response] is the
  /// server answer when the failure came with one.
  PeekEntry fail(
    PeekFailure failure, {
    required DateTime at,
    PeekResponse? response,
  }) => PeekEntry(
    id: id,
    request: request,
    startedAt: startedAt,
    source: source,
    response: response,
    failure: failure,
    completedAt: at,
    isPinned: isPinned,
    timings: timings,
  );

  /// A copy with the given fields replaced. Use [complete] and [fail] to
  /// move between states.
  PeekEntry copyWith({
    PeekRequest? request,
    PeekResponse? response,
    PeekFailure? failure,
    String? source,
    bool? isPinned,
    PeekTimings? timings,
  }) => PeekEntry(
    id: id,
    request: request ?? this.request,
    startedAt: startedAt,
    source: source ?? this.source,
    response: response ?? this.response,
    failure: failure ?? this.failure,
    completedAt: completedAt,
    isPinned: isPinned ?? this.isPinned,
    timings: timings ?? this.timings,
  );

  @override
  bool operator ==(Object other) =>
      other is PeekEntry &&
      other.id == id &&
      other.request == request &&
      other.response == response &&
      other.failure == failure &&
      other.startedAt == startedAt &&
      other.completedAt == completedAt &&
      other.source == source &&
      other.isPinned == isPinned &&
      other.timings == timings;

  @override
  int get hashCode => Object.hash(
    id,
    request,
    response,
    failure,
    startedAt,
    completedAt,
    source,
    isPinned,
    timings,
  );

  @override
  String toString() {
    final outcome = switch (state) {
      PeekEntryState.pending => 'pending',
      PeekEntryState.completed => '$statusCode',
      PeekEntryState.failed => 'failed: ${failure?.kind.name}',
    };
    return 'PeekEntry($id ${request.method} ${request.host}${request.path} '
        '$outcome)';
  }
}
