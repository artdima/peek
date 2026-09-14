# Changelog

## Unreleased

The first release: `PeekChopperInterceptor`, which reports the calls a
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
