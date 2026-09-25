import 'dart:async';
import 'dart:io';

import '../transport/peek_remote_transport.dart';

/// The transport where there is `dart:io`: a plain WebSocket.
PeekRemoteTransport platformTransport(Duration timeout) =>
    _WebSocketTransport(timeout);

final class _WebSocketTransport implements PeekRemoteTransport {
  const _WebSocketTransport(this._timeout);

  final Duration _timeout;

  @override
  Future<PeekRemoteConnection> connect(Uri uri) async {
    // The connection owns the socket and closes it.
    // ignore: close_sinks
    final socket = await WebSocket.connect(uri.toString()).timeout(_timeout);
    return _WebSocketConnection(socket);
  }
}

final class _WebSocketConnection implements PeekRemoteConnection {
  _WebSocketConnection(this._socket);

  final WebSocket _socket;

  // The protocol sends text; a binary message is ignored, as it says.
  @override
  late final Stream<String> messages =
      _socket.where((message) => message is String).cast<String>();

  @override
  void send(String message) {
    if (_socket.readyState == WebSocket.open) _socket.add(message);
  }

  @override
  Future<void> close() => _socket.close();
}
