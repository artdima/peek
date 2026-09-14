# Changelog

Each package keeps its own changelog; this one says what a release is.
Versions move together, so `peek`, `peek_dio` and `peek_talker` always
carry the same number.

## 1.0.0

The first release. Peek reads the network calls an app's own loggers
already record and shows them inside the app; it never performs,
intercepts, delays or changes a request of its own.

- [`peek`](packages/peek/CHANGELOG.md) — the pure-Dart core and the
  Flutter console built on it.
- [`peek_dio`](packages/peek_dio/CHANGELOG.md) — the Dio interceptor.
- [`peek_talker`](packages/peek_talker/CHANGELOG.md) — the Talker adapter.
