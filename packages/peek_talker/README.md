# peek_talker

Reports the calls [Talker](https://pub.dev/packages/talker) logs to
[Peek](https://pub.dev/packages/peek), so they can be read inside the app.

Peek never performs, intercepts or modifies a request of its own. An app
that already logs its calls through Talker has them in `talker.stream`;
this package listens there, so nothing has to be logged twice.

## Install

```yaml
dependencies:
  peek: ^1.0.0
  peek_talker: ^1.0.0
```

## Use

One line, next to the Talker you already have:

```dart
peek.attach(PeekTalkerAdapter(peek, talker: talker));
```

That is all, as long as Talker sees the calls — with
[`talker_dio_logger`](https://pub.dev/packages/talker_dio_logger), that
means its interceptor is on the client:

```dart
dio.interceptors.add(TalkerDioLogger(talker: talker));
```

`peek.attach` hands the adapter's life to the instance: `peek.dispose()`
releases it. An adapter built without attaching must be disposed by hand.

The compiled version of these lines lives in
[`example/lib/talker_setup.dart`](https://github.com/artdima/peek/blob/main/packages/peek/example/lib/talker_setup.dart).

## The history is replayed

Talker keeps what it logged before the adapter existed, and the adapter
reports it, oldest first — an app that opens Peek after a failure wants to
see the failure. Pass `replayHistory: false` to start from now instead.

A call whose beginning was never seen is reported as one finished entry
rather than as an answer to nothing.

## Peek reads the objects, not the text

`TalkerDioLoggerSettings` decides what the console prints. Turning
`printRequestData` off hides a body from the console and changes nothing
here: the log entry still carries Dio's own objects, and that is what Peek
maps.

What Peek keeps and what it hides is set on the instance, through
`PeekOptions` — one place for every adapter. Nothing is masked until the
app asks; the default policy covers the usual secret names, and a set can
be extended by spreading the defaults back in:

```dart
final peek = Peek(
  options: const PeekOptions(
    redaction: PeekRedactionPolicy(
      headerNames: {...PeekRedactionPolicy.defaultHeaderNames, 'x-api-key'},
    ),
  ),
);
```

## Teaching it another logger

Talker carries whatever its integrations put in it. A mapper claims the
entries it knows and leaves the rest alone, so another integration —
`talker_http_logger`, `talker_chopper_logger`, an app's own log class — is
a mapper rather than a change to the adapter:

```dart
final class HttpTalkerLogMapper implements PeekTalkerLogMapper {
  const HttpTalkerLogMapper();

  @override
  bool canMap(TalkerData data) => data is HttpRequestLog;

  @override
  PeekEvent? map(TalkerData data, PeekTalkerContext context) {
    final log = data as HttpRequestLog;
    return PeekRequestStarted(
      id: context.begin(log.request),
      timestamp: log.time,
      request: PeekRequest(method: log.request.method, uri: log.request.url),
      source: context.source,
    );
  }
}
```

The three entries of one call — it went out, it came back, it failed —
report under one id: mark the object they share with `context.begin` and
find it again with `context.find`. Then pass the mappers in, in the order
they should be tried:

```dart
PeekTalkerAdapter(
  peek,
  talker: talker,
  mappers: const [
    HttpTalkerLogMapper(),
    ...PeekTalkerAdapter.defaultMappers,
  ],
);
```

## Limits

- **Only what Talker logged.** A client without a Talker integration is
  invisible here; give it one, or use an adapter of its own, such as
  `peek_dio`.
- **Streamed bodies and file contents** are described rather than read;
  see `peek_dio`.
- **Do not use both** `peek_talker` and `PeekDioInterceptor` on the same
  client: the call would be reported twice, once by each.

See the [repository README](https://github.com/artdima/peek) for the full picture.
