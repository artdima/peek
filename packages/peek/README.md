<p align="center">
  <img src="https://raw.githubusercontent.com/artdima/peek/main/assets/hero-light.jpg" alt="Peek — a network logger for Flutter: requests, responses and failures, right inside the app. Plugs into dio, talker, chopper and http." width="860">
</p>

<p align="center">
  <a href="https://pub.dev/packages/peek"><img src="https://img.shields.io/pub/v/peek.svg" alt="pub package"></a>
  <a href="https://artdima.github.io/peek/"><img src="https://img.shields.io/badge/demo-live-ff6a3d?logo=flutter&logoColor=white" alt="Live demo"></a>
  <a href="https://github.com/artdima/peek/actions/workflows/ci.yml"><img src="https://github.com/artdima/peek/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://codecov.io/gh/artdima/peek"><img src="https://codecov.io/gh/artdima/peek/branch/main/graph/badge.svg" alt="Coverage"></a>
  <a href="https://github.com/artdima/peek/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue" alt="License: MIT"></a>
</p>

<p align="center">
  <b>English</b> ·
  <a href="https://github.com/artdima/peek/blob/main/README.ru.md">Русский</a> ·
  <a href="https://github.com/artdima/peek/blob/main/README.zh-CN.md">简体中文</a> ·
  <a href="https://github.com/artdima/peek/blob/main/README.es.md">Español</a> ·
  <a href="https://github.com/artdima/peek/blob/main/README.pt-BR.md">Português</a> ·
  <a href="https://github.com/artdima/peek/blob/main/README.ja.md">日本語</a>
</p>

**What Peek is.** Peek is a network logger for Flutter with the calls shown
right inside the app: requests, responses, headers and failures. Search and
filters find the call you are after, and a call exports as cURL, HAR,
Markdown or text.

Peek attaches to Dio, Chopper and `package:http` through adapters. If you
use Talker, Peek takes the network logs it already keeps, without recording
them twice.

<p align="center">
  <a href="https://artdima.github.io/peek/"><img src="https://raw.githubusercontent.com/artdima/peek/main/assets/demo-button.png" width="300" alt="Open the live demo: runs in your browser, no install"></a>
</p>

**How it works.** Peek watches the calls without changing what they carry or
how they behave: nothing is delayed, retried or rewritten. It creates no
client, uses no `HttpOverrides` and prints nothing to the console — keep the
console logger you are used to.

`package:http` needs a wrapper, and it passes the data through unchanged. If
something goes wrong inside Peek itself, the error goes to
`PeekOptions.onError` and the app carries on.

