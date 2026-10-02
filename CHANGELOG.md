# Changelog

Each package keeps its own changelog; this one says what a release is.
Versions move together, so every package always carries the same number.

## 2.0.0

Remote viewing. A sixth package,
[`peek_remote`](packages/peek_remote/CHANGELOG.md), streams what Peek
records to [Peek Pro](https://github.com/artdima/peek-pro), a Mac app, over
the local network. Pair once from Connect to Peek Pro in Peek's menu with
the code Peek Pro shows, and the calls appear there as they happen; large
bodies stay on the device until someone opens one. A session also saves as
a `.peek` file, which Peek Pro opens. [`doc/remote.md`](doc/remote.md) is
the guide, and `doc/spec/` describes the format and the protocol for anyone
building another viewer.

The major version is for one change: `PeekBody` has a new kind,
`PeekRemoteBody`, so a `switch` that names every kind needs one more case —
see [`peek`](packages/peek/CHANGELOG.md). The four adapters are unchanged
and move to `peek: ^2.0.0`.

## 1.4.0

A release about the console again; the adapters only carry the number. On
the web an export saves itself through the browser, so a HAR reaches the
disk without the app wiring up a sharing package. Where the screen is wide
enough for both panes, the list and the call each wear a bar of their own
and the rule between them runs the full height of the window.

See [`peek`](packages/peek/CHANGELOG.md) for the details.

## 1.3.0

A release about the screen rather than the packages. Peek pauses and
resumes recording from its own bar, the actions sheet groups what it
offers, the sort menu marks each order, and the filters sheet is now one
row per criterion, each opening a sheet of its own. The four adapters are
unchanged and move with the version.

See [`peek`](packages/peek/CHANGELOG.md) for the details.

## 1.2.0

A fifth package: [`peek_http`](packages/peek_http/CHANGELOG.md) —
`PeekHttpClient` reports the calls a `package:http` client makes.
`package:http` has no interceptors, so the adapter wraps the client the app
already has and passes each call through as it came: the response keeps its
type and its bytes, and an entry ends when the body has been read. Where it
sits among other wrapping clients, such as `RetryClient`, decides whether it
sees every attempt or the request body — the README describes both.

The other four packages are unchanged and carry the number to stay in step.

## 1.1.0

A fourth package: [`peek_chopper`](packages/peek_chopper/CHANGELOG.md) —
`PeekChopperInterceptor` reports the calls a `ChopperClient` makes. Chopper
hands an interceptor the rest of the chain, so a call is followed inside one
method: no correlation, nothing written into the request, and a retry is the
second call it looks like. A status the server refused is recorded as the
answer it is; only what the chain throws ends a call as a failure.

The other three packages are unchanged and carry the number to stay in step.

## 1.0.0

The first release. Peek reads the network calls an app's own loggers
already record and shows them inside the app; it never performs,
intercepts, delays or changes a request of its own.

- [`peek`](packages/peek/CHANGELOG.md) — the pure-Dart core and the
  Flutter console built on it.
- [`peek_dio`](packages/peek_dio/CHANGELOG.md) — the Dio interceptor.
- [`peek_talker`](packages/peek_talker/CHANGELOG.md) — the Talker adapter.
