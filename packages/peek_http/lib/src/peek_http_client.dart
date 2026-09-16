import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:peek/core.dart';

import 'capturing_stream.dart';
import 'peek_http_mapper.dart';
import 'response_copy.dart' if (dart.library.io) 'io/response_copy.dart';

/// Reports the calls a `package:http` client makes to Peek.
///
/// ```dart
/// final peek = Peek();
/// final client = PeekHttpClient(peek, http.Client());
/// ```
///
/// `package:http` has no interceptors, so this client wraps the one the app
/// already has and hands every call to it as it came. The response the app
/// gets back is the one [inner] returned, with the same type, status and
/// headers; only its body stream is a pass-through that keeps the first
/// bytes on the way. A call ends in Peek when that body has been read — a
/// body nobody reads leaves the call pending, as the connection is.
///
/// Where it sits among other wrapping clients decides what it sees.
/// Innermost, next to the transport, it reports every attempt of a
/// `RetryClient` and every header the outer clients added — but a request
/// that went through `RetryClient` arrives as a stream, so its body is not
/// shown. Outside `RetryClient`, a call is one entry with its request body,
/// and the attempts in between are not seen.
///
/// Nothing here can break a call: mapping and reporting sit in their own
/// `try`, while `inner.send` and the body stream are outside it. An error is
/// rethrown as it came.
final class PeekHttpClient extends http.BaseClient {
  /// Creates a client reporting into [sink] the calls sent through [inner].
  ///
  /// When [sink] is a [Peek], its clock stamps the events and its body limit
  /// caps what is kept of a response.
  PeekHttpClient(this.sink, this.inner, {PeekClock? clock})
    : clock =
          clock ??
          (sink is Peek ? sink.options.clock : const PeekSystemClock());

  /// The name this adapter reports itself under.
  static const String source = PeekHttpMapper.client;

  /// Where the calls are reported.
  final PeekSink sink;

  /// The client that sends the calls.
  final http.Client inner;

  /// What stamps the events.
  final PeekClock clock;

  int get _limit => switch (sink) {
    final Peek peek => peek.options.limits.maxBodyBytes,
    _ => const PeekLimits().maxBodyBytes,
  };

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final id = PeekId.generate();
    // An ending is only worth reporting under an id whose start landed.
    var started = false;

    _guard(() {
      sink.report(
        PeekRequestStarted(
          id: id,
          timestamp: clock.now(),
          request: PeekHttpMapper.request(request),
          source: source,
        ),
      );
      started = true;
    });

    final http.StreamedResponse response;
    try {
      response = await inner.send(request);
    } on Object catch (error, stackTrace) {
      if (started) {
        _guard(
          () => sink.report(
            PeekRequestFailed(
              id: id,
              timestamp: clock.now(),
              failure: PeekHttpMapper.failure(error, stackTrace),
            ),
          ),
        );
      }
      rethrow;
    }
    if (!started) return response;

    try {
      return copyResponse(response, _capture(id, response));
    } on Object catch (error, stackTrace) {
      sink.reportAdapterError(error, stackTrace);
      _guard(
        () => sink.report(
          PeekResponseReceived(
            id: id,
            timestamp: clock.now(),
            response: PeekHttpMapper.response(
              response,
              PeekBody.unavailable(
                PeekBodyUnavailableReason.notCaptured,
                contentType: PeekMediaType.tryParse(
                  response.headers['content-type'],
                ),
              ),
            ),
          ),
        ),
      );
      return response;
    }
  }

  @override
  void close() => inner.close();

  CapturingStream _capture(PeekId id, http.StreamedResponse response) =>
      CapturingStream(
        response.stream,
        limit: _limit,
        onDone:
            (captured, received) => _guard(
              () => sink.report(
                PeekResponseReceived(
                  id: id,
                  timestamp: clock.now(),
                  response: _mapped(response, captured, received),
                ),
              ),
            ),
        onError:
            (error, stackTrace, captured, received) => _guard(
              () => sink.report(
                PeekRequestFailed(
                  id: id,
                  timestamp: clock.now(),
                  failure: PeekHttpMapper.failure(error, stackTrace),
                  response: _mapped(
                    response,
                    captured,
                    _sizeOfCut(response, received),
                  ),
                ),
              ),
            ),
        onCancel:
            (captured, received) => _guard(
              () => sink.report(
                PeekResponseReceived(
                  id: id,
                  timestamp: clock.now(),
                  response: _mapped(
                    response,
                    captured,
                    _sizeOfCut(response, received),
                  ),
                ),
              ),
            ),
      );

  PeekResponse _mapped(
    http.StreamedResponse response,
    List<int> captured,
    int size,
  ) => PeekHttpMapper.response(
    response,
    PeekHttpMapper.responseBody(response, captured, received: size),
  );

  // A body that ended early is as long as the server said, unless it was
  // zipped: then Content-Length counts the wire, not what the app reads.
  static int _sizeOfCut(http.BaseResponse response, int received) {
    final length = response.contentLength;
    final encoding = response.headers['content-encoding'];
    if (length == null || (encoding != null && encoding != 'identity')) {
      return received;
    }
    return math.max(length, received);
  }

  void _guard(void Function() report) {
    try {
      report();
    } on Object catch (error, stackTrace) {
      sink.reportAdapterError(error, stackTrace);
    }
  }
}
