// Streams what Peek records to Peek Pro on a Mac. Nothing about the Mac has
// to be in code: start the client in a debug build, and a person pairs once
// from Peek's menu — Connect to Peek Pro — with the code Peek Pro shows. The
// full app, menu and all, is under `packages/peek/example`.

import 'package:peek/core.dart';
import 'package:peek_remote/peek_remote.dart';

/// What an app adds where Peek is set up, behind `kDebugMode`.
PeekRemote startRemote(Peek peek) =>
    peek.attach(PeekRemote(peek, name: 'Example'))..start();

/// For a test run or a CI job, where nobody is there to type a code: the
/// address and the long token Peek Pro shows in its settings.
PeekRemote startRemoteWithToken(Peek peek, String address, String token) =>
    peek.attach(
      PeekRemote(
        peek,
        endpoint: PeekRemoteEndpoint.parse(address),
        token: token,
      ),
    )..start();

/// The frames the client and the desktop exchange are a Dart API as well.
void main() {
  const codec = PeekRemoteCodec();
  final hello = PeekRemoteHello(
    sessionId: 'example-session',
    code: '4719',
    session: PeekSessionHeader.current(
      startedAt: DateTime.now(),
      name: 'Example',
    ),
  );
  final received = codec.decode(codec.encode(hello)) as PeekRemoteHello;

  // ignore: avoid_print
  print('${received.session.name} pairs with code ${received.code}');
}
