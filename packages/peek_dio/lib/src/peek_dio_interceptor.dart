import 'package:dio/dio.dart';
import 'package:peek/core.dart';

import 'peek_dio_mapper.dart';

/// Reports the calls a `Dio` instance makes to Peek.
///
/// ```dart
/// final peek = Peek();
/// dio.interceptors.add(PeekDioInterceptor(peek));
/// ```
///
/// Add it **last**. Interceptors run in the order they were added, so one
/// added last sees the headers the ones before it put on the request —
/// tokens, correlation ids — which is what a reader is looking for. Added
/// first, it would report the call as it was written rather than as it went
/// out. `LogInterceptor` asks for the same place, for the same reason.
///
/// The interceptor never changes what passes through it: the request goes
/// on as it arrived, and so does the response. A call is followed by the
/// identity of its [RequestOptions] rather than by a mark left in
/// `extra`, so nothing in the request carries Peek's fingerprints. A retry
/// interceptor that builds fresh options therefore reports a second call,
/// which is what happened.
///
/// Nothing here can break a request: a mapper that chokes on an unusual
/// payload hands the error to [PeekSink.reportAdapterError], and the call
/// carries on either way.
final class PeekDioInterceptor extends Interceptor {
  /// Creates an interceptor reporting into [sink].
  ///
  /// [clock] stamps the events; when [sink] is a [Peek], its own clock is
  /// used, so a test that stops one stops the other too.
  PeekDioInterceptor(this.sink, {PeekClock? clock})
    : clock =
          clock ??
          (sink is Peek ? sink.options.clock : const PeekSystemClock());

  /// The name this adapter reports itself under.
  static const String source = PeekDioMapper.client;

  /// Where the calls are reported.
  final PeekSink sink;

  /// What stamps the events.
  final PeekClock clock;

  final Expando<PeekId> _ids = Expando<PeekId>('peek_dio');

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _guard(() {
      final id = PeekId.generate();
      final started = PeekRequestStarted(
        id: id,
        timestamp: clock.now(),
        request: PeekDioMapper.request(options),
        source: source,
      );
      sink.report(started);
      // Remembered only once the start is reported: an id handed out for a
      // call Peek never saw begin would report an answer to nothing.
      _ids[options] = id;
    });
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _guard(() {
      final id = _ids[response.requestOptions];
      if (id == null) return;
      sink.report(
        PeekResponseReceived(
          id: id,
          timestamp: clock.now(),
          response: PeekDioMapper.response(response),
        ),
      );
    });
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _guard(() {
      final id = _ids[err.requestOptions];
      if (id == null) return;
      final response = err.response;
      sink.report(
        PeekRequestFailed(
          id: id,
          timestamp: clock.now(),
          failure: PeekDioMapper.failure(err),
          response: response == null ? null : PeekDioMapper.response(response),
        ),
      );
    });
    handler.next(err);
  }

  void _guard(void Function() report) {
    try {
      report();
    } on Object catch (error, stackTrace) {
      sink.reportAdapterError(error, stackTrace);
    }
  }
}
