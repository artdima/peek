# Changelog

## Unreleased

- `PeekShareContent.kind` says what a `PeekShareDelegate` is handed:
  `PeekShareKind.text` — a URL, a command or a summary to paste where text
  goes — or `PeekShareKind.file`, a HAR or a session to attach. It defaults
  to `file`, so a delegate written before this one goes on attaching
  everything; one that tells the two apart hands text to the platform as
  text, as the example now does with `share_plus`. On the web, text goes
  through the browser's own share sheet where there is one (phones,
  Safari) and is saved as a file where there is not; a sheet closed
  without choosing shares nothing.
- A call's sheet shares it as text, not only as a HAR, so a failing call
  reaches a chat or a ticket in one step. The sheet is a table now: a row
  per format — URL, cURL, Text, Markdown, HAR — with a Copy button at its
  end and, where something can carry the call off (the app's
  `PeekShareDelegate`, or the browser on the web), a Share button beside
  it. Above the table the call is named the way its tile names it, with
  the host, the outcome, the size and the time on a line of figures, and a
  redirected call shows its hops as a bar, a segment per hop in the colour
  of its status. Pin and Close are round buttons in the header; there is
  no Cancel row. `peekEntryContent` builds what a row shares for an app's
  own menu, in any `PeekEntryFormat`; `PeekEntryAction` gains `shareUrl`,
  `shareCurl`, `shareText` and `shareMarkdown`; `PeekIcons.copy` is new and
  `PeekIcons.share` is drawn as a tray an arrow leaves; `PeekMethodBadge`
  with `large` is the pill that heads a sheet rather than a tile; and
  `PeekStrings` gain `exportAs`, `formatUrl`, `formatCurl`, `formatText`,
  `formatMarkdown`, `formatHar`, `copyHar`, `redirectCount`, `shareUrl`,
  `shareCurl`, `shareText` and `shareMarkdown`.
- The list's menu is laid out the same way: a Session badge and the count
  at its head — `10 requests`, or `2 of 10 requests` under a filter — the
  HAR row with its Copy and Share buttons, then a Session card with Save
  session and the way to Peek Pro, which now says where the link stands
  beside it: `Not connected`, `Connected to Studio Mac`, and so on.
  `PeekBadge` is the pill at the head of a sheet (`PeekMethodBadge` with
  `large` is one); `peekDesktopMenuTitle` and `peekDesktopMenuStatus` give
  an app's own menu the same row; `PeekStrings` gain `session`,
  `listTitle` and `desktopNotConnected`.
- An empty list has a picture: a radar of three arcs sweeping out from a
  point. While nothing has been recorded the centre is a green pulse —
  Peek is listening, and the line under it says recording is on, or that
  it is paused and the pulse goes grey — and when the search and the
  filters have caught everything the arcs are dashed, with a stray dot
  on each, a filter sits at the centre, the line counts what is hidden
  (`All 6 requests are outside the current search and filters.`) and
  Clear filters is a tinted button. `PeekRadar` draws the picture,
  `PeekEmptyState.illustrated` lays a screen out around one with larger
  type, `PeekFilledButton` gains `tinted`, and `PeekStrings` gain
  `noRequestsPausedHint` and `noMatchesOf`; `noRequestsHint` now says that
  recording is on.
- In the dark, a sheet rises off the screen instead of vanishing into it:
  every sheet and alert now draws with `PeekTheme.elevated`, which lifts
  each surface a step the way iOS does — the sheet takes a card's colour,
  a card on it a fill's, with the ink and the status hues unchanged — and
  leaves a light theme as it is. `PeekThemeScope` is what puts a theme in
  force under a subtree, and `PeekTheme.of` looks there before the app's
  registered extension.

## 2.0.0

