import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:peek_remote/peek_remote.dart';

import '../support.dart';

/// Writes the reference frames of `doc/spec/` and keeps them honest.
///
/// A plain run compares every file with what this package writes today and
/// fails on any difference; with `--dart-define=PEEK_UPDATE_SPEC=true`
/// (`melos run spec:update`) the files are rewritten instead.
const bool _update = bool.fromEnvironment('PEEK_UPDATE_SPEC');

const String _directory = '../../doc/spec/fixtures/remote';

const PeekRemoteCodec _codec = PeekRemoteCodec();

/// Which way each reference frame travels.
String _direction(PeekRemoteFrame frame) => switch (frame) {
  PeekRemoteWelcome() ||
  PeekRemoteDenied() ||
  PeekRemoteBodyRequest() => 'toApp',
  PeekRemotePing() || PeekRemotePong() => 'either',
  _ => 'toDesktop',
};

Map<String, String> _files() {
  final files = <String, String>{
    for (final MapEntry(key: name, value: frame) in referenceFrames.entries)
      '$name.json': '${_codec.encode(frame)}\n',
    // What a newer peer might send: both must be read, not refused.
    'unknown-type.json': '${jsonEncode({'type': 'hologram', 'depth': 3})}\n',
    'unknown-keys.json':
        '${jsonEncode({
          ...jsonDecode(_codec.encode(hello)) as Map<String, Object?>,
          'addedLater': {'nested': true},
        })}\n',
  };
  final manifest = {
    for (final MapEntry(key: name, value: frame) in referenceFrames.entries)
      '$name.json': {
        'type': _codec.encodeFrame(frame)['type'],
        'direction': _direction(frame),
      },
    'unknown-type.json': {'type': 'hologram', 'ignored': true},
    'unknown-keys.json': {
      'type': 'hello',
      'direction': 'toDesktop',
      'sameAs': 'hello.json',
    },
  };
  files['manifest.json'] =
      '${const JsonEncoder.withIndent('  ').convert(manifest)}\n';
  return files;
}

void main() {
  final files = _files();

  test('the reference frames are what this package writes', () {
    final directory = Directory(_directory);
    if (_update) directory.createSync(recursive: true);
    for (final MapEntry(key: name, value: text) in files.entries) {
      final file = File('$_directory/$name');
      if (_update) {
        file.writeAsStringSync(text);
      } else {
        expect(
          file.existsSync() ? file.readAsStringSync() : null,
          text,
          reason:
              '$name differs from what peek_remote writes; if the change is '
              'meant, run `dart run melos run spec:update`.',
        );
      }
    }
    if (!_update && directory.existsSync()) {
      final extra = [
        for (final file in directory.listSync().whereType<File>())
          if (!files.containsKey(file.uri.pathSegments.last))
            file.uri.pathSegments.last,
      ];
      expect(extra, isEmpty, reason: 'files no test writes');
    }
  });

  test('every reference frame reads back as itself', () {
    for (final MapEntry(key: name, value: frame) in referenceFrames.entries) {
      expect(_codec.decode(files['$name.json']!), frame, reason: name);
    }
    expect(
      _codec.decode(files['unknown-type.json']!),
      const PeekRemoteUnknownFrame('hologram'),
    );
    expect(_codec.decode(files['unknown-keys.json']!), hello);
  });

  test('every file is one line', () {
    for (final MapEntry(key: name, value: text) in files.entries) {
      if (name == 'manifest.json') continue;
      expect('\n'.allMatches(text), hasLength(1), reason: name);
      expect(text, endsWith('\n'), reason: name);
    }
  });
}
