# peek_example

An app that makes real calls and reads them in Peek. It is what the
screenshots in the README come from, and what the integration test drives.

```sh
flutter run
```

Every button on the home screen is one scenario — a JSON answer, a failure,
a timeout, a redirect, an image, a body past the limit, a header with three
values — chosen so each screen of Peek has something to show. The switch at
the top picks which adapter reports them:

- `lib/dio_setup.dart` — `PeekDioInterceptor` on a Dio client;
- `lib/talker_setup.dart` — `PeekTalkerAdapter` next to a `TalkerDioLogger`;
- `lib/chopper_setup.dart` — `PeekChopperInterceptor` in a Chopper chain,
  with its own scenarios in `lib/chopper_scenarios.dart`;
- `lib/http_setup.dart` — `PeekHttpClient` around a `package:http` client,
  with its own scenarios in `lib/http_scenarios.dart`;
- `lib/share.dart` — the share delegate, wired to `share_plus`.

The Dio routes share `lib/scenarios.dart`. Chopper has its own list because
it takes the base of a call per request, and because a status the server
refused is an answer there rather than a failure. `package:http` has its own
too: its calls end when the body is read, and one scenario waits before
reading to show a call pending until then.

A last row fills the store with made-up calls from `lib/demo_data.dart`,
reported through Peek's public API the way an adapter would — for looking
at the screens without a network.

Peek is opened from the floating button with `showPeek`. Redaction is left
at its default here — off — so the tokens the scenarios send are visible.

```sh
flutter test integration_test
```

runs the smoke test on a connected device: it presses through the
scenarios, opens Peek and reads a call.
