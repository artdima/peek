import 'transport_unsupported.dart'
    if (dart.library.io) '../io/web_socket_transport.dart';

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

  /// Opens a connection to [uri], or throws.
  Future<PeekRemoteConnection> connect(Uri uri);
}
