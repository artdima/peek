# Remote viewing

Peek shows an app's calls on the device. [Peek Pro](https://github.com/artdima/peek-pro)
shows them on a Mac, live, while the app runs: a bigger screen, search
across everything, several apps at once and sessions saved to files.
The [`peek_remote`](../packages/peek_remote) package in the app streams the
calls there. This guide sets it up from nothing and says what crosses the
wire and what does not.

## How it works

```
┌─ the app, a debug build ─────────────┐             ┌─ the Mac ──────────────────┐
│                                      │             │                            │
│  adapters ─▶ Peek ─▶ PeekRemote ─────┼── calls ───▶│  Peek Pro, port 9741       │
│                          ▲           │             │                            │
│                          └───────────┼◀── bodies ──┤  as a person opens them    │
│                                      │             │                            │
└──────────────────────────────────────┘             └────────────────────────────┘
```

- **The Mac listens, the app calls it.** A phone reaches a laptop more
  easily than the other way round, and one Mac can watch several apps at
  once. The connection is a WebSocket on the local network, port 9741 unless
  Peek Pro was told otherwise.
- **First the history, then every change.** Once Peek Pro lets the app in,
  the app sends every call its store holds, oldest first, and then each
  change as it happens. A call travels exactly as a line of a `.peek` file
  holds it.
- **Bodies stay on the device until someone opens one.** A body up to 4 KB
  (`inlineBodyBytes`) travels with its call; a larger one is sent when a
  person opens it in Peek Pro, so a big download costs nothing until then.
- **The app never waits for the network.** A change goes into a queue and
  out on the next turn of the event loop. When Peek Pro cannot keep up, the
  oldest frames are thrown away (`maxQueued`, 2000) and Peek Pro says calls
  may be missing.
- **A lost connection comes back by itself.** The app tries again after a
  pause that grows to half a minute, sends its history anew, and Peek Pro
  recognises the run and replaces what it showed rather than adding a
  second session.

[`doc/spec/remote-protocol.md`](spec/remote-protocol.md) has every frame.

## Setting it up

### 1. Add the package

```yaml
dependencies:
  peek_remote: ^2.0.0
```

