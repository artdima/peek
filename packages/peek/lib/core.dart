/// The pure-Dart core of Peek: the network-call model, the adapter contract
/// and the in-memory store.
///
/// Adapter packages import this library and nothing else — it never depends
/// on Flutter.
library;

export 'src/core/model/peek_cookie.dart';
export 'src/core/model/peek_headers.dart';
export 'src/core/model/peek_id.dart';
export 'src/core/peek_clock.dart';
