import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';
import 'package:peek_talker/peek_talker.dart';
import 'package:talker/talker.dart';
import 'package:talker_dio_logger/dio_logs.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';

/// A sink that keeps what it was told, so a test can read it back.
final class RecordingSink implements PeekSink {
  final List<PeekEvent> events = [];
  final List<Object> errors = [];

  @override
  void report(PeekEvent event) => events.add(event);

  @override
  void reportAdapterError(Object error, StackTrace stackTrace) =>
      errors.add(error);
}

/// Answers requests without a network.
final class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.answer);

  final FutureOr<ResponseBody> Function(RequestOptions options) answer;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => answer(options);

  @override
  void close({bool force = false}) {}
}

void main() {
  late RecordingSink sink;
  late Talker talker;

  setUp(() {
    sink = RecordingSink();
    talker = Talker();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  Dio dioAnswering(FutureOr<ResponseBody> Function(RequestOptions) answer) =>
      Dio(BaseOptions(baseUrl: 'https://api.example.com'))
        ..httpClientAdapter = FakeAdapter(answer)
        ..interceptors.add(TalkerDioLogger(talker: talker));

  ResponseBody ok(String body, {int statusCode = 200}) =>
      ResponseBody.fromString(
        body,
        statusCode,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );

  test('reports a call Talker logged, start and end under one id', () async {
    final adapter = PeekTalkerAdapter(sink, talker: talker);
    addTearDown(adapter.dispose);
    final dio = dioAnswering((_) => ok('{"id":7}'));

    await dio.get<dynamic>('/users');
    await settle();

    expect(sink.errors, isEmpty);
    final started = sink.events.whereType<PeekRequestStarted>().single;
    final received = sink.events.whereType<PeekResponseReceived>().single;
    expect(started.source, 'talker/dio');
    expect(started.request.method, 'GET');
    expect(started.request.uri.path, '/users');
    expect(received.id, started.id);
    expect(received.response.statusCode, 200);
    expect((received.response.body as PeekTextBody).text, '{"id":7}');
  });

  test('reports what went wrong, with the answer that came with it', () async {
    final adapter = PeekTalkerAdapter(sink, talker: talker);
    addTearDown(adapter.dispose);
    final dio = dioAnswering((_) => ok('{"error":"gone"}', statusCode: 404));

    await expectLater(
      dio.get<dynamic>('/missing'),
      throwsA(isA<DioException>()),
    );
    await settle();

    final started = sink.events.whereType<PeekRequestStarted>().single;
    final failed = sink.events.whereType<PeekRequestFailed>().single;
    expect(failed.id, started.id);
    expect(failed.failure.kind, PeekFailureKind.badResponse);
    expect(failed.response?.statusCode, 404);
  });

  test('reports an orphan response whole, starting where it began', () {
    final options = RequestOptions(
      path: '/users',
      baseUrl: 'https://api.example.com',
    );
    final context = PeekTalkerContext(source: 'talker');
    final log = DioResponseLog(
      'answer',
      response: Response<dynamic>(
        requestOptions: options,
        statusCode: 200,
        data: const {'id': 7},
      ),
      settings: const TalkerDioLoggerSettings(),
    );

    final event = const DioTalkerLogMapper().map(log, context);

    final recorded = (event as PeekEntryRecorded).entry;
    expect(recorded.source, 'talker/dio');
    expect(recorded.request.uri.path, '/users');
    expect(recorded.response?.statusCode, 200);
    expect(recorded.completedAt, isNotNull);
    expect(recorded.startedAt, lessThanOrEqualTo(recorded.completedAt!));
  });

  test('replays what Talker logged before it was attached', () async {
    final dio = dioAnswering((_) => ok('{"id":7}'));
    await dio.get<dynamic>('/users');
    await settle();

    final adapter = PeekTalkerAdapter(sink, talker: talker);
    addTearDown(adapter.dispose);

    expect(sink.events.whereType<PeekRequestStarted>(), hasLength(1));
    expect(sink.events.whereType<PeekResponseReceived>(), hasLength(1));
  });

  test('claims the logs it knows and no others', () {
    const mapper = DioTalkerLogMapper();
    final options = RequestOptions(path: '/users');

    expect(
      mapper.canMap(
        DioRequestLog(
          'call',
          requestOptions: options,
          settings: const TalkerDioLoggerSettings(),
        ),
      ),
      isTrue,
    );
    expect(mapper.canMap(TalkerData('an ordinary message')), isFalse);
  });
}
