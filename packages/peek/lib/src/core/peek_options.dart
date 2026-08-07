import 'package:meta/meta.dart';

import 'limits/peek_limits.dart';
import 'peek_clock.dart';
import 'redaction/peek_redaction_policy.dart';

/// Receives errors Peek swallowed so the app never sees them: an adapter
/// that threw, an event the reducer dropped, a store that failed.
typedef PeekErrorHandler = void Function(Object error, StackTrace stackTrace);

/// How a `Peek` instance behaves.
@immutable
final class PeekOptions {
  /// Creates options; every default suits a debug build of a typical app.
  const PeekOptions({
    this.limits = const PeekLimits(),
    this.redaction = PeekRedactionPolicy.none,
    this.clock = const PeekSystemClock(),
    this.onError,
    this.enabled = true,
  });

  /// How much is kept.
  final PeekLimits limits;

  /// What is masked before it is kept; nothing, by default.
  ///
  /// A log that hides what was sent is a log that cannot be debugged, so
  /// Peek shows the call as it happened. Masking is one line away, and
  /// worth it wherever a log leaves the device — an exported HAR, a
  /// screenshot on an issue:
  ///
  /// ```dart
  /// Peek(options: const PeekOptions(redaction: PeekRedactionPolicy()));
  /// ```
  final PeekRedactionPolicy redaction;

  /// The clock Peek and its UI read the current time from.
  final PeekClock clock;

  /// Where swallowed errors go; `null` drops them.
  final PeekErrorHandler? onError;

  /// Whether Peek records anything at all. Pass `kDebugMode` to switch it
  /// off in release builds without touching the adapters.
  final bool enabled;

  /// A copy with the given fields replaced.
  PeekOptions copyWith({
    PeekLimits? limits,
    PeekRedactionPolicy? redaction,
    PeekClock? clock,
    PeekErrorHandler? onError,
    bool? enabled,
  }) => PeekOptions(
    limits: limits ?? this.limits,
    redaction: redaction ?? this.redaction,
    clock: clock ?? this.clock,
    onError: onError ?? this.onError,
    enabled: enabled ?? this.enabled,
  );

  @override
  String toString() => 'PeekOptions($limits, $redaction, enabled: $enabled)';
}