Remote viewing: the calls Peek records can be watched live on a Mac, in
[Peek Pro](https://github.com/artdima/peek-pro), through the new
`peek_remote` package — see
[`doc/remote.md`](https://github.com/artdima/peek/blob/main/doc/remote.md).

**Upgrading from 1.x.** One change breaks code, and only code that
switches over `PeekBody`: it has a sixth kind, `PeekRemoteBody`. Add a
`PeekRemoteBody()` case — treating it like `PeekUnavailableBody` is a safe
start — and move the constraint to `peek: ^2.0.0`. Everything else is new.

- **Breaking:** `PeekBody` has a sixth kind, `PeekRemoteBody`
  (`PeekBody.remote`) — a body that exists and can be had, but is held
  elsewhere: on the device, when a desktop viewer shows the calls. It knows
  its size and type and holds nothing else. A `switch` over `PeekBody` that
  names every kind stops compiling; add a case for it (or a `_` case) —
  treating it like `PeekUnavailableBody` is a safe start. The codec writes it
  as the `remote` body kind, which readers before this one take for a body
  that was not captured.
- New in the public API: `PeekBodyLoader` fetches a `PeekRemoteBody`, and
  `PeekBodySide` says which half of a call a body is. Hand a loader to
  `PeekScreen` (or `showPeek`, `PeekRoute`, `Peek.open`, `PeekOverlay`,
  `PeekScope`) and such a body shows its size and type with a Load body
  button; what the loader returns replaces the body in the store, so it is
  loaded once, and a failure offers Retry. Without a loader there is no
  button. `PeekEntry.bodyOn` and `PeekEntry.withBody` reach a body by its
  side; `PeekRemoteBodyView` and five `PeekStrings` (`remoteBody`,
  `loadBody`, `loadingBody`, `loadBodyFailed`, `retry`) are new.
- New in the public API: `PeekCodec` writes every part of a call as
  JSON-ready values and reads it back. Unlike HAR it loses nothing Peek
  knows — pending calls, the kind of a failure and its stack trace, pins,
  truncation, why a body is missing — and it reads leniently, so a newer
  writer's unknown keys and kinds do not break an older reader. Session
  files and remote viewing are built on it.
- New in the public API: a session file. `PeekSessionWriter` writes a
  `PeekSessionHeader` and then one line of JSON per call; `PeekSessionReader`
  reads it back into a `PeekSession`. A broken line costs that line, not the
  file, and is counted in `skipped`; a later line of the same call replaces
  the earlier one, so a file can be appended to with
  `PeekSessionCodec.encodeEntry` as calls complete. Peek hands over text and
  never writes a file itself — where the lines go is up to the app.
- `PeekOptions.name` says what the app calls itself in a saved session. Pure
  Dart cannot read an app's name, so without it a viewer shows the platform.
- The list's menu saves a session: everything recorded, not only what the
  list shows, as a `.peek` file named after the app and the time. It sits
  beside Share as HAR and appears where that does — with the app's
  `PeekShareDelegate`, or as a download on the web. `peekSessionContent`
  builds the same file for an app's own menu; `PeekIcons.download` and
  `PeekStrings.saveSession` are new.
- The list's menu always offers **Connect to Peek Pro**, under its own
  heading, and says where the link stands — connected, waiting, turned
  away. With `peek_remote` attached it opens a sheet to pair from: the Macs
  heard on the network, an address to type, and the four-digit code Peek
  Pro shows, in four cells that take a pasted or autofilled code. A refused
  code shakes the cells; a Mac that does not answer, one that answers
  without Peek Pro, an address that leads nowhere and a dropped connection
  each say so. Without `peek_remote` the sheet says what Peek Pro is and how
  to add it. Export moved beside it and appears only when there is
  something to export.
- New in the public API, for the link: `PeekDesktopLink` in the core —
  pure Dart, so the screen knows nothing of `peek_remote`, which implements
  it — with `PeekDesktopLinkState`, `PeekDesktopLinkStatus`,
  `PeekDesktopDenial`, `PeekDesktopFailure` and `PeekDesktopFound`. The
  screen finds the link among `Peek.adapters`. `PeekDesktopSetup`,
  `PeekDesktopLinkSheet`, `showPeekDesktop`, `peekDesktopLinkOf`,
  `peekDesktopMenuLabel` and `peekDesktopAddress` are the sheet's parts;
  `PeekCodeField` is the code cells on their own; `PeekIcons.desktop` and
  the `PeekStrings` that start with `desktop` are new.
- Sheets rise above the keyboard, so a field in one stays in view.

## 1.4.0

Exports save themselves in a browser, and a wide layout gives the list and
the call a bar each.

- On the web an export no longer needs a `PeekShareDelegate`: without one
  Peek hands the file to the browser, which puts it where downloads go. An
  app that brings its own delegate still wins, and
  `peekPlatformShareDelegate()` returns whatever the platform offers. The
  URL behind the file now outlives the click that started the download, so
  a large export arrives whole.
- Side by side, each pane wears a bar of its own. The filters, the
  clearing, the pause and the list's menu sit on the line the way out is
  on, above the name; the call carries its own menu at the top of its
  pane; and the rule between the panes runs the full height of the window
  instead of starting below a bar that spanned both. The list pane is
  wider, so the four quick modes and the order fit on one line.
- A call's menu is named apart from the list's, in both layouts: 'Request
  actions' rather than a second 'More'.
- New in the public API: `peekPlatformShareDelegate()`,
  `PeekSeparator.vertical()`, `PeekScreen.listPaneWidth` and
  `PeekStrings.requestActions`.
- The README and the package description say plainly that Peek records the
  calls it shows, rather than describing it as a layer over someone else's
  logger.

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
