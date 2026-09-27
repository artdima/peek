# peek_remote

Streams the calls [Peek](https://pub.dev/packages/peek) records in an app to
a desktop viewer — [Peek Pro](https://github.com/artdima/peek) — over a
WebSocket on the local network.

The app connects to the desktop, introduces itself with the token the
desktop shows, and sends what its store holds and then every change. Bodies
stay on the device until the desktop asks for one, so a large download costs
nothing until someone wants to read it.

## Install

```yaml
dependencies:
  peek: ^2.0.0
  peek_remote: ^2.0.0
```

## Use

Start the desktop viewer; it shows its address and a token. Then, in the app:

```dart
final remote = peek.attach(
  PeekRemote(
    peek,
    endpoint: PeekRemoteEndpoint.parse('192.168.1.20:9741'),
    token: 'k7Qx2mP9',
  ),
)..start();
```

`peek.attach` disposes the client together with Peek. Pass `name:` to say
what the desktop should call the app; `PeekOptions.name` is used otherwise.

A person at the phone can pair with the short code the desktop shows
instead of a token written in code — and then nothing needs to be in code
at all:

```dart
final remote = peek.attach(PeekRemote(peek)..start());
// Once, when the person types the code the desktop shows:
await remote.connect(PeekRemoteEndpoint.parse('192.168.1.20:9741'), code: '4719');
```

A right code is answered with a device token, which the client sends from
then on, and the desktop is remembered (`shared_preferences`): the next
`start()` goes straight back to it. `remote.forget()` drops it; a desktop
that has forgotten the device turns it away, and the app asks for a code
again. `remote.state` is `unpaired` while there is nothing to connect to.

- **Where the desktop is.** A phone on the same Wi-Fi uses the address the
  desktop shows. An Android emulator reaches the machine it runs on as
  `10.0.2.2`; a device on a cable can run `adb reverse tcp:9741 tcp:9741` and
  use `localhost`. The iOS simulator shares the Mac's network: `localhost`.
- **It never slows the app down.** A change is queued and sent on the next
  turn of the event loop. When the desktop cannot keep up, the oldest frames
  go and the desktop is told how many (`maxQueued`, 2000 by default).
- **Bodies stay on the device** when they are larger than `inlineBodyBytes`
  (4 KB by default); the desktop asks for one when someone opens it.
- **A lost desktop is tried again** after a pause that grows to `retryMax`,
  and the history is sent anew. A desktop that turns the app away — a wrong
  token, another protocol version — stops it for good; the reason reaches
  `PeekOptions.onError` and `remote.denial`.
- **Debug builds only.** The connection is plain `ws://` on a local network;
  start the client behind `kDebugMode`, as Peek itself usually is.

`remote.state` and `remote.stateChanges` say whether it is connected.

## Finding the desktop

Peek Pro announces itself over Bonjour as `_peek._tcp`, and
`remote.discover()` lists the desktops on the network as they come and go
(the "Connect to Peek Pro" sheet in Peek shows them). It browses through the
platform's own Bonjour, by way of [`bonsoir`](https://pub.dev/packages/bonsoir);
on iOS the app needs two keys in `Info.plist`:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Streams network calls to Peek Pro on this network.</string>
<key>NSBonjourServices</key>
<array>
  <string>_peek._tcp</string>
</array>
```

Office networks often block multicast; an address typed in always works.

## Without a desktop

`tool/peek_remote_dump.dart` in the repository listens the way the desktop
does and prints every frame, for trying the client out:

```sh
dart run tool/peek_remote_dump.dart --token k7Qx2mP9 --out session.jsonl
```

`--code 4719` makes it pair the way a desktop does.

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
