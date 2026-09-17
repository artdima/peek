# Changelog

## 1.2.0

Released alongside `peek_http`, the adapter for `package:http`. The library
is unchanged; the README and the example app now show the new adapter.

## 1.1.0

Released alongside `peek_chopper`, the adapter for Chopper. Nothing in this
package changed.

## 1.0.0

The first release: a viewer for the network calls an app's own loggers
already record. Peek never performs, intercepts or changes a request.

- A pure-Dart core — `package:peek/core.dart` — with the model of a call
  (`PeekEntry`, request, response, headers, cookies, body, failure,
  timings), the `PeekSink`/`PeekEvent` contract adapters report into, an
  in-memory ring-buffer store with pinning, filtering, searching and
  sorting, and export as cURL, HAR 1.2, Markdown and plain text.
- Optional redaction of headers, query parameters and body keys before a
  call is stored — off by default, one line to turn on — and size limits
  that truncate bodies UTF-8-safely and say so.
- A Flutter UI in the spirit of Pulse: a console with search, quick filters
  and a filter sheet; a call screen with bodies, headers, cookies, query
  parameters, errors and timing on screens of their own; a JSON tree and a
  raw text view; a share delegate the app wires to its own sharing package.
- `showPeek`, `PeekRoute` and `PeekOverlay` for opening it, `PeekTheme`
  for the look, `PeekStrings` for the words. Its own icon set, drawn from
  outlines (Lucide, ISC) — no font, no assets, no dependencies beyond
  Flutter and `meta`.
