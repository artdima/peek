/// Reports the calls Dio makes to Peek.
///
/// Attach the interceptor to a `Dio` instance and its calls show up in
/// Peek's screens. This package maps Dio's objects onto Peek's events and
/// does nothing else: what is kept, redacted and shown is Peek's to decide.
///
/// It imports `package:peek/core.dart` rather than `package:peek/peek.dart`,
/// so an adapter never drags the user interface — or Flutter — in with it.
library;

export 'src/peek_dio_mapper.dart';
