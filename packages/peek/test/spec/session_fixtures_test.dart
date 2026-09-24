import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';

import '../support/entries.dart';

/// Writes the reference session files of `doc/spec/` and keeps them honest.
///
/// A plain run compares every file with what Peek writes today and fails on
/// any difference, so a file edited by hand is caught. With
/// `--dart-define=PEEK_UPDATE_SPEC=true` (`melos run spec:update`) the files
/// are rewritten instead.
const bool _update = bool.fromEnvironment('PEEK_UPDATE_SPEC');

const String _directory = '../../doc/spec/fixtures/sessions';

const PeekSessionCodec _codec = PeekSessionCodec();

// Pinned, so a release does not rewrite every reference file.
final PeekSessionHeader _header = PeekSessionHeader(
  name: 'Peek fixtures',
  platform: 'ios',
  osVersion: '18.0',
  startedAt: fixtureStart,
  peekVersion: '2.0.0',
);

// What the UI fixtures do not show: a cut-off body, timing phases, a failure
// with details and a stack trace, and extra request data.
final PeekEntry _truncated = PeekEntry(
  id: const PeekId('spec-truncated'),
  request: PeekRequest(
    method: 'GET',
    uri: Uri.parse('https://api.example.com/export?format=csv'),
  ),
  startedAt: fixtureStart.add(const Duration(seconds: 20)),
  source: 'http',
  response: PeekResponse(
    statusCode: 200,
    headers: PeekHeaders.fromMap({'Content-Type': 'text/csv'}),
    body: PeekBody.text(
      'id,name\n1,Ada\n2,Grace\n',
      contentType: PeekMediaType.tryParse('text/csv'),
      size: 3276800,
    ),
  ),
  completedAt: fixtureStart.add(const Duration(seconds: 21)),
);

final PeekEntry _timed = PeekEntry(
  id: const PeekId('spec-timed'),
  request: PeekRequest(
    method: 'GET',
    uri: Uri.parse('https://api.example.com/profile'),
    headers: PeekHeaders.fromEntries(const [
      MapEntry('Accept', 'application/json'),
      MapEntry('Cookie', 'session=abc'),
      MapEntry('cookie', 'theme=dark'),
    ]),
  ),
  startedAt: fixtureStart.add(const Duration(seconds: 22)),
  source: 'chopper',
  response: PeekResponse(
    statusCode: 200,
    statusMessage: 'OK',
    headers: PeekHeaders.fromEntries(const [
      MapEntry('Content-Type', 'application/json'),
      MapEntry('Set-Cookie', 'session=abc; Path=/; HttpOnly'),
      MapEntry('Set-Cookie', 'theme=dark; Max-Age=3600'),
    ]),
    body: PeekBody.text(
      '{"name":"Ada","city":"Zürich 🏔"}',
      contentType: PeekMediaType.json,
    ),
  ),
  completedAt: fixtureStart.add(
    const Duration(seconds: 22, milliseconds: 187, microseconds: 500),
  ),
  timings: const PeekTimings(
    blocked: Duration(milliseconds: 2),
    dns: Duration(milliseconds: 14),
    connect: Duration(milliseconds: 31),
    ssl: Duration(milliseconds: 48),
    send: Duration(microseconds: 1500),
    wait: Duration(milliseconds: 83),
    receive: Duration(milliseconds: 8),
  ),
);

final PeekEntry _crashed = PeekEntry(
  id: const PeekId('spec-crashed'),
  request: PeekRequest(
    method: 'POST',
    uri: Uri.parse('https://pay.example.com/v1/charges'),
    body: PeekBody.text('{"amount":1200}', contentType: PeekMediaType.json),
    extra: const {'retry': 2, 'traceId': 'a1b2c3'},
  ),
  startedAt: fixtureStart.add(const Duration(seconds: 24)),
  source: 'talker/dio',
  failure: PeekFailure(
    kind: PeekFailureKind.connection,
    message: 'Connection reset by peer',
    details: 'SocketException: Connection reset by peer (OS Error: 54)',
    stackTrace: StackTrace.fromString(
      '#0      PaymentApi.charge '
      '(package:shop/api/payment_api.dart:42:7)\n'
      '<asynchronous suspension>\n'
      '#1      CheckoutCubit.pay '
      '(package:shop/checkout/checkout_cubit.dart:88:5)\n',
    ),
  ),
  completedAt: fixtureStart.add(const Duration(seconds: 25)),
);

