# peek_dio

Reports the calls [Dio](https://pub.dev/packages/dio) makes to
[Peek](https://pub.dev/packages/peek), so they can be read inside the app.

Peek never performs, intercepts or modifies a request of its own. This
package hands Dio's view of a call over and nothing more: the request goes
on as it arrived, and so does the response.

## Install

```yaml
dependencies:
  peek: ^0.1.0
  peek_dio: ^0.1.0
```

## Use

Two lines, once, where the client is built:

```dart
final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
dio.interceptors.add(PeekDioInterceptor(Peek.instance));
```

`Peek.instance` is the default instance, created on first use. An app that
wants its own — with different limits, or one per client — passes it
instead:

```dart
final peek = Peek(options: PeekOptions(enabled: kDebugMode));
dio.interceptors.add(PeekDioInterceptor(peek));
```

Then show it, from a debug menu or a shake:

```dart
showPeek(context, peek: peek);
```

The compiled version of these lines lives in
[`example/lib/dio_setup.dart`](../../example/lib/dio_setup.dart).

## Add it last

Interceptors run in the order they were added. Added last, Peek reports the
call as it went out — with the tokens and correlation ids the interceptors
before it put on the request. Added first, it would report the call as it
was written. `LogInterceptor` asks for the same place, for the same reason.

```dart
dio.interceptors
  ..add(AuthInterceptor())
  ..add(RetryInterceptor())
  ..add(PeekDioInterceptor(peek)); // last
```

A retry interceptor that builds fresh `RequestOptions` produces a second
entry, because a second call is what happened.

## What is not captured

- **Streamed bodies.** A request or response Dio never buffers is marked as
  streamed rather than read: reading it would consume the stream the app is
  about to use.
- **File contents in a `FormData`.** Only the part's name, file name, media
  type and size are kept.
- **Anything past the limits.** A body larger than `PeekLimits.maxBodyBytes`
  is truncated, and the entry says so.

## Redaction

Peek shows a call as it happened: nothing is masked unless the app asks.
What is hidden is Peek's decision, not the adapter's, so it is configured on
the instance and applies to every adapter at once. The default policy
covers the usual names — `Authorization`, `Cookie`, `token`, `password`
and their relatives:

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
screen, the clipboard or an exported file. Worth turning on wherever a log
leaves the device — a HAR attached to an issue, a screenshot in a chat.

See the [repository README](../../README.md) for the full picture.
