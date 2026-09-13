# Contributing to Peek

Thank you for looking. Peek is small on purpose, and the rules below are
what keep it that way.

## What belongs in Peek

Peek is a presentation layer: it shows the network calls a logger already
recorded. It never performs, intercepts, delays or changes a request, and it
never logs to the console. A change that would make Peek sit in the path of
a request does not belong here, however convenient — support for another
logger belongs in an adapter package instead. `doc/architecture.md` explains
the layers; `doc/adapters.md` is the guide to writing an adapter.

## Getting set up

Peek is a monorepo: pub workspaces resolve the packages together, melos runs
the scripts.

```sh
git clone https://github.com/artdima/peek.git
cd peek
flutter pub get           # resolves the whole workspace at once
dart run melos run ci     # format:check, analyze, test — what CI runs
```

Flutter is pinned in `.fvmrc`; CI uses that version, and goldens are
authored against it. The packages themselves promise less — Dart `^3.7.0`,
Flutter `>=3.29.0` — and the `floor` job in CI checks each of them against
that oldest SDK on its own, with every dependency downgraded to the oldest
version its pubspec admits. A lower bound is a promise: raise it when the
code starts using something newer. The tests are held to it too, so an
assertion that needs a newer testing API belongs in a form both versions
understand — `containsSemantics` over `matchesSemantics`, say.

The scripts, all through `dart run melos run <name>`:

| Script             | Does                                                   |
| ------------------ | ------------------------------------------------------ |
| `ci`               | Everything CI runs, in order                           |
| `format`           | Formats every Dart source in place                     |
| `analyze`          | Analyzes every package, failing on infos too           |
| `test`             | Runs every package's tests                             |
| `test:coverage`    | The same, collecting lcov                              |
| `test:integration` | Drives the example on a connected device               |
| `update:goldens`   | Rewrites the golden files (Linux only)                 |
| `pana`             | Scores the publishable packages as pub.dev would       |

## Goldens

Rendering differs between platforms, so goldens are authored and compared on
Linux only, at the Flutter pinned in `.fvmrc`; elsewhere those tests skip
themselves rather than fail for the wrong reason. To add one, write the test
with `expectGolden(finder, 'name')`, then have the files rewritten where CI
compares them: run the **Goldens** workflow (Actions → Goldens → Run
workflow) on your branch. It runs `update:goldens` and commits the PNGs that
changed back to the branch. The same command works locally in an x64 Linux
container with that Flutter:

```sh
dart run melos run update:goldens
```

Set `PEEK_GOLDENS=1` to force the comparison on another platform (expect
differences that mean nothing) or `PEEK_GOLDENS=0` to skip it on Linux —
which is what the `floor` job does, since an older Flutter draws the same
widget differently.

## Definition of done

A change is finished when all of this is true:

- `dart run melos run ci` is green: formatted, no analyzer output at all
  (infos included), every test passing.
- Every new public symbol has a dartdoc comment; every behaviour change has
  a test that fails without it.
- Comments say why, not what. The code says what.
- The public API grew only as much as it had to.
- After 1.0: a line in the package's `CHANGELOG.md` under `Unreleased` for
  anything a user can see.

## Commits and pull requests

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org),
scoped by package:

```
feat(core): add PeekTimings
feat(ui): group the entry screen by section
feat(dio): map transformTimeout to a timeout failure
fix(talker): correlate replayed logs by id
docs: write the adapter guide
test: cover the redaction policy
ci: pin the Flutter version from .fvmrc
chore: bump melos
```

One self-contained change per commit, each green on its own. Work happens on
a branch and lands through a pull request, even solo — that is what runs CI.

## Adding an adapter

Adapters for widely used loggers are welcome as packages in
[this repository](https://github.com/artdima/peek);
anything more specific is better as your own package, and Peek will happily
link to it. Either way, follow `doc/adapters.md` — an adapter watches, and
never intervenes.

## Reporting things

Bugs and ideas go through the issue templates. Security reports do not:
`SECURITY.md` says how to send those privately.
