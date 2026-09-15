# Changelog

Each package keeps its own changelog; this one says what a release is.
Versions move together, so every package always carries the same number.

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
