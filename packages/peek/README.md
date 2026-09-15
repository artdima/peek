<p align="center">
  <picture>
    <source
      media="(prefers-color-scheme: dark)"
      srcset="https://raw.githubusercontent.com/artdima/peek/main/assets/peek-logo-dark.png">
    <img src="https://raw.githubusercontent.com/artdima/peek/main/assets/peek-logo.png" width="320" alt="Peek">
  </picture>
</p>

<p align="center">
  <em>A beautiful in-app viewer for the network logs your Flutter app already collects.</em>
</p>

<p align="center">
  <a href="https://pub.dev/packages/peek"><img src="https://img.shields.io/pub/v/peek.svg" alt="pub package"></a>
  <a href="https://github.com/artdima/peek/actions/workflows/ci.yml"><img src="https://github.com/artdima/peek/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://codecov.io/gh/artdima/peek"><img src="https://codecov.io/gh/artdima/peek/branch/main/graph/badge.svg" alt="Coverage"></a>
  <a href="https://github.com/artdima/peek/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue" alt="License: MIT"></a>
</p>

---

**What Peek is.** A presentation layer. Your app already has a logger —
Dio's interceptors, Talker — and that logger already sees every call. Peek
takes what it sees and turns it into a console you can open inside the
app: searchable, filterable, one call at a time down to the last header,
with export as cURL, HAR, Markdown or text.

**What Peek is not.** Another network logger. Peek never performs,
intercepts, delays or changes a request. It does not create an
`HttpClient`, does not wrap `Dio`, does not touch `HttpOverrides`, and does
not print to the console. An adapter is a pair of eyes, not a pair of
hands — and if anything inside Peek fails, the failure reaches
`PeekOptions.onError`, never your app.

**Inspired by Pulse.** Peek is inspired by
[Pulse](https://github.com/kean/Pulse), the network logger for Apple
platforms. It is an independent project, written from scratch for Flutter.

<p align="center">
  <img src="https://raw.githubusercontent.com/artdima/peek/main/assets/screens.png" alt="Peek: the console, a call and a JSON body" width="800">
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
calls all three ways and drives every screen.

## Packages

| Package | What it is | Depends on |
| --- | --- | --- |
| [`peek`](https://github.com/artdima/peek/tree/main/packages/peek) | The core model, store and exporters (`package:peek/core.dart`, pure Dart) and the Flutter UI (`package:peek/peek.dart`) | `flutter`, `meta` |
| [`peek_chopper`](https://github.com/artdima/peek/tree/main/packages/peek_chopper) | `PeekChopperInterceptor`: reports what a Chopper client does | `peek`, `chopper`, `http` |
| [`peek_dio`](https://github.com/artdima/peek/tree/main/packages/peek_dio) | `PeekDioInterceptor`: reports what a Dio client does | `peek`, `dio` |
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
  `share_plus`.

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

MIT © 2026 Dmitrii Medyannik. The icon outlines come from
[Lucide](https://lucide.dev) (ISC); see [`NOTICE`](https://github.com/artdima/peek/blob/main/NOTICE).
