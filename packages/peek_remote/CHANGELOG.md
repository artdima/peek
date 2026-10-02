# Changelog

## 2.0.0

The first release — numbered with the rest of Peek, which moves as one. It
streams what Peek records to [Peek Pro](https://github.com/artdima/peek-pro)
on a Mac;
[`doc/remote.md`](https://github.com/artdima/peek/blob/main/doc/remote.md)
is the guide.

- The protocol between an app and a desktop viewer: `PeekRemoteFrame` and
  its frames (`hello`, `welcome`, `denied`, `entry`, `cleared`, `synced`,
  `dropped`, `bodyRequest`, `bodyResponse`, `ping`, `pong`), written and
  read by `PeekRemoteCodec` with the same leniency as a `.peek` file.
  `PeekRemoteProtocol.check` decides whether a desktop welcomes an app.
  `doc/spec/remote-protocol.md` describes it all.
- `PeekRemote` streams a `Peek` store to a desktop: a hello, the history
  after the welcome, then every change. Recording never waits
  for the network — changes are queued (`maxQueued`) and the oldest thrown
  away, with a `dropped` frame, when the desktop cannot keep up. Bodies over
  `inlineBodyBytes` stay in the app until the desktop asks for one. A lost
  connection is tried again after a growing, jittered pause; a refusal stops
  it and reaches `PeekOptions.onError`. `PeekRemoteEndpoint` says where the
  desktop listens; `PeekRemoteTransport` is the WebSocket underneath, on
  every platform with `dart:io`.
- Pairing with a code. `peek.attach(PeekRemote(peek)..start())` needs
  nothing about the desktop in code: a person types the four digits the
  desktop shows, `connect(endpoint, code:)` sends them, and a right code is
  answered with a device token (`deviceToken`, from the desktop `serverId`)
  that is sent from then on. `PeekRemoteMemory` keeps the desktop and its
  token in `shared_preferences`, so the next `start()` goes straight back;
  `forget()` drops them; while there is nothing to connect to, the state
  is `unpaired`. A token written in code (`token:`) still works, for CI.
- Finding the desktop: `discover()` lists the desktops announcing
  `_peek._tcp` over Bonjour, through the platform's own Bonjour by way of
  `bonsoir` (`PeekRemoteDiscovery`, `PeekRemoteDiscovered`). An iOS app
  needs `NSLocalNetworkUsageDescription` and `NSBonjourServices`; an
  address typed in always works. A device token goes only to the desktop
  that issued it.
- `PeekRemote` implements Peek's `PeekDesktopLink`, which Connect to Peek
  Pro on Peek's screen drives: where the link stands, the desktops nearby,
  connect, disconnect, forget — and why a desktop could not be reached.
  The WebSocket transport throws `PeekRemoteConnectException` with the
  reason it read from the platform: no answer, refused, not found.
- `package:peek_remote/protocol.dart` holds the frames and the codec alone,
  pure Dart, for tools without Flutter. `tool/peek_remote_dump.dart` in the
  repository listens like a desktop and prints every frame; `--code` makes
  it pair.
- Needs Dart 3.11 and Flutter 3.41, for `bonsoir`. `shared_preferences` and
  `bonsoir` are the first plugins in the Peek family, and only here: `peek`
  itself still takes none.
