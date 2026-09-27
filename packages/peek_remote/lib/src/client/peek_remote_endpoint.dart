import 'package:meta/meta.dart';

import '../protocol/peek_remote_frame.dart';

/// Where the desktop listens.
@immutable
final class PeekRemoteEndpoint {
  /// The desktop at [host] on [port].
  ///
  /// An Android emulator reaches the machine it runs on as `10.0.2.2`; an
  /// Android device on a cable can use `adb reverse tcp:9741 tcp:9741` and
  /// `localhost`. An iPhone connects over Wi-Fi, cable or not.
  const PeekRemoteEndpoint(
    this.host, {
    this.port = PeekRemoteProtocol.defaultPort,
  });

  /// Reads `host` or `host:port`, the way the desktop shows its address.
  factory PeekRemoteEndpoint.parse(String address) {
    final text = address.trim();
    final colon = text.lastIndexOf(':');
    if (colon <= 0 || text.startsWith('[')) return PeekRemoteEndpoint(text);
    final port = int.tryParse(text.substring(colon + 1));
    if (port == null || port <= 0 || port > 65535) {
      throw FormatException('"$address" is not host:port');
    }
    return PeekRemoteEndpoint(text.substring(0, colon), port: port);
  }

  /// The desktop's name or address.
  final String host;

  /// Its port.
  final int port;

  /// The WebSocket address to connect to.
  Uri get uri => Uri(scheme: 'ws', host: host, port: port, path: '/');

  @override
  bool operator ==(Object other) =>
      other is PeekRemoteEndpoint && other.host == host && other.port == port;

  @override
  int get hashCode => Object.hash(host, port);

  @override
  String toString() => '$host:$port';
}
