import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';
import 'package:peek_talker/peek_talker.dart';
import 'package:talker/talker.dart';

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

/// A log a mapper can claim, carrying the call it is about.
final class CallLog extends TalkerLog {
  CallLog(super.message, {required this.call});

  final Object call;

  @override
  String get key => 'call';
}

/// Claims [CallLog]s and reports a start for each.
final class CallMapper implements PeekTalkerLogMapper {
  const CallMapper({this.silent = false});

  /// Whether the mapper claims logs but reports nothing about them.
  final bool silent;

  @override
  bool canMap(TalkerData data) => data is CallLog;

  @override
  PeekEvent? map(TalkerData data, PeekTalkerContext context) {
    if (silent) return null;
    final log = data as CallLog;
    return PeekRequestStarted(
      id: context.begin(log.call),
      timestamp: data.time,
      request: PeekRequest(
        method: 'GET',
        uri: Uri.parse('https://api.example.com/${data.message}'),
      ),
      source: context.source,
    );
  }
}

/// Claims everything and raises on it.
final class BrokenMapper implements PeekTalkerLogMapper {
  const BrokenMapper();

  @override
  bool canMap(TalkerData data) => true;

  @override
  PeekEvent? map(TalkerData data, PeekTalkerContext context) =>
      throw StateError('cannot map');
}

void main() {
  late RecordingSink sink;
  late Talker talker;

  setUp(() {
    sink = RecordingSink();
    talker = Talker();
  });

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('reports what a mapper claims and leaves the rest alone', () async {
    final adapter = PeekTalkerAdapter(
      sink,
      talker: talker,
      mappers: const [CallMapper()],
    );
    addTearDown(adapter.dispose);

    talker
      ..logCustom(CallLog('users', call: Object()))
      ..info('nothing to do with the network');
    await settle();

    expect(sink.events, hasLength(1));
    expect(sink.errors, isEmpty);
    final started = sink.events.single as PeekRequestStarted;
    expect(started.request.uri.path, '/users');
    expect(started.source, 'talker');
  });

  test('a mapper may claim a log and report nothing', () async {
    final adapter = PeekTalkerAdapter(
      sink,
      talker: talker,
      mappers: const [CallMapper(silent: true)],
    );
    addTearDown(adapter.dispose);

    talker.logCustom(CallLog('users', call: Object()));
    await settle();

    expect(sink.events, isEmpty);
    expect(sink.errors, isEmpty);
  });

  test('the first mapper to claim an entry is the one that maps it', () async {
    final adapter = PeekTalkerAdapter(
      sink,
      talker: talker,
      mappers: const [CallMapper(), BrokenMapper()],
    );
    addTearDown(adapter.dispose);

    talker.logCustom(CallLog('users', call: Object()));
    await settle();

    expect(sink.events, hasLength(1));
    expect(sink.errors, isEmpty);
  });

  test('replays what was logged before it existed, oldest first', () async {
    talker.logCustom(CallLog('first', call: Object()));
    await Future<void>.delayed(const Duration(milliseconds: 2));
    talker.logCustom(CallLog('second', call: Object()));
    await settle();

    final adapter = PeekTalkerAdapter(
      sink,
      talker: talker,
      mappers: const [CallMapper()],
    );
    addTearDown(adapter.dispose);

    expect(
      sink.events.cast<PeekRequestStarted>().map(
        (event) => event.request.uri.path,
      ),
      ['/first', '/second'],
    );
  });

  test('leaves the history alone when it is not asked for it', () async {
    talker.logCustom(CallLog('first', call: Object()));
    await settle();

    final adapter = PeekTalkerAdapter(
      sink,
      talker: talker,
      mappers: const [CallMapper()],
      replayHistory: false,
    );
    addTearDown(adapter.dispose);

    expect(sink.events, isEmpty);

    talker.logCustom(CallLog('second', call: Object()));
    await settle();
    expect(sink.events, hasLength(1));
  });

  test('hands a mapper that raises to the sink, not back to Talker', () async {
    final adapter = PeekTalkerAdapter(
      sink,
      talker: talker,
      mappers: const [BrokenMapper()],
    );
    addTearDown(adapter.dispose);

    talker.logCustom(CallLog('users', call: Object()));
    await settle();

    expect(sink.events, isEmpty);
    expect(sink.errors.single, isA<StateError>());
  });

  test('stops listening when disposed, twice over', () async {
    final adapter = PeekTalkerAdapter(
      sink,
      talker: talker,
      mappers: const [CallMapper()],
    )..dispose();
    adapter.dispose();

    talker.logCustom(CallLog('users', call: Object()));
    await settle();

    expect(sink.events, isEmpty);
    expect(adapter.name, 'talker');
  });

  test('keeps a call under one id from one log to the next', () {
    final context = PeekTalkerContext(source: 'talker');
    final call = Object();

    expect(context.find(call), isNull);
    final id = context.begin(call);
    expect(context.find(call), id);
    expect(context.find(Object()), isNull);
  });
}
