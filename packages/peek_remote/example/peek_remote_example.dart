// The frames an app and a desktop exchange, written and read back. The
// client that streams a store over a WebSocket arrives in the next release;
// this shows the protocol it speaks.

import 'package:peek/core.dart';
import 'package:peek_remote/peek_remote.dart';

/// Introduces an app, checks it the way a desktop would, and prints both.
void main() {
  const codec = PeekRemoteCodec();
  final hello = PeekRemoteHello(
    sessionId: 'example-session',
    token: 'k7Qx2mP9',
    session: PeekSessionHeader.current(
      startedAt: DateTime.now(),
      name: 'Example',
    ),
  );

  final text = codec.encode(hello);
  final received = codec.decode(text) as PeekRemoteHello;
  final refusal = PeekRemoteProtocol.check(received, token: 'k7Qx2mP9');

  // ignore: avoid_print
  print(text);
  // ignore: avoid_print
  print(refusal ?? codec.encode(const PeekRemoteWelcome()));
}
