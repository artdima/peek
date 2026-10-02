import 'package:peek/core.dart';

import 'transport_unsupported.dart'
    if (dart.library.io) '../io/web_socket_transport.dart';

/// Connecting failed, and why, in terms a person can act on.
final class PeekRemoteConnectException implements Exception {
  /// Creates the exception for [failure], caused by [cause].
  const PeekRemoteConnectException(this.failure, [this.cause]);

  /// Why the desktop could not be reached.
  final PeekDesktopFailure failure;

  /// What the platform threw.
  final Object? cause;

  @override
  String toString() => 'PeekRemoteConnectException(${failure.name}: $cause)';
}

/// A connection that carries text messages both ways.
abstract interface class PeekRemoteConnection {
  /// The messages that arrive, until the connection closes.
  Stream<String> get messages;

  /// Sends [message]; never waits for the network.
  void send(String message);

  /// Closes the connection. Safe to call twice.
  Future<void> close();
}

/// Opens connections to a desktop.
///
/// The WebSocket transport is the one to use; a test hands in its own.
abstract interface class PeekRemoteTransport {
  /// The platform's WebSocket, where there is one; on the web connecting
  /// fails with an [UnsupportedError] for now.
  factory PeekRemoteTransport.webSocket({
    Duration timeout = const Duration(seconds: 5),
  }) => platformTransport(timeout);

  /// Opens a connection to [uri], or throws — a
  /// [PeekRemoteConnectException] when the reason is known.
  Future<PeekRemoteConnection> connect(Uri uri);
}
