/// Streams the calls Peek records in an app to a desktop viewer.
///
/// The app is the client and the desktop — Peek Pro — the server: the app
/// connects, introduces itself with a token the desktop shows, and sends
/// what its store holds and then every change. Bodies stay on the device
/// until the desktop asks for one. `doc/spec/remote-protocol.md` describes
/// the protocol for anyone building the other end.
///
/// It imports `package:peek/core.dart` rather than `package:peek/peek.dart`,
/// so it never drags the user interface in with it. `dart:io` is kept to one
/// directory reached only through a conditional import. Its one plugin is
/// `shared_preferences`, which remembers the desktop between runs.
library;

export 'src/client/peek_remote.dart';
export 'src/client/peek_remote_endpoint.dart';
export 'src/client/peek_remote_memory.dart';
export 'src/protocol/peek_remote_codec.dart';
export 'src/protocol/peek_remote_frame.dart';
export 'src/transport/peek_remote_transport.dart';
