# peek_http

Reports the calls a [`package:http`](https://pub.dev/packages/http) client
makes to [Peek](https://pub.dev/packages/peek), so they can be read inside
the app.

Peek never performs, intercepts or modifies a request of its own. This
package will hand the client's view of a call over and nothing more: the
request goes on as it arrived, and so do the response and its bytes.

> Being built. The client lands in the next commits; until then this
> package holds nothing worth depending on.

See the [repository README](https://github.com/artdima/peek) for the full picture.
