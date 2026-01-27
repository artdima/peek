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

## Checklist

- [ ] Every `PeekRequestStarted` is followed by exactly one ending event.
- [ ] A response for an unknown id does not throw.
- [ ] Bodies you cannot read become `PeekBody.unavailable`.
- [ ] Mapping errors reach `reportAdapterError`, never the app.
- [ ] `dispose` is safe to call twice.
- [ ] Tests run against a real `Peek` with a fake clock and check the
      resulting entries, not just the events.