And one line where Peek is set up — behind `kDebugMode`, see
[Keep it out of release builds](#keep-it-out-of-release-builds):

```dart
if (kDebugMode) {
  peek.attach(PeekRemote(peek)..start());
}
```

`peek.attach` disposes the client with Peek. Nothing is written about the
Mac in code: a person pairs from the phone, once, and the app remembers.

### 2. Let the app use the local network

- **iOS** asks the person before an app talks to the local network, and
  lets it browse only for the services it names. Add to `Info.plist`:

  ```xml
  <key>NSLocalNetworkUsageDescription</key>
  <string>Streams network calls to Peek Pro on this network.</string>
  <key>NSBonjourServices</key>
  <array>
    <string>_peek._tcp</string>
  </array>
  ```

- **macOS**: the same two keys, and in the sandbox's entitlements
  `com.apple.security.network.client`.
- **Android**: nothing. Flutter's debug build already has `INTERNET`, and
  the permission Bonjour needs comes with the package.

### 3. Pair from the phone

1. Start Peek Pro. It shows a four-digit code in its window while no device
   is connected; the toolbar's Connection button and Settings → Connection
   → Access show it too.
2. In the app, open Peek, tap **⋯** and **Connect to Peek Pro**.
3. Pick the Mac under **On this network**, or type its address.
4. Type the code. The app connects after the fourth digit.

A right code is answered with a token for this device, which the app keeps
and sends from then on: the next launch goes straight back to the Mac with
no code. A code lasts a few minutes, works once, and gives way to a new one
after five wrong tries. **Forget this Mac** in the same sheet drops the
pairing on the phone; Settings → Connection → Paired Devices in Peek Pro
drops it on the Mac, and the app asks for a code again.

### Where the Mac is

| The app runs on | Address |
| --- | --- |
| The iOS Simulator | `localhost` — it shares the Mac's network |
| An iPhone or iPad | The Mac's Wi-Fi address, on the same Wi-Fi. A cable does not carry the app's connection, and `localhost` is the phone itself |
| The Android emulator | `10.0.2.2` |
| An Android phone on Wi-Fi | The Mac's Wi-Fi address |
| An Android phone on a cable | `localhost`, after `adb reverse tcp:9741 tcp:9741` |

Peek Pro lists its addresses in its window and in Settings → Connection.
On the same Wi-Fi the Mac usually needs no address at all: Peek Pro
announces itself over Bonjour and the sheet lists it by name.

### Without a person: a token in code

A test run or a CI job has nobody to type a code. Peek Pro also shows a
long token — Settings → Connection → Access — and an app that has it in
code needs no pairing:

```dart
peek.attach(
  PeekRemote(
    peek,
    endpoint: PeekRemoteEndpoint.parse('192.168.1.20:9741'),
    token: const String.fromEnvironment('PEEK_REMOTE_TOKEN'),
  ),
)..start();
```

**Regenerate** in Peek Pro turns away every app that still sends the old
token. The example app takes all of this from `--dart-define`:
`PEEK_REMOTE` for the address, `PEEK_REMOTE_TOKEN` or `PEEK_REMOTE_CODE`.

An app with its own screen for pairing calls
`remote.connect(endpoint, code: '4719')` and follows `remote.stateChanges`;
`remote.discover()` lists the Macs on the network.

## Security

**Who can stream into Peek Pro.** Only an app that sends the token Peek
Pro shows, or a token it issued for a right code. A code is four digits,
short-lived, spent on success, replaced after five wrong tries and compared
in constant time; the token it earns is long and random. Peek Pro keeps the
tokens it issued in the Mac's Keychain and lists the devices, so one can be
forgotten.

**Where the app sends its calls.** To the Mac a person picked or typed, and
nowhere else — there is no relay and no account. A device token goes only
to the Mac that issued it: the app tells Macs apart by the id Peek Pro
announces, and offers another Mac no token at all. Pick your own Mac by
name: a stranger's Mac on the same network could run a viewer too.

**What anyone on the network can see.** The connection is plain `ws://`,
not encrypted: it is meant for a local network and a debug build. Someone
who can watch that network's traffic can read the calls as they pass. When
that matters, mask what should not travel — redaction runs before anything
is stored, so masked values arrive masked:

```dart
Peek(options: PeekOptions(redaction: PeekRedactionPolicy()));
```

**What the app keeps.** The Mac's address, name and id, and the device
token, in `shared_preferences` under keys starting with `peek_remote.`.
`remote.forget()` removes them.

### Keep it out of release builds

A network inspector that streams a user's calls to whichever Mac is on the
Wi-Fi has no place in an app on the store. Start the client only in debug
builds — `if (kDebugMode)`, or a flavour of your own — and switch recording
off there too with `PeekOptions(enabled: kDebugMode)`. A client that is
never started opens no socket and browses for nothing.

## What is not sent

- **Nothing Peek does not hold.** Calls the store evicted, bytes past
  `maxBodyBytes` and values the redaction policy masked never leave the
  device — Peek Pro sees the store, not the network.
- **Nothing but the calls.** No logs, no screenshots, no identifiers of the
  device or the person. The app introduces itself with what a `.peek` file's
  header holds — its name, the platform, Peek's version, when it started
  and, on Apple platforms, the OS version — and a random id for the run.
- **Large bodies until they are opened.** And never, if the app is gone by
  then: Peek Pro shows that the body could not be loaded.
- **Nothing from Peek Pro but what the protocol needs.** The answer to the
  hello, requests for bodies, and pings to keep the connection honest.

## When it does not connect

| The sheet says | What it means |
| --- | --- |
| Waiting for … | The app cannot reach the Mac at that address. A real device typed `localhost`; the phone and the Mac are on different networks, or a guest network keeps devices apart; the Mac's firewall blocks Peek Pro (System Settings → Network → Firewall, allow incoming connections); on an iPhone, the app is off in Settings → Privacy & Security → Local Network. |
| Check the code on the Mac. | The code was wrong, or had changed. Type the one Peek Pro shows now. |
| Speaks another version of the protocol | Update whichever of the two is older. |
| Peek Pro turned the app away | Peek Pro forgot this device, or the token in code is old. Pair again with a code, or copy the token again. |

The Mac missing from **On this network** means Bonjour is not getting
through: many office networks block it, Peek Pro can have advertising off
(Settings → Connection → Bonjour), and an iOS app needs the two
`Info.plist` keys above. Typing the address always works.

To tell a network problem from anything else, open
`http://<the Mac's address>:9741` in the device's browser. An error at once
means the Mac is reachable and something else is wrong; a page that loads
until it times out means the device cannot reach the Mac at all.

## Without Peek Pro

`tool/peek_remote_dump.dart` in `packages/peek_remote` listens the way Peek
Pro does and prints every frame, for trying the client out or for a CI job
that keeps the calls:

```sh
dart run tool/peek_remote_dump.dart --token k7Qx2mP9 --out session.jsonl
```

`--code 4719` makes it pair the way Peek Pro does.

## Building a viewer

Peek Pro is one viewer; the protocol does not assume it. Everything a viewer
needs is in [`doc/spec/`](spec/):
[`remote-protocol.md`](spec/remote-protocol.md) for the connection and
[`session-format.md`](spec/session-format.md) for the calls and the `.peek`
files, each with reference files a viewer's tests can read.
