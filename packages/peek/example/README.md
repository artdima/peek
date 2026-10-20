# peek_example

An app that makes real calls and reads them in Peek. It is what the
screenshots in the README come from, and what the integration test drives.

```sh
flutter run
```

Every button on the home screen is one scenario — a JSON answer, a failure,
a timeout, a redirect, an image, a body past the limit, a header with three
values — chosen so each screen of Peek has something to show, and how its
last run went is read beside its name. The row of adapters under the heading
picks which one reports them, with the package that carries it named at the
end:

- `lib/dio_setup.dart` — `PeekDioInterceptor` on a Dio client;
- `lib/talker_setup.dart` — `PeekTalkerAdapter` next to a `TalkerDioLogger`;
- `lib/chopper_setup.dart` — `PeekChopperInterceptor` in a Chopper chain,
  with its own scenarios in `lib/chopper_scenarios.dart`;
- `lib/http_setup.dart` — `PeekHttpClient` around a `package:http` client,
  with its own scenarios in `lib/http_scenarios.dart`;
- `lib/share.dart` — the share delegate, wired to `share_plus`; on the web
  it hands back nothing, and Peek saves the file through the browser.

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

On the web the example is the demo page,
[artdima.github.io/peek](https://artdima.github.io/peek/): an app on one
phone and Peek on the other — two views of one program over the same
`Peek`, so a call made on the left arrives on the right.
`web/index.html` lays the page out, `web/flutter_bootstrap.js` adds the
views and names each phone, and `lib/web_demo.dart` draws a phone's screen
around each of them. The switch under the left phone picks its app: a
sneaker shop, which the page opens with, or the example itself, which the
page calls the playground. The one above the phones picks their theme;
`lib/web_demo_page_web.dart` is where the program hears what the page
picked.

The shop, in `lib/shop/`, is a small app of the kind Peek is for: a
catalogue, a page per shoe, favourites and a bag that orders. Its server
is pretended inside the app — `PaceServer`, a Dio adapter — so its calls
are the same for every visitor and still go through `PeekDioInterceptor`
like any other. Two of them fail the way they do in a real shop: the last
pair of a size has gone by the time it is added to the bag (409), and the
first payment finds the provider busy (503).

```sh
flutter run -d chrome
```

```sh
flutter test integration_test
```

runs the smoke test on a connected device: it presses through the
scenarios, opens Peek and reads a call.
