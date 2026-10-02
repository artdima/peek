import 'dart:async';
import 'dart:io';

import 'package:meta/meta.dart';
import 'package:peek/core.dart';

import '../transport/peek_remote_transport.dart';

/// The transport where there is `dart:io`: a plain WebSocket.
PeekRemoteTransport platformTransport(Duration timeout) =>
    _WebSocketTransport(timeout);

final class _WebSocketTransport implements PeekRemoteTransport {
  const _WebSocketTransport(this._timeout);

  final Duration _timeout;

  @override
  Future<PeekRemoteConnection> connect(Uri uri) async {
    try {
      // The connection owns the socket and closes it.
      // ignore: close_sinks
      final socket = await WebSocket.connect(uri.toString()).timeout(_timeout);
      return _WebSocketConnection(socket);
    } on TimeoutException catch (error) {
      throw PeekRemoteConnectException(PeekDesktopFailure.timedOut, error);
    } on SocketException catch (error) {
      throw PeekRemoteConnectException(peekRemoteFailureOf(error), error);
    }
  }
}

/// What a socket error means for a person: the operating systems word it
/// differently and number it differently, so both are read.
@internal
PeekDesktopFailure peekRemoteFailureOf(SocketException error) {
  final text = '${error.message} ${error.osError?.message ?? ''}'.toLowerCase();
  final code = error.osError?.errorCode;
  if (text.contains('host lookup') ||
      text.contains('nodename nor servname') ||
      text.contains('no address associated')) {
    return PeekDesktopFailure.notFound;
  }
  // ECONNREFUSED on Darwin, Linux and Android, Windows.
  if (text.contains('refused') || const {61, 111, 10061}.contains(code)) {
    return PeekDesktopFailure.refused;
  }
  // ETIMEDOUT, ENETUNREACH and EHOSTUNREACH: nothing on the way answers.
  if (text.contains('timed out') ||
      text.contains('unreachable') ||
      text.contains('no route') ||
      const {60, 51, 65, 110, 101, 113, 10060, 10051, 10065}.contains(code)) {
    return PeekDesktopFailure.timedOut;
  }
  return PeekDesktopFailure.other;
}

final class _WebSocketConnection implements PeekRemoteConnection {
  _WebSocketConnection(this._socket);

  final WebSocket _socket;

  // The protocol sends text; a binary message is ignored, as it says.
  @override
  late final Stream<String> messages = _socket
      .where((message) => message is String)
      .cast<String>();

  @override
  void send(String message) {
    if (_socket.readyState == WebSocket.open) _socket.add(message);
  }

  @override
  Future<void> close() => _socket.close();
}
