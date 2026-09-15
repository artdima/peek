# Writing a Peek adapter

An adapter connects a logger you already use to Peek. It watches what the
logger sees, turns each network call into Peek's model and reports it into a
`PeekSink`. It never performs, delays or changes a request — Peek is a
presentation layer, and an adapter is a pair of eyes, not a pair of hands.

Everything an adapter needs comes from one import:

```dart
import 'package:peek/core.dart';
```

## The contract

Each network call is a short sequence of events that share one `PeekId`:

| Event                  | When                                | Carries                          |
| ---------------------- | ----------------------------------- | -------------------------------- |
| `PeekRequestStarted`   | the request goes out                | `PeekRequest`, source name       |
| `PeekResponseReceived` | a response arrives                  | `PeekResponse`, optional timings |
| `PeekRequestFailed`    | the call fails                      | `PeekFailure`, optional response |
| `PeekEntryRecorded`    | a whole call is learned after the fact | a complete `PeekEntry`        |

Rules the sink relies on:

1. **One id per call.** Draw it with `PeekId.generate()` when the request
   starts and reuse it for the response or failure of that call. Never mint
   an id from the logger's own objects — hash codes collide, and Peek's ids
   are unique across app launches.
2. **Exactly one ending.** A started call ends with either a response or a
   failure, never both. A failure that came with a server answer (a status
   the client rejects, say) is one `PeekRequestFailed` with `response` set.
3. **After-the-fact sources report entries.** If you only see calls once
   they are over — a log history, a replayed file — build a `PeekEntry` and
   report `PeekEntryRecorded`. Peek upserts it by id.
4. **Timestamps are yours.** Stamp events with the time you saw them, using
   a `PeekClock` so tests can freeze it. Accept the clock in your
   constructor and default to `PeekSystemClock`.
5. **Unknown ids are fine.** If you report a response for an id Peek has
   not seen, Peek records a call whose request it missed. Do not try to
   reconstruct one.

What the sink guarantees in return: `report` is synchronous, cheap and never
throws. You can call it from inside an interceptor without a `try`.

## Mapping a call

Four types carry everything Peek draws. Fill in what the logger gives you and
leave the rest at its default — an absent value is shown as absent, a guessed
one is shown as fact.

```dart
PeekRequest(
  method: 'GET',                                  // uppercased for you
  uri: Uri.parse('https://api.example.com/users?page=2'),
  headers: PeekHeaders.fromMap(request.headers),  // or fromMultiMap
  body: PeekBody.text(request.body),
  extra: {'client': 'main'},                      // free-form, optional
);

PeekResponse(
  statusCode: 200,
  statusMessage: 'OK',
  headers: PeekHeaders.fromMultiMap(response.headers),
  body: PeekBody.bytes(response.bodyBytes),
);

PeekFailure(
  kind: PeekFailureKind.timeout,  // connection, badCertificate, cancelled,
  message: '$error',              // badResponse, unknown
  details: error,
  stackTrace: stackTrace,
);

const PeekTimings(
  connect: Duration(milliseconds: 12),
  wait: Duration(milliseconds: 84),
);
```

A body is whichever of these fits: `PeekBody.text`, `PeekBody.bytes`,
`PeekBody.form`, `PeekBody.fromJsonLike` for a value the logger already
decoded, `PeekBody.empty()` for none, and `PeekBody.unavailable(reason)` for
one that exists but was not captured — `streamed`, `tooLarge`, `notCaptured`
or `unreadable`. The last one is not a failure to apologise for: knowing a
body was a stream is worth more than an empty box.

Timings are optional and partial: pass a `PeekTimings` with only the phases
the logger measured, or none at all. Peek always knows the whole duration —
it has both timestamps.

## What an adapter must not do

- Modify, delay or cancel the request or response it observes.
- Read a streamed body. Report `PeekBody.unavailable(streamed)` instead.
- Redact or truncate. Peek applies its own policy to every event; doing it
  twice only loses information.
- Let an exception escape into the client's code. Wrap the mapping in
  `try`/`catch` and hand failures to `PeekSink.reportAdapterError`.
- Log to the console. The logger you are adapting already does.

