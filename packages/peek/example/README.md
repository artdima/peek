# peek_example

An app that makes real calls and reads them in Peek. It is what the
screenshots in the README come from, and what the integration test drives.

```sh
flutter run
```

Every button on the home screen is one scenario from `lib/scenarios.dart` —
a JSON answer, a failure, a timeout, a redirect, an image, a body past the
limit, a header with three values — chosen so each screen of Peek has
something to show. The calls go out through Dio; a second route sends the
same calls through Talker instead, so both adapters are exercised:

- `lib/dio_setup.dart` — `PeekDioInterceptor` on the client;
- `lib/talker_setup.dart` — `PeekTalkerAdapter` next to a `TalkerDioLogger`;
- `lib/share.dart` — the share delegate, wired to `share_plus`.

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
