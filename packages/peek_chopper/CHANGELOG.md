# Changelog

## 1.3.0

Released alongside `peek` 1.3.0, which rebuilt its screens. Nothing in this
package changed.

## 1.2.0

Released alongside `peek_http`, the adapter for `package:http`. Nothing in
this package changed.

## 1.1.0

The first release — numbered with the rest of Peek, which moves as one: `PeekChopperInterceptor`, which reports the calls a
`ChopperClient` makes into Peek.

- A passive `Interceptor`: it returns the response the chain produced,
  rethrows an error as it was, and writes nothing into the request — a
  mapping failure reaches `PeekOptions.onError`, not the app.
- A call is followed inside one `intercept`, so nothing has to be
  remembered between calls and a retry is reported as the second call it is.
- A status the server refused is recorded as a response, the way Chopper
  hands it over; only what the chain throws ends a call as a failure.
- Sorts transport errors into Peek's kinds — an aborted call before a broken
  connection, since `RequestAbortedException` is a `ClientException` too.
- Describes multipart parts without opening their files, and marks streamed
  bodies as unavailable rather than draining them.
- `PeekChopperMapper` — the pure mapping from Chopper's objects to Peek's
  model — is public, for other adapters that see Chopper's types.
