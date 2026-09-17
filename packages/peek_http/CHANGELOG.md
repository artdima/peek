# Changelog

## 1.2.0

The first release — numbered with the rest of Peek, which moves as one:
`PeekHttpClient`, which reports the calls a `package:http` client makes into
Peek.

- Wraps the client the app already has and passes every call to it as it
  came; an error is rethrown as it was, and a mapping failure reaches
  `PeekOptions.onError`, not the app.
- The response keeps its type — an `IOStreamedResponse` still detaches its
  socket — and its body is a pass-through that keeps the first bytes, up to
  `PeekLimits.maxBodyBytes`.
- An entry ends when the body has been read: a response, a failure part-way
  with what came before, or what was read before the app stopped.
- A status the server refused is recorded as a response; only what the
  client throws ends a call as a failure, an abort before a broken
  connection.
- Describes multipart requests without finalizing them or opening their
  files, keeps `Set-Cookie` values apart, and marks streamed request bodies
  as unavailable.
- `PeekHttpMapper` — the pure mapping from `package:http` objects to Peek's
  model — is public, for other adapters that see those types.
