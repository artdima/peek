import 'package:chopper/chopper.dart';
import 'package:peek/core.dart';

import 'peek_chopper_mapper.dart';

/// Reports the calls a `ChopperClient` makes to Peek.
///
/// ```dart
/// final peek = Peek();
/// final client = ChopperClient(
///   baseUrl: Uri.parse('https://api.example.com'),
///   interceptors: [PeekChopperInterceptor(peek)],
/// );
/// ```
///
/// Add it **last**. Interceptors run in the order they are listed, so one
/// listed last sees the headers the ones before it put on the request —
/// tokens, correlation ids — which is what a reader is looking for. Listed
/// first, it would report the call as it was written rather than as it went
/// out.
///
/// A call is followed inside a single `intercept`, so nothing is remembered
/// between calls and nothing is written into the request to tie the two ends
/// together. A retry that goes through the chain again is reported as a
/// second call, which is what happened.
///
/// A status the server refused is an answer, not a failure: `404` is
/// reported as a response and shown in the colour of its class. Only what
/// the chain throws — a broken connection, a timeout, an abort — ends a call
/// as a failure.
///
/// Nothing here can break a request: the mapping and the reporting sit in
/// their own `try`, while `chain.proceed` is called outside it, so an
/// adapter that chokes hands the error to [PeekSink.reportAdapterError] and
/// the call carries on. The response returned is the one that arrived, and
/// an error is rethrown as it was.
final class PeekChopperInterceptor implements Interceptor {
  /// Creates an interceptor reporting into [sink].
  ///
  /// [clock] stamps the events; when [sink] is a [Peek], its own clock is
  /// used, so a test that stops one stops the other too.
  PeekChopperInterceptor(this.sink, {PeekClock? clock})
    : clock =
          clock ??
          (sink is Peek ? sink.options.clock : const PeekSystemClock());

  /// The name this adapter reports itself under.
  static const String source = PeekChopperMapper.client;

  /// Where the calls are reported.
  final PeekSink sink;

  /// What stamps the events.
  final PeekClock clock;

  @override
  Future<Response<BodyType>> intercept<BodyType>(Chain<BodyType> chain) async {
    final request = chain.request;
    final id = PeekId.generate();
    // An answer is only worth reporting under an id the call was given: if
    // the start never landed, neither does its ending.
    var started = false;

    _guard(() {
      sink.report(
        PeekRequestStarted(
          id: id,
          timestamp: clock.now(),
          request: PeekChopperMapper.request(request),
          source: source,
        ),
      );
      started = true;
    });

    try {
      final response = await chain.proceed(request);
      if (started) {
        _guard(
          () => sink.report(
            PeekResponseReceived(
              id: id,
              timestamp: clock.now(),
              response: PeekChopperMapper.response(response),
            ),
          ),
        );
      }
      return response;
    } on Object catch (error, stackTrace) {
      if (started) {
        _guard(
          () => sink.report(
            PeekRequestFailed(
              id: id,
              timestamp: clock.now(),
              failure: PeekChopperMapper.failure(error, stackTrace),
              response: PeekChopperMapper.responseOf(error),
            ),
          ),
        );
      }
      rethrow;
    }
  }

  void _guard(void Function() report) {
    try {
      report();
    } on Object catch (error, stackTrace) {
      sink.reportAdapterError(error, stackTrace);
    }
  }
}
