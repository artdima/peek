# Changelog

## Unreleased

The first release — numbered with the rest of Peek, which moves as one.

- The protocol between an app and a desktop viewer: `PeekRemoteFrame` and
  its frames (`hello`, `welcome`, `denied`, `entry`, `cleared`, `synced`,
  `dropped`, `bodyRequest`, `bodyResponse`, `ping`, `pong`), written and
  read by `PeekRemoteCodec` with the same leniency as a `.peek` file.
  `PeekRemoteProtocol.check` decides whether a desktop welcomes an app.
  `doc/spec/remote-protocol.md` describes it all.
