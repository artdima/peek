/// Reports the calls Talker logs to Peek.
///
/// An app that already logs through Talker has its network calls in
/// `talker.stream`; this package listens there and maps what it finds onto
/// Peek's events, so nothing has to be logged twice.
///
/// It imports `package:peek/core.dart` rather than `package:peek/peek.dart`,
/// so an adapter never drags the user interface — or Flutter — in with it.
library;

export 'src/dio_talker_log_mapper.dart';
export 'src/peek_talker_adapter.dart';
export 'src/peek_talker_log_mapper.dart';
