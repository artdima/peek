import 'package:dio/dio.dart';
import 'package:peek/core.dart';
import 'package:peek_dio/peek_dio.dart';
import 'package:talker/talker.dart';
import 'package:talker_dio_logger/dio_logs.dart';

import 'peek_talker_log_mapper.dart';

/// Maps the logs `talker_dio_logger` writes onto Peek's events.
///
/// The three logs of one call — request, response, error — carry the same
/// `RequestOptions` object, which is what keeps them under one id.
///
/// Peek reads the objects in the log, not the text of it:
/// `TalkerDioLoggerSettings` decides what the console prints, so turning
/// `printRequestData` off hides a body from the console and changes nothing
/// here. What Peek keeps and hides is set on the `Peek` instance, through
/// `PeekOptions`.
final class DioTalkerLogMapper implements PeekTalkerLogMapper {
  /// Creates the mapper.
  const DioTalkerLogMapper();

  @override
  bool canMap(TalkerData data) =>
      data is DioRequestLog || data is DioResponseLog || data is DioErrorLog;

  @override
  PeekEvent? map(TalkerData data, PeekTalkerContext context) => switch (data) {
    final DioRequestLog log => _started(log, context),
    final DioResponseLog log => _received(log, context),
    final DioErrorLog log => _failed(log, context),
    _ => null,
  };

  PeekEvent _started(DioRequestLog log, PeekTalkerContext context) =>
      PeekRequestStarted(
        id: context.begin(log.requestOptions),
        timestamp: log.time,
        request: PeekDioMapper.request(log.requestOptions),
        source: _source(context),
      );

  PeekEvent _received(DioResponseLog log, PeekTalkerContext context) {
    final id = context.find(log.response.requestOptions);
    if (id != null) {
      return PeekResponseReceived(
        id: id,
        timestamp: log.time,
        response: PeekDioMapper.response(log.response),
      );
    }

    return PeekEntryRecorded(
      _whole(
        request: log.response.requestOptions,
        completedAt: log.time,
        elapsed: log.responseTime,
        source: _source(context),
        response: PeekDioMapper.response(log.response),
      ),
    );
  }

  PeekEvent _failed(DioErrorLog log, PeekTalkerContext context) {
    final error = log.dioException;
    final answer = error.response;
    final response = answer == null ? null : PeekDioMapper.response(answer);
    final id = context.find(error.requestOptions);
    if (id != null) {
      return PeekRequestFailed(
        id: id,
        timestamp: log.time,
        failure: PeekDioMapper.failure(error),
        response: response,
      );
    }

    return PeekEntryRecorded(
      _whole(
        request: error.requestOptions,
        completedAt: log.time,
        elapsed: log.responseTime,
        source: _source(context),
        response: response,
        failure: PeekDioMapper.failure(error),
      ),
    );
  }

  // A call whose start Peek never saw is reported whole. Talker knows how
  // long it took, so the start is placed that far back rather than made up.
  static PeekEntry _whole({
    required RequestOptions request,
    required DateTime completedAt,
    required int? elapsed,
    required String source,
    PeekResponse? response,
    PeekFailure? failure,
  }) => PeekEntry(
    id: PeekId.generate(),
    request: PeekDioMapper.request(request),
    startedAt:
        elapsed == null
            ? completedAt
            : completedAt.subtract(Duration(milliseconds: elapsed)),
    source: source,
    response: response,
    failure: failure,
    completedAt: completedAt,
  );

  static String _source(PeekTalkerContext context) =>
      '${context.source}/${PeekDioMapper.client}';
}
