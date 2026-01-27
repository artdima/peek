import 'peek_event.dart';

/// Where adapters send what they observe.
///
/// For every call an adapter reports one [PeekRequestStarted] when the
/// request goes out and exactly one [PeekResponseReceived] or
/// [PeekRequestFailed] when it ends, all with the same [PeekEvent.id] drawn
/// from `PeekId.generate()`. A source that only learns about calls after the
/// fact reports a single [PeekEntryRecorded] instead.
///
/// [report] is synchronous, cheap and never throws: adapters call it from
/// inside network interceptors, and Peek must never slow down or break a
/// request. Out-of-order and unknown ids are not errors — a response whose
/// request Peek never saw is recorded as such.
///
/// When the adapter itself fails — a mapper choked on an unusual payload —
/// it hands the error to [reportAdapterError] instead of letting it escape
/// into the client's code.
abstract interface class PeekSink {
  /// Records [event]. Never throws.
  void report(PeekEvent event);

  /// Records that the adapter hit [error] while observing a call. Never
  /// throws.
  void reportAdapterError(Object error, StackTrace stackTrace);
}
