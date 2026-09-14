/// Reports the calls Chopper makes to Peek.
///
/// Chopper hands an interceptor the rest of the chain to call, so this
/// package watches a call from one `intercept`: the request as it goes out,
/// and whatever comes back. It maps Chopper's objects onto Peek's events and
/// does nothing else — what is kept, redacted and shown is Peek's to decide,
/// and the call itself passes through untouched.
///
/// It imports `package:peek/core.dart` rather than `package:peek/peek.dart`,
/// so an adapter never drags the user interface — or Flutter — in with it,
/// and it stays clear of `dart:io`, because Chopper runs on the web too.
library;

export 'src/peek_chopper_interceptor.dart';
export 'src/peek_chopper_mapper.dart';
