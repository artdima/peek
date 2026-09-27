# peek_remote

Streams the calls [Peek](https://pub.dev/packages/peek) records in an app to
a desktop viewer — [Peek Pro](https://github.com/artdima/peek-pro) — over a
WebSocket on the local network.

The app connects to the desktop, is let in with a code a person types once,
and sends what its store holds and then every change. Bodies stay on the
device until the desktop asks for one, so a large download costs nothing
until someone wants to read it.

[`doc/remote.md`](https://github.com/artdima/peek/blob/main/doc/remote.md)
is the whole guide: setting up, security, what is not sent, and what to do
when it does not connect.

## Install

```yaml
dependencies:
  peek: ^2.0.0
  peek_remote: ^2.0.0
```

## Use

One line where Peek is set up, in debug builds:

```dart
if (kDebugMode) {
  peek.attach(PeekRemote(peek)..start());
}
```

Then, with Peek Pro running, open Peek on the device, tap ⋯ and
**Connect to Peek Pro**, pick the Mac or type its address, and type the
four-digit code Peek Pro shows. A right code is answered with a token for
this device, which the client sends from then on, and the desktop is
remembered (`shared_preferences`): the next `start()` goes straight back to
it. `peek.attach` disposes the client together with Peek; pass `name:` to
say what the desktop should call the app (`PeekOptions.name` otherwise).

An app with its own pairing screen does the same in code:

```dart
await remote.connect(PeekRemoteEndpoint.parse('192.168.1.20:9741'), code: '4719');
```

`remote.forget()` drops the desktop; a desktop that has forgotten the device
turns it away, and the app asks for a code again. `remote.state` is
`unpaired` while there is nothing to connect to, and `remote.stateChanges`
follows it.

A test run or a CI job has nobody to type a code: give it the address and
the long token Peek Pro shows in its settings instead.

```dart
peek.attach(
  PeekRemote(
    peek,
    endpoint: PeekRemoteEndpoint.parse('192.168.1.20:9741'),
    token: const String.fromEnvironment('PEEK_REMOTE_TOKEN'),
  ),
)..start();
```

- **Where the desktop is.** A phone or tablet on the same Wi-Fi uses the
  address the desktop shows — an iPhone too when it is on a cable, since the
  cable does not carry the app's connection. The iOS Simulator shares the
  Mac's network: `localhost`. The Android emulator reaches the machine it
  runs on as `10.0.2.2`; an Android phone on a cable can run
  `adb reverse tcp:9741 tcp:9741` and use `localhost`.
- **It never slows the app down.** A change is queued and sent on the next
  turn of the event loop. When the desktop cannot keep up, the oldest frames
  go and the desktop is told how many (`maxQueued`, 2000 by default).
- **Bodies stay on the device** when they are larger than `inlineBodyBytes`
  (4 KB by default); the desktop asks for one when someone opens it.
- **A lost desktop is tried again** after a pause that grows to `retryMax`,
  and the history is sent anew. A desktop that turns the app away — a wrong
  code or token, another protocol version — stops it until it is told to
  connect again; the reason reaches `PeekOptions.onError` and
  `remote.denial`.
- **Debug builds only.** The connection is plain `ws://` on a local network;
  start the client behind `kDebugMode`, as Peek itself usually is.

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
