/// Reports the calls a `package:http` client makes to Peek.
///
/// `package:http` has no interceptors: every call goes through
/// `Client.send`, so this package wraps the client the app already has and
/// passes each call on as it came. It maps the client's objects onto Peek's
/// events and does nothing else — what is kept, redacted and shown is Peek's
/// to decide.
///
/// It imports `package:peek/core.dart` rather than `package:peek/peek.dart`,
/// so an adapter never drags the user interface — or Flutter — in with it.
/// `dart:io` is kept to one directory reached only through a conditional
/// import, because `package:http` runs on the web too.
library;

export 'src/peek_http_mapper.dart';
