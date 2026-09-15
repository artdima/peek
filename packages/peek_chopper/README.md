# peek_chopper

Reports the calls [Chopper](https://pub.dev/packages/chopper) makes to
[Peek](https://pub.dev/packages/peek), so they can be read inside the app.

Peek never performs, intercepts or modifies a request of its own. This
package hands Chopper's view of a call over and nothing more: the request
goes on as it arrived, and so does the response.

## Install

```yaml
dependencies:
  peek: ^1.0.0
  peek_chopper: ^1.1.0
```

## Use

One interceptor, where the client is built:

```dart
final client = ChopperClient(
  baseUrl: Uri.parse('https://api.example.com'),
  interceptors: [PeekChopperInterceptor(Peek.instance)],
);
```

`Peek.instance` is the default instance, created on first use. An app that
wants its own — with different limits, or one per client — passes it
instead:

```dart
final peek = Peek(options: PeekOptions(enabled: kDebugMode));
final client = ChopperClient(
  baseUrl: Uri.parse('https://api.example.com'),
  interceptors: [PeekChopperInterceptor(peek)],
);
```

Then show it, from a debug menu or a shake:

```dart
showPeek(context, peek: peek);
```

The compiled version of these lines lives in
[`example/peek_chopper_example.dart`](https://github.com/artdima/peek/blob/main/packages/peek_chopper/example/peek_chopper_example.dart).

## Add it last

Interceptors run in the order they are listed. Listed last, Peek reports the
call as it went out — with the tokens and correlation ids the interceptors
before it put on the request. Listed first, it would report the call as it
was written.

```dart
ChopperClient(
  baseUrl: baseUrl,
  interceptors: [
    AuthInterceptor(),
    RetryInterceptor(),
    PeekChopperInterceptor(peek), // last
  ],
);
```

A call that goes through the chain a second time is reported as a second
entry, because a second call is what happened.

## A refused status is an answer

Chopper returns `404` and `500` as responses rather than throwing, and Peek
records them as such: an entry with a status in the colour of its class, the
server's payload in the body. Only what the chain throws — a broken
connection, a timeout, an aborted call — ends an entry as a failure.

`ChopperHttpException` is raised by the generated service after the chain is
over, so the entry is already recorded as a response by the time your code
sees the exception.

## What is not captured

- **Streamed bodies.** A request or response that was never buffered is
  marked as streamed rather than read: reading it would consume the stream
  the app is about to use.
- **File contents in a multipart part.** Only the part's name, file name,
  media type and size are kept.
- **Redirects.** `package:http` hands over the answer, not the hops it took
  to reach it, so an entry shows the final response alone.
- **Anything past the limits.** A body larger than `PeekLimits.maxBodyBytes`
  is truncated, and the entry says so.

## Not another logger

[`talker_chopper_logger`](https://pub.dev/packages/talker_chopper_logger)
prints calls; Peek shows them. The two are not alternatives, but running
both puts every call in front of you twice — once in the console, once in
Peek — so keep the one you read.

## Redaction

Peek shows a call as it happened: nothing is masked unless the app asks.
What is hidden is Peek's decision, not the adapter's, so it is configured on
the instance and applies to every adapter at once. The default policy covers
the usual names — `Authorization`, `Cookie`, `token`, `password` and their
relatives:

```dart
final peek = Peek(
  options: const PeekOptions(redaction: PeekRedactionPolicy()),
);
```

Every set of names replaces the built-in one rather than adding to it, so
extend a set by spreading the defaults back in:

```dart
PeekRedactionPolicy(
  headerNames: {...PeekRedactionPolicy.defaultHeaderNames, 'x-api-key'},
  bodyKeys: {...PeekRedactionPolicy.defaultBodyKeys, 'pin'},
)
```

Masking runs before anything is stored, so a masked value never reaches the
screen, the clipboard or an exported file.

See the [repository README](https://github.com/artdima/peek) for the full picture.
