import 'package:meta/meta.dart';

/// How the time of a call was spent, phase by phase, for adapters that know.
///
/// The phases follow the HAR `timings` object; any of them may be unknown.
@immutable
final class PeekTimings {
  /// Creates a timing breakdown.
  const PeekTimings({
    this.blocked,
    this.dns,
    this.connect,
    this.ssl,
    this.send,
    this.wait,
    this.receive,
  });

  /// Time spent waiting for a connection from the pool.
  final Duration? blocked;

  /// DNS resolution.
  final Duration? dns;

  /// Opening the TCP connection, TLS included when [ssl] is unknown.
  final Duration? connect;

  /// The TLS handshake.
  final Duration? ssl;

  /// Sending the request.
  final Duration? send;

  /// Waiting for the first byte of the response.
  final Duration? wait;

  /// Receiving the response.
  final Duration? receive;

  /// The phases as HAR-named pairs, unknown ones skipped.
  Map<String, Duration> get known => {
    for (final MapEntry(:key, :value) in _phases.entries)
      if (value != null) key: value,
  };

  Map<String, Duration?> get _phases => {
    'blocked': blocked,
    'dns': dns,
    'connect': connect,
    'ssl': ssl,
    'send': send,
    'wait': wait,
    'receive': receive,
  };

  @override
  bool operator ==(Object other) =>
      other is PeekTimings &&
      other.blocked == blocked &&
      other.dns == dns &&
      other.connect == connect &&
      other.ssl == ssl &&
      other.send == send &&
      other.wait == wait &&
      other.receive == receive;

  @override
  int get hashCode =>
      Object.hash(blocked, dns, connect, ssl, send, wait, receive);

  @override
  String toString() => 'PeekTimings(${known.keys.join(', ')})';
}
