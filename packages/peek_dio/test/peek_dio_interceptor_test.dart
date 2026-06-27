import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';
import 'package:peek_dio/peek_dio.dart';

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

/// Answers requests without a network, the way Dio's own tests do.
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

/// A header value that cannot be printed, so the mapper raises on it.
final class Unprintable {
  const Unprintable();

  @override
  String toString() => throw StateError('cannot print');
}

void main() {
  late RecordingSink sink;
  late PeekFakeClock clock;
  late Dio dio;

  Dio dioAnswering(FutureOr<ResponseBody> Function(RequestOptions) answer) {
    final client =
        Dio(BaseOptions(baseUrl: 'https://api.example.com'))
          ..httpClientAdapter = FakeAdapter(answer)
          ..interceptors.add(PeekDioInterceptor(sink, clock: clock));
    return client;
  }

  ResponseBody ok(String body, {int statusCode = 200}) =>
      ResponseBody.fromString(
        body,
        statusCode,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );

  setUp(() {
    sink = RecordingSink();
    clock = PeekFakeClock();
  });

  test('reports a call that came back', () async {
    dio = dioAnswering((_) => ok('{"id":7}'));

    final response = await dio.get<dynamic>('/users');

    expect(response.statusCode, 200);
    expect(sink.errors, isEmpty);
    expect(sink.events, hasLength(2));

    final started = sink.events.first as PeekRequestStarted;
    final received = sink.events.last as PeekResponseReceived;
    expect(started.source, 'dio');
    expect(started.request.method, 'GET');
    expect(started.request.uri.path, '/users');
    expect(received.id, started.id);
    expect(received.response.statusCode, 200);
    expect((received.response.body as PeekTextBody).text, '{"id":7}');
  });

  test('reports a status the client rejects, with what came with it', () async {
    dio = dioAnswering((_) => ok('{"error":"gone"}', statusCode: 404));

    await expectLater(
      dio.get<dynamic>('/missing'),
      throwsA(isA<DioException>()),
    );

    final failed = sink.events.last as PeekRequestFailed;
    expect(failed.failure.kind, PeekFailureKind.badResponse);
    expect(failed.response?.statusCode, 404);
    expect((failed.response!.body as PeekTextBody).text, '{"error":"gone"}');
  });

  test('reports a call that ran out of time', () async {
    dio = dioAnswering(
      (options) =>
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.receiveTimeout,
            message: 'Receive timed out',
          ),
    );

    await expectLater(dio.get<dynamic>('/slow'), throwsA(isA<DioException>()));

    final failed = sink.events.last as PeekRequestFailed;
    expect(failed.failure.kind, PeekFailureKind.timeout);
    expect(failed.failure.message, 'Receive timed out');
    expect(failed.response, isNull);
  });

  test('reports a call the app called off', () async {
    final token = CancelToken();
    dio = dioAnswering((_) async {
      token.cancel();
      await Future<void>.delayed(Duration.zero);
      return ok('{}');
    });

    await expectLater(
      dio.get<dynamic>('/slow', cancelToken: token),
      throwsA(isA<DioException>()),
    );

    final failed = sink.events.last as PeekRequestFailed;
    expect(failed.failure.kind, PeekFailureKind.cancelled);
  });

  test('a retry is a second call, because that is what happened', () async {
    var attempts = 0;
    dio = dioAnswering((_) {
      attempts++;
      return ok('{"attempt":$attempts}', statusCode: attempts == 1 ? 500 : 200);
    });
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          if (error.response?.statusCode != 500) return handler.next(error);
          handler.resolve(await dio.fetch<dynamic>(error.requestOptions));
        },
      ),
    );

    final response = await dio.get<dynamic>('/flaky');

    expect(response.statusCode, 200);
    final ids = sink.events.map((event) => event.id).toSet();
    expect(ids, hasLength(2));
    expect(sink.events.whereType<PeekRequestStarted>(), hasLength(2));
    expect(sink.events.whereType<PeekRequestFailed>(), hasLength(1));
    expect(sink.events.whereType<PeekResponseReceived>(), hasLength(1));
  });

  test('a mapper that raises does not break the call', () async {
    dio = dioAnswering((_) => ok('{"id":7}'));

    final response = await dio.get<dynamic>(
      '/users',
      options: Options(headers: {'X-Odd': const Unprintable()}),
    );

    expect(response.statusCode, 200);
    expect(sink.errors, hasLength(1));
    expect(sink.errors.single, isA<StateError>());
    // The request was never reported, so neither is its answer: an id it
    // was never given is an id it cannot report under.
    expect(sink.events, isEmpty);
  });

  test('changes neither the request nor the response', () async {
    late RequestOptions seen;
    dio = dioAnswering((options) {
      seen = options;
      return ok('{"id":7}');
    });

    final response = await dio.get<dynamic>(
      '/users',
      options: Options(headers: {'X-Tag': 'a'}),
    );

    expect(seen.headers['X-Tag'], 'a');
    expect(seen.extra, isEmpty);
    expect(response.data, {'id': 7});
    expect(response.requestOptions.extra, isEmpty);
    expect(
      response.headers.value(Headers.contentTypeHeader),
      'application/json',
    );
  });

  test('stamps events with the clock it was given', () async {
    dio = dioAnswering((_) => ok('{}'));

    await dio.get<dynamic>('/users');
    clock.advance(const Duration(seconds: 5));
    await dio.get<dynamic>('/users');

    final stamps = sink.events.map((event) => event.timestamp).toSet();
    expect(stamps, hasLength(2));
  });

  test('takes its clock from the instance it reports into', () {
    final peek = Peek(
      options: const PeekOptions().copyWith(clock: PeekFakeClock()),
    );
    addTearDown(peek.dispose);

    expect(PeekDioInterceptor(peek).clock, same(peek.options.clock));
  });
}