**Inspired by Pulse.** The idea of Peek is inspired by
[Pulse](https://github.com/kean/Pulse), the network logger for Apple
platforms. Peek is an independent project, written from scratch for Flutter.

<p align="center">
  <img src="https://raw.githubusercontent.com/artdima/peek/main/assets/screenshots/phones-light.png" width="860" alt="Peek in the light theme: the console, one call, a JSON body and the export sheet">
</p>
<p align="center">
  <img src="https://raw.githubusercontent.com/artdima/peek/main/assets/screenshots/phones-dark.png" width="860" alt="Peek in the dark theme: the console, one call, a JSON body and the export sheet">
</p>

## Quick start

With Dio, two lines where the client is built and one wherever you want a
button:

```dart
final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
dio.interceptors.add(PeekDioInterceptor(Peek.instance));

// Later, from any widget:
showPeek(context);
```

With Talker, one line next to the Talker you already have — the calls its
loggers see are Peek's:

```dart
final peek = Peek();
peek.attach(PeekTalkerAdapter(peek, talker: talker));
dio.interceptors.add(TalkerDioLogger(talker: talker));

showPeek(context, peek: peek);
```

With Chopper, one interceptor in the chain:

```dart
final client = ChopperClient(
  baseUrl: Uri.parse('https://api.example.com'),
  interceptors: [PeekChopperInterceptor(Peek.instance)],
);

showPeek(context);
```

With `package:http`, which has no interceptors, one client around the one you
have:

```dart
final client = PeekHttpClient(Peek.instance, http.Client());

showPeek(context);
```

Prefer a floating button that is always there? Wrap the app once:

```dart
MaterialApp(
  builder: (context, child) => PeekOverlay(
    enabled: kDebugMode,
    child: child!,
  ),
);
```

These lines are compiled, not just quoted: they live in
[`example`](https://github.com/artdima/peek/tree/main/packages/peek/example), an app that makes real
calls all four ways and drives every screen.

## Packages

| Package | What it is | Depends on |
| --- | --- | --- |
| [`peek`](https://github.com/artdima/peek/tree/main/packages/peek) | The core model, store and exporters (`package:peek/core.dart`, pure Dart) and the Flutter UI (`package:peek/peek.dart`) | `flutter`, `meta` |
| [`peek_chopper`](https://github.com/artdima/peek/tree/main/packages/peek_chopper) | `PeekChopperInterceptor`: reports what a Chopper client does | `peek`, `chopper`, `http` |
| [`peek_dio`](https://github.com/artdima/peek/tree/main/packages/peek_dio) | `PeekDioInterceptor`: reports what a Dio client does | `peek`, `dio` |
| [`peek_http`](https://github.com/artdima/peek/tree/main/packages/peek_http) | `PeekHttpClient`: reports what a `package:http` client does | `peek`, `http` |
| [`peek_remote`](https://github.com/artdima/peek/tree/main/packages/peek_remote) | `PeekRemote`: streams the calls to Peek Pro on a Mac, live | `peek`, `bonsoir`, `shared_preferences` |
| [`peek_talker`](https://github.com/artdima/peek/tree/main/packages/peek_talker) | `PeekTalkerAdapter`: reads what Talker logs, `talker_dio_logger` understood out of the box | `peek`, `peek_dio`, `talker`, `talker_dio_logger` |

## Configuration

Everything is set once, on the `Peek` instance, and applies to every
adapter:

```dart
final peek = Peek(
  options: PeekOptions(
    enabled: kDebugMode,
    limits: const PeekLimits(maxEntries: 500, maxBodyBytes: 256 * 1024),
    redaction: PeekRedactionPolicy(
      headerNames: {...PeekRedactionPolicy.defaultHeaderNames, 'x-session'},
    ),
    onError: (error, stackTrace) => log('peek: $error'),
  ),
);
```

- **`enabled`** — pass `kDebugMode` to switch Peek off in release builds
  without touching the adapters.
- **`limits`** — how many calls are kept, how many bytes of a body, how
  many calls may be pinned. What a body limit costs is `maxEntries` of
  them, so raise one with the other in mind.
- **`redaction`** — nothing is masked until asked. `PeekRedactionPolicy()`
  covers the usual names (`Authorization`, `Cookie`, `token`, `password`
  and their relatives); each set replaces the built-in one, so extend a set
  by spreading the defaults back in.
- **Theme** — Peek brings its own look and takes only the brightness from
  the app. Register an override on the app's theme to change any token:
  `ThemeData(extensions: [PeekTheme.light().copyWith(accent: Colors.teal)])`.
- **Strings** — subclass `PeekStrings`, override what you translate, and
  pass it to `showPeek(context, strings: ...)`.
- **Sharing** — Peek depends on no sharing package. Hand it a
  `PeekShareDelegate` wired to the one you use; the example shows it with
  `share_plus`. What arrives says what it is: `PeekShareKind.text` is a
  URL, a cURL command or a summary to paste, `PeekShareKind.file` a HAR or
  a session to attach. On the web there is nothing to hand over: the
  browser shares the text where it can and saves the file otherwise, and a
  delegate given there is still used instead.

## Peek Pro

[Peek Pro](https://github.com/artdima/peek-pro) is a Mac app for watching
the network logs of a phone, a simulator or an emulator in real time. On
the big screen you can search the calls, follow several apps at once and
save sessions to files.

<p align="center">
  <img src="https://raw.githubusercontent.com/artdima/peek/main/assets/screenshots/peek-pro.png" alt="Peek Pro on a Mac: the calls of two devices and two saved sessions, one call open in full" width="860">
</p>

To connect, add [`peek_remote`](https://github.com/artdima/peek/tree/main/packages/peek_remote) and start it in debug builds:

```dart
if (kDebugMode) {
  peek.attach(PeekRemote(peek)..start());
}
```

Then pick Connect to Peek Pro in Peek's menu and enter the code the Mac app
shows. The connection is set up once.

The full guide is [`doc/remote.md`](https://github.com/artdima/peek/blob/main/doc/remote.md): how to set the connection up
and what stays on the device. If you are building a log viewer of your
own, the protocol and the `.peek` file format are described in
[`doc/spec/`](https://github.com/artdima/peek/tree/main/doc/spec).

## Writing your own adapter

An adapter watches a logger and reports `PeekEvent`s into a `PeekSink`. It
needs one import — `package:peek/core.dart` — and about a screen of code;
[`doc/adapters.md`](https://github.com/artdima/peek/blob/main/doc/adapters.md) is the guide, from the contract to the
package layout, with a checklist at the end.

## Contributing

Bugs and ideas go through the issue templates; pull requests through
[`CONTRIBUTING.md`](https://github.com/artdima/peek/blob/main/CONTRIBUTING.md), which has the setup, the scripts and
the definition of done. Security reports are private: see
[`SECURITY.md`](https://github.com/artdima/peek/blob/main/SECURITY.md).

## License

MIT © 2026 Dmitriy Medyannik. The icon outlines come from
[Lucide](https://lucide.dev) (ISC); see [`NOTICE`](https://github.com/artdima/peek/blob/main/NOTICE).
