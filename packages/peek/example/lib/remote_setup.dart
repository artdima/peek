import 'dart:async';

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
/// `PEEK_REMOTE_CODE=4719` pairs with the code the desktop shows instead of
/// a token. Without `PEEK_REMOTE` the client goes back to the desktop it
/// paired with last, if any. Peek disposes the client with itself.
PeekRemote startRemote(Peek peek) {
  const address = String.fromEnvironment('PEEK_REMOTE');
  const token = String.fromEnvironment('PEEK_REMOTE_TOKEN');
  const code = String.fromEnvironment('PEEK_REMOTE_CODE');
  final remote = peek.attach(
    PeekRemote(peek, token: token.isEmpty ? null : token, name: 'Peek example'),
  );
  if (address.isEmpty) {
    remote.start();
  } else {
    unawaited(
      remote.connect(
        PeekRemoteEndpoint.parse(address),
        code: code.isEmpty ? null : code,
      ),
    );
  }
  return remote;
}
