# Changelog

## Unreleased

The first release — numbered with the rest of Peek, which moves as one.

- The protocol between an app and a desktop viewer: `PeekRemoteFrame` and
  its frames (`hello`, `welcome`, `denied`, `entry`, `cleared`, `synced`,
  `dropped`, `bodyRequest`, `bodyResponse`, `ping`, `pong`), written and
  read by `PeekRemoteCodec` with the same leniency as a `.peek` file.
  `PeekRemoteProtocol.check` decides whether a desktop welcomes an app.
  `doc/spec/remote-protocol.md` describes it all.
- `PeekRemote` streams a `Peek` store to a desktop: a hello with the token,
  the history after the welcome, then every change. Recording never waits
  for the network — changes are queued (`maxQueued`) and the oldest thrown
  away, with a `dropped` frame, when the desktop cannot keep up. Bodies over
  `inlineBodyBytes` stay in the app until the desktop asks for one. A lost
  connection is tried again after a growing, jittered pause; a refusal stops
  it and reaches `PeekOptions.onError`. `PeekRemoteEndpoint` says where the
  desktop listens; `PeekRemoteTransport` is the WebSocket underneath, on
  every platform with `dart:io`.
