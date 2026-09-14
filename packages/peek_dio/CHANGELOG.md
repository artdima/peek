# Changelog

## 1.0.0

The first release: `PeekDioInterceptor`, which reports the calls a Dio
client makes into Peek.

- A passive `Interceptor`: it always passes the call on, never touches
  `RequestOptions`, and swallows nothing — a mapping failure reaches
  `PeekOptions.onError`, not the app.
- Maps every `DioExceptionType`, keeps the server's answer on a failed
  call, follows redirects hop by hop, describes multipart parts without
  reading their files, and marks streamed bodies as unavailable rather than
  draining them.
- `PeekDioMapper` — the pure mapping from Dio's objects to Peek's model — is
  public, for other adapters that see Dio's types.
