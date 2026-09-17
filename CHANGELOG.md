# Changelog

Each package keeps its own changelog; this one says what a release is.
Versions move together, so every package always carries the same number.

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
