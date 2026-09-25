import 'package:peek/core.dart';
import 'package:peek_remote/peek_remote.dart';

/// Streams the example's calls to a desktop viewer, when the app was started
/// with its address:
///
/// ```sh
/// flutter run --dart-define=PEEK_REMOTE=192.168.1.20:9741 \
///   --dart-define=PEEK_REMOTE_TOKEN=k7Qx2mP9
/// ```
///
/// Without `PEEK_REMOTE` nothing is sent and this returns `null`. Peek
/// disposes the client with itself.
PeekRemote? startRemote(Peek peek) {
  const address = String.fromEnvironment('PEEK_REMOTE');
  if (address.isEmpty) return null;
  const token = String.fromEnvironment('PEEK_REMOTE_TOKEN');
  return peek.attach(
    PeekRemote(
      peek,
      endpoint: PeekRemoteEndpoint.parse(address),
      token: token.isEmpty ? null : token,
      name: 'Peek example',
    ),
  )..start();
}
