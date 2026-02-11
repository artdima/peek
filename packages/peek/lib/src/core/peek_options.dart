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
    this.redaction = const PeekRedactionPolicy(),
    this.clock = const PeekSystemClock(),
    this.onError,
    this.enabled = true,
  });

  /// How much is kept.
  final PeekLimits limits;

  /// What is masked before it is kept.
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