final List<PeekEntry> _basic = [...uiFixtures, _truncated, _timed, _crashed];

String _text(Iterable<String> lines) => lines.map((line) => '$line\n').join();

// Keys a newer writer might add, at every level an object can grow, but not
// inside `extra`, where every key is data.
Object? _withUnknownKeys(Object? json) => switch (json) {
  final Map<String, Object?> map => {
    for (final MapEntry(:key, :value) in map.entries)
      key: key == 'extra' ? value : _withUnknownKeys(value),
    'addedLater': {
      'nested': [1, 'two', null],
    },
  },
  final List<Object?> list => [for (final item in list) _withUnknownKeys(item)],
  _ => json,
};

Map<String, String> _files() {
  final basicLines = [for (final entry in _basic) _codec.encodeEntry(entry)];
  final e4Done = PeekEntry(
    id: e4.id,
    request: e4.request,
    startedAt: e4.startedAt,
    source: e4.source,
    response: PeekResponse(
      statusCode: 200,
      body: PeekBody.text(
        'done',
        contentType: PeekMediaType.tryParse('text/plain'),
      ),
    ),
    completedAt: e4.startedAt.add(const Duration(seconds: 9)),
  );
  final e1Line = _codec.encodeEntry(e1);
  final headerMap =
      jsonDecode(_codec.encodeHeader(_header)) as Map<String, Object?>;

  return {
    'basic.peek': _text([_codec.encodeHeader(_header), ...basicLines]),
    'header-only.peek': _text([_codec.encodeHeader(_header)]),
    'broken-line.peek': _text([
      _codec.encodeHeader(_header),
      for (final entry in fixtures.take(3)) _codec.encodeEntry(entry),
      // A write that stopped halfway, and an entry without its request.
      e1Line.substring(0, e1Line.length ~/ 2),
      jsonEncode({
        'id': 'no-request',
        'source': 'dio',
        'startedAt': '2026-09-10T12:00:03.000Z',
      }),
      '',
      for (final entry in fixtures.skip(3)) _codec.encodeEntry(entry),
    ]),
    'appended.peek': _text([
      _codec.encodeHeader(_header),
      _codec.encodeEntry(e4),
      _codec.encodeEntry(e1),
      _codec.encodeEntry(e4Done),
    ]),
    'unknown-keys.peek': _text([
      for (final line in [_codec.encodeHeader(_header), ...basicLines])
        jsonEncode(_withUnknownKeys(jsonDecode(line))),
    ]),
    'future-version.peek': _text([
      jsonEncode({
        ...headerMap,
        'formatVersion': 2,
        'peekVersion': '3.0.0',
        'device': {'model': 'iPhone 17'},
      }),
      _codec.encodeEntry(e1),
      jsonEncode({
        ...jsonDecode(_codec.encodeEntry(e3)) as Map<String, Object?>,
        'response': {
          'status': 200,
          'body': {'kind': 'remote', 'type': 'image/png', 'size': 48213},
        },
      }),
      jsonEncode({
        ...jsonDecode(_codec.encodeEntry(e5)) as Map<String, Object?>,
        'failure': {'kind': 'quotaExceeded', 'message': 'slow'},
      }),
      jsonEncode({'kind': 'marker', 'label': 'login finished'}),
    ]),
    'old-version.peek': _text([
      jsonEncode({...headerMap, 'formatVersion': 0}),
      _codec.encodeEntry(e1),
    ]),
    'not-a-session.peek': _text([
      jsonEncode({
        'log': {'version': '1.2', 'entries': <Object?>[]},
      }),
    ]),
    'empty.peek': '',
  };
}

