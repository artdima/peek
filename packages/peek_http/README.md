# peek_http

Reports the calls a [`package:http`](https://pub.dev/packages/http) client
makes to [Peek](https://pub.dev/packages/peek), so they can be read inside
the app.

Peek never performs, intercepts or modifies a request of its own. This
package hands the client's view of a call over and nothing more: the request
goes on as it arrived, and so do the response and its bytes.

## Install

```yaml
dependencies:
  peek: ^1.0.0
  peek_http: ^1.2.0
```

## Use

`package:http` has no interceptors, so Peek wraps the client the app already
has:

```dart
final client = PeekHttpClient(Peek.instance, http.Client());
```

`Peek.instance` is the default instance, created on first use. An app that
wants its own — with different limits, or one per client — passes it
instead:

```dart
final peek = Peek(options: PeekOptions(enabled: kDebugMode));
final client = PeekHttpClient(peek, http.Client());
```

Then show it, from a debug menu or a shake:

```dart
showPeek(context, peek: peek);
```

Any `Client` can be wrapped the same way — `IOClient`, `BrowserClient`,
[`cupertino_http`](https://pub.dev/packages/cupertino_http)'s or
[`cronet_http`](https://pub.dev/packages/cronet_http)'s. The response keeps
its type: an `IOStreamedResponse` still detaches its socket.

The compiled version of these lines lives in
[`example/peek_http_example.dart`](https://github.com/artdima/peek/blob/main/packages/peek_http/example/peek_http_example.dart).

### Code that calls `http.get`

The top-level functions build a `Client()` of their own. `runWithClient`
decides what that is, so wrap the app once:

```dart
void main() {
  http.runWithClient(
    () => runApp(const App()),
    () => PeekHttpClient(Peek.instance, http.Client()),
  );
}
```

`http.Client()` inside the factory is the default client, not the factory
again, so this does not recurse.

## An entry ends when the body is read

The body of a `package:http` response is a stream the app reads after the
headers arrive. Peek passes it through untouched and keeps the first bytes
on the way, so an entry is complete once the app has read the body:

- read to the end — a response, with its body;
- failed part-way, an aborted call say — a failure, with what came before;
- dropped by the app part-way — a response with what was read, marked as
  cut short.

A body nobody reads leaves its entry pending, which is the truth: the call
is not over, and the connection is still held.

A timeout the app puts on the future — `client.send(request).timeout(...)` —
stops the app waiting, not the call: `package:http` has no way to be told.
The entry stays pending until the client underneath gives up, and ends as
whatever that client reports. A timeout set on the client itself, such as
`HttpClient.connectionTimeout` for an `IOClient`, ends the call where it
happens.

## Where it goes among other clients

Clients that wrap clients run from the outside in, and Peek reports what it
sees at its place in the chain.

**Next to the transport** — the usual choice. Peek sees the headers every
outer client added, and every attempt a retrying client makes:

```dart
final client = AuthClient(
  RetryClient(PeekHttpClient(peek, http.Client())),
);
```

`RetryClient` sends each attempt as a fresh streamed copy of the request, so
from here the request body is shown as streamed rather than read.

**Outside `RetryClient`** — when the request body matters more than the
attempts. Peek sees the request as the app wrote it, body included, and one
entry per call with the final answer:

```dart
final client = AuthClient(
  PeekHttpClient(peek, RetryClient(http.Client())),
);
```

## A refused status is an answer

`404` and `500` arrive as responses, and Peek records them as such: an entry
with a status in the colour of its class, the server's payload in the body.
Only what the client throws — a refused connection, an aborted call — ends
an entry as a failure.

## What is not captured

- **Streamed request bodies.** A `StreamedRequest` is marked as streamed:
  its stream belongs to the client sending it.
- **File contents in a multipart request.** Only the field, file name, media
  type and size are kept.
- **Redirects.** `package:http` hands over the final response, not the hops
  it took to reach it.
- **Anything past the limits.** A body larger than `PeekLimits.maxBodyBytes`
  is truncated, and the entry says so.

## Not another logger

A logging client prints calls; Peek shows them. The two are not
alternatives, but running both puts every call in front of you twice — once
in the console, once in Peek — so keep the one you read.

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
