# Architecture

Peek is a presentation layer. It never performs a request, never wraps a
client and never sits in the path of one: it shows what the loggers an app
already runs have seen. Everything below follows from that.

## The shape

```
┌──────────────────────────────┐   ┌──────────────────────────────┐
│  Loggers the app already has │   │  peek_dio · peek_talker · …  │
│  Dio interceptors, Talker,   ├──▶│  adapters: watch, map into   │
│  http, chopper, …            │   │  PeekEvent                   │
└──────────────────────────────┘   └───────────────┬──────────────┘
                                                   │ PeekSink.report
                                   ┌───────────────▼──────────────┐
                                   │  peek/core   (pure Dart)     │
                                   │  model · redaction · limits  │
                                   │  store · query · export      │
                                   └───────────────┬──────────────┘
                                                   │ PeekStore.changes
                                   ┌───────────────▼──────────────┐
                                   │  peek/ui     (Flutter)       │
                                   │  controller · screens · theme│
                                   └──────────────────────────────┘
```

Dependencies run one way only: `ui → core`, `adapter → core`. The core knows
about neither the screens nor the adapters, and the adapters know nothing
about each other.

## The three layers

**Core** (`package:peek/core.dart`, `lib/src/core/`) is the model of a
network call and everything that can be done to one without drawing it: the
`PeekEntry` and its parts, the redaction policy, the size limits, the store,
the filter/search/sort query, and the exporters (cURL, HAR, Markdown, text).
It is pure Dart.

**UI** (`package:peek/peek.dart`, `lib/src/ui/`) is Flutter: `PeekController`
holds what the list shows, `PeekScope` hands it down, `PeekTheme` says how
everything looks, and the screens and widgets read both. Peek brings its own
frame and its own theme rather than borrowing the app's, so a log reads the
same wherever it is embedded; the only thing it takes from the host's theme
is the brightness.

**Adapters** (`peek_dio`, `peek_talker`, yours) are separate packages, one
per logger, each depending on `package:peek/core.dart` and its logger — never
on the UI. Adding a logger adds a package; it changes nothing else.
`doc/adapters.md` is the guide to writing one.

## Why the core is pure Dart

- A network call is a value, and values are cheaper to test than widgets:
  most of Peek's tests need no `WidgetTester` and no surface.
- An adapter depends on the core, so a Flutter-free core keeps a Dart-only
  logger adapter possible and keeps every adapter's dependency small.
- Export, redaction and the store are useful without a screen — a CI job
  turning entries into HAR needs no Flutter.
- If a `peek_core` package is ever wanted, it lifts out mechanically: the
  boundary already exists, and the public API would not move.

The rule is enforced, not remembered: `packages/peek/test/architecture_test.dart`
scans `lib/src/core/**` for any `package:flutter/…` directive and fails on
the first one. Each adapter has the mirror of that test, asserting it imports
Peek's core and nothing beyond it.

## What happens to an event

1. An adapter sees a call and reports a `PeekEvent` into the `PeekSink` —
   `Peek` itself is the sink.
2. `Peek.report` drops the event when recording is off, paused or disposed.
3. Redaction runs first: headers, query parameters and body fields matching
   the policy are replaced before anything keeps them. What is redacted is
   never stored, so nothing downstream can leak it.
4. Size limits run second: bodies past `maxBodyBytes` are truncated and
   marked as such.
5. The reducer applies the event to the store — starting an entry,
   completing it, or recording a whole one learned after the fact. An event
   it refuses is reported to `PeekOptions.onError` rather than dropped in
   silence.
6. The store emits a `PeekStoreChange`; `PeekController` re-runs its query
   and notifies; the screens rebuild.

Every step runs inside a guard. A failure anywhere in Peek — in an adapter's
mapping, in the reducer, in the store — reaches `PeekOptions.onError` and
never the app: a debugging tool that can break the app it debugs is worse
than none.

## The store

`PeekStore` is an interface; `InMemoryPeekStore` is the only implementation
in 1.0 — a ring buffer of `maxEntries` that evicts the oldest first and skips
pinned entries. Persistence is a different `PeekStore`, not a change here.

## The UI layer

`PeekController` is a `ChangeNotifier` over one `Peek`: it subscribes to
`store.changes`, keeps the filtered and sorted entries and the facets a
filter can offer, and debounces typing so a large store is not scanned on
every keystroke. `PeekScope` is an `InheritedNotifier` around it, so screens
depend on the state rather than on the way it was opened, and a modal route
— which builds beside the screen that opened it, not under it — is handed the
scope explicitly.

`PeekTheme` is a `ThemeExtension`, which is how an app overrides any token
without Peek exposing a second theming system. `PeekSurface` gives every
screen and panel the ancestors Flutter's text expects, so nothing inherits
the host's styling by accident.

## Where things go

| Adding                     | Goes in                              |
| -------------------------- | ------------------------------------ |
| A field of a network call  | `core/model/`, and every exporter    |
| An export format           | `core/export/`, exported from `core.dart` |
| A way to filter or sort    | `core/query/`                        |
| A screen or a widget       | `ui/screens/`, `ui/widgets/`         |
| Support for another logger | a new `peek_<logger>` package        |

Nothing in `core/` may import from `ui/`, and nothing in either may import an
adapter.
