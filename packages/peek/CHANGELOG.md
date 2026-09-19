# Changelog

## 1.3.0

The screen catches up with the work done on it every day.

- Recording pauses and resumes from the bar, and a card under the quick
  bar says so while it is paused. `Peek.pauseChanges` reports every change,
  so a pause the app asks for reaches the screen too.
- The actions sheet sits flush against the bottom edge and groups what it
  offers into cards under their own headings; a call's sheet opens with
  the method as a tile beside its path and host.
- Each order in the sort menu wears a glyph, and an option no one chose
  reads quieter than an action.
- The filters sheet is one row per criterion: it says what it is narrowed
  to and opens a sheet of its own to change it, where values toggle with
  their counts. The button at the foot says how many requests are left.
- New in the public API: `PeekFilledButton`, `PeekAction.section` and
  `header` on `showPeekActions`, `PeekIconButton.selected`,
  `PeekMethodBadge.large`, `PeekController.pause`/`resume`, nine glyphs in
  `PeekIcons` and the strings that name all of it.

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