## Shape of an adapter

```dart
final class PeekFooAdapter implements PeekAdapter {
  PeekFooAdapter(this._sink, {PeekClock clock = const PeekSystemClock()})
      : _clock = clock;

  final PeekSink _sink;
  final PeekClock _clock;
  final _ids = Expando<PeekId>();

  @override
  String get name => 'foo';

  void onRequest(FooRequest request) {
    try {
      final id = PeekId.generate();
      _ids[request] = id;
      _sink.report(PeekRequestStarted(
        id: id,
        timestamp: _clock.now(),
        request: mapRequest(request),
        source: name,
      ));
    } catch (error, stackTrace) {
      _sink.reportAdapterError(error, stackTrace);
    }
  }

  @override
  void dispose() {}
}
```

Correlate the response with its request through the object the logger hands
you both times — an `Expando` keyed by that object costs nothing and leaves
the request untouched.

## When the logger hands you the chain

Some clients do not call you twice. Chopper, and anything else shaped after
OkHttp, gives an interceptor the rest of the chain and lets it make the
call, so one method sees the whole thing:

```dart
@override
Future<Response<BodyType>> intercept<BodyType>(Chain<BodyType> chain) async {
  final id = PeekId.generate();
  _guard(() => _sink.report(PeekRequestStarted(id: id, ...)));

  try {
    final response = await chain.proceed(chain.request);
    _guard(() => _sink.report(PeekResponseReceived(id: id, ...)));
    return response;
  } on Object catch (error, stackTrace) {
    _guard(() => _sink.report(PeekRequestFailed(id: id, ...)));
    rethrow;
  }
}
```

Two things follow. The id lives in a local variable: no `Expando`, nothing
written into the request, and a call that goes through the chain a second
time is a second call reported as one.

And the adapter now holds the continuation of the call, which a pair of
callbacks never did. `proceed` therefore stays **outside** the `try` that
guards the mapping — a guard wrapped around it would turn a mapper that
raises into a request that never went out. Return the response that
arrived, and `rethrow` the error as it was: not a copy, not a wrapper.

## Attaching it

An adapter that implements `PeekAdapter` can be handed to Peek, which keeps
it in `adapters` and disposes it with itself:

```dart
final peek = Peek();
peek.attach(PeekFooAdapter(peek));
```

`attach` returns the adapter, so the line that creates it is also the line
that registers it with the logger.

## Packaging it

An adapter is its own package, named `peek_<logger>`, so that an app pays
only for the loggers it uses:

```
peek_foo/
├── lib/peek_foo.dart              # the only public library
├── lib/src/peek_foo_adapter.dart
├── lib/src/peek_foo_mapper.dart   # logger types → Peek's model
├── test/peek_foo_mapper_test.dart
├── test/architecture_test.dart    # core-only imports
├── CHANGELOG.md  LICENSE  README.md
└── pubspec.yaml
```

```yaml
name: peek_foo
description: >-
  Reports the calls Foo makes to Peek, so they can be read in the app.
version: 0.1.0

environment:
  sdk: ^3.7.0

dependencies:
  foo: ^1.0.0
  peek: ^1.0.0

topics:
  - debugging
  - http
  - logging
  - network
```

Two rules the package shape is there to keep: the adapter depends on
`package:peek/core.dart` only — never on `package:peek/peek.dart`, which
would drag Flutter and the screens in — and the mapping from the logger's
types to Peek's lives in its own file, so it can be tested without the
logger running.

## Checklist

- [ ] Every `PeekRequestStarted` is followed by exactly one ending event.
- [ ] A response for an unknown id does not throw.
- [ ] Bodies you cannot read become `PeekBody.unavailable`.
- [ ] Mapping errors reach `reportAdapterError`, never the app.
- [ ] `dispose` is safe to call twice.
- [ ] A chain-shaped adapter calls `proceed` outside its guard, returns the
      response it was handed and rethrows the error it caught.
- [ ] Tests run against a real `Peek` with a fake clock and check the
      resulting entries, not just the events.

Peek's own layers, and why the core carries no Flutter, are in
[architecture.md](architecture.md).
