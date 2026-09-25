# peek_remote

Streams the calls [Peek](https://pub.dev/packages/peek) records in an app to
a desktop viewer — [Peek Pro](https://github.com/artdima/peek) — over a
WebSocket on the local network.

> Work in progress: this release holds the protocol. The client that streams
> a store follows.

The app connects to the desktop, introduces itself with the token the
desktop shows, and sends what its store holds and then every change. Bodies
stay on the device until the desktop asks for one, so a large download costs
nothing until someone wants to read it.

## The protocol

[`doc/spec/remote-protocol.md`](https://github.com/artdima/peek/blob/main/doc/spec/remote-protocol.md)
describes every frame, for anyone building the other end. The frames are
also a Dart API:

```dart
const codec = PeekRemoteCodec();
final text = codec.encode(const PeekRemotePing());
final frame = codec.decode(text); // PeekRemotePing
```

## License

MIT — see [LICENSE](LICENSE).