// What a reader must make of each file: a newer-format flag and the ids in
// order, or an error for the file as a whole.
String _manifest(Map<String, String> files) {
  const reader = PeekSessionReader();
  final manifest = <String, Object?>{};
  for (final MapEntry(:key, :value) in files.entries) {
    try {
      final document = reader.readString(value);
      manifest[key] = {
        'formatVersion': document.header.formatVersion,
        'newerFormat': document.header.isNewerFormat,
        'entries': [for (final entry in document.entries) entry.id.value],
        'skipped': document.skipped,
      };
    } on FormatException {
      manifest[key] = {'error': true};
    }
  }
  return '${const JsonEncoder.withIndent('  ').convert(manifest)}\n';
}

void main() {
  final files = _files();
  final all = {...files, 'manifest.json': _manifest(files)};

  test('the reference session files are up to date', () {
    final directory = Directory(_directory);
    if (_update) directory.createSync(recursive: true);
    for (final MapEntry(key: name, value: text) in all.entries) {
      final file = File('$_directory/$name');
      if (_update) {
        file.writeAsStringSync(text);
        continue;
      }
      expect(
        file.existsSync() ? file.readAsStringSync() : null,
        text,
        reason:
            'doc/spec/fixtures/sessions/$name is stale or edited by hand; '
            'run `dart run melos run spec:update`.',
      );
    }
    if (!_update && directory.existsSync()) {
      final extra = directory
          .listSync()
          .map((file) => file.uri.pathSegments.last)
          .where((name) => !name.startsWith('.') && !all.containsKey(name));
      expect(extra, isEmpty, reason: 'files the spec test does not write');
    }
  });

  group('the reference files read as the spec says', () {
    const reader = PeekSessionReader();
    List<String> ids(PeekSession document) => idsOf(document.entries);

    test('basic holds every entry, in order, nothing lost', () {
      final document = reader.readString(files['basic.peek']!);
      expect(document.header, _header);
      expect(ids(document), idsOf(_basic));
      for (var i = 0; i < _basic.length; i++) {
        expect(
          _codec.encodeEntry(document.entries[i]),
          _codec.encodeEntry(_basic[i]),
        );
      }
    });

    test('unknown keys change nothing', () {
      final plain = reader.readString(files['basic.peek']!);
      final grown = reader.readString(files['unknown-keys.peek']!);
      expect(grown.header, plain.header);
      expect(grown.skipped, 0);
      expect(
        grown.entries.map(_codec.encodeEntry),
        plain.entries.map(_codec.encodeEntry),
      );
    });

    test('broken lines are skipped and counted', () {
      final document = reader.readString(files['broken-line.peek']!);
      expect(ids(document), idsOf(fixtures));
      expect(document.skipped, 2);
    });

    test('a later line replaces the entry in place', () {
      final document = reader.readString(files['appended.peek']!);
      expect(ids(document), ['e4', 'e1']);
      expect(document.entries.first.state, PeekEntryState.completed);
    });

    test('a newer format is read as far as it goes', () {
      final document = reader.readString(files['future-version.peek']!);
      expect(document.header.isNewerFormat, isTrue);
      expect(ids(document), ['e1', 'e3', 'e5']);
      expect(document.skipped, 1);
      expect(
        document.entries[1].response!.body,
        PeekBody.unavailable(
          PeekBodyUnavailableReason.notCaptured,
          contentType: PeekMediaType.tryParse('image/png'),
          size: 48213,
        ),
      );
      expect(document.entries[2].failure!.kind, PeekFailureKind.unknown);
    });

    test('a header alone is an empty session', () {
      final document = reader.readString(files['header-only.peek']!);
      expect(document.entries, isEmpty);
    });

    test('an old, foreign or empty file is refused', () {
      for (final name in [
        'old-version.peek',
        'not-a-session.peek',
        'empty.peek',
      ]) {
        expect(
          () => reader.readString(files[name]!),
          throwsFormatException,
          reason: name,
        );
      }
    });
  });
}
