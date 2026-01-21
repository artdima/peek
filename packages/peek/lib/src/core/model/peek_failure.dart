import 'package:meta/meta.dart';

/// Why a network call failed.
enum PeekFailureKind {
  /// Connecting, sending or receiving took too long.
  timeout,

  /// The connection could not be made or dropped.
  connection,

  /// The server certificate was rejected.
  badCertificate,

  /// The call was cancelled by the app.
  cancelled,

  /// A response arrived, but with a status the client treats as an error.
  badResponse,

  /// Anything else.
  unknown,
}

/// What went wrong with a network call.
@immutable
final class PeekFailure {
  /// Creates a failure. [details] is usually the original error object.
  const PeekFailure({
    required this.kind,
    required this.message,
    this.details,
    this.stackTrace,
  });

  /// The category of the failure.
  final PeekFailureKind kind;

  /// A human-readable description.
  final String message;

  /// The original error, when the adapter had one.
  final Object? details;

  /// Where the failure was raised, when known.
  final StackTrace? stackTrace;

  /// A copy with the given fields replaced.
  PeekFailure copyWith({
    PeekFailureKind? kind,
    String? message,
    Object? details,
    StackTrace? stackTrace,
  }) => PeekFailure(
    kind: kind ?? this.kind,
    message: message ?? this.message,
    details: details ?? this.details,
    stackTrace: stackTrace ?? this.stackTrace,
  );

  /// Stack traces compare by identity: two traces are never equal by value.
  @override
  bool operator ==(Object other) =>
      other is PeekFailure &&
      other.kind == kind &&
      other.message == message &&
      other.details == details &&
      identical(other.stackTrace, stackTrace);

  @override
  int get hashCode =>
      Object.hash(kind, message, details, identityHashCode(stackTrace));

  @override
  String toString() => 'PeekFailure(${kind.name}: $message)';
}
