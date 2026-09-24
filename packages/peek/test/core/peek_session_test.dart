import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';
import 'package:peek/src/core/internal/os_version.dart';

import '../support/entries.dart';

PeekEntry _withId(PeekEntry entry, String id) => PeekEntry(
  id: PeekId(id),
  request: entry.request,
  startedAt: entry.startedAt,
  source: entry.source,
  response: entry.response,
  failure: entry.failure,
  completedAt: entry.completedAt,
  isPinned: entry.isPinned,
  timings: entry.timings,
);

void main() {
  const writer = PeekSessionWriter();
  const reader = PeekSessionReader();
  const codec = PeekSessionCodec();

  final header = PeekSessionHeader(
    name: 'Acme Shop',
    platform: 'ios',
    osVersion: '26.0',
    startedAt: fixtureStart,
  );

  // The UI fixtures over and over, each call with an id of its own.
  final twoHundred = [
    for (var i = 0; i < 200; i++)
      _withId(uiFixtures[i % uiFixtures.length], 'call-$i'),
  ];

  group('PeekSessionWriter and PeekSessionReader', () {
    test('write two hundred calls and read them back in order', () {
      final text = writer.write(header, twoHundred);
      final session = reader.readString(text);

      expect(session.header, header);
      expect(session.entries, twoHundred);
      expect(session.skipped, 0);
      expect(const LineSplitter().convert(text), hasLength(201));
      expect(text, endsWith('\n'));
    });

    test('put the header first and one call on each line', () {
      final multiline = PeekEntry(
        id: const PeekId('note'),
        request: PeekRequest(
          method: 'POST',
          uri: Uri.parse('https://api.example.com/notes'),
          body: PeekBody.text('first\nsecond\r\nthird'),
        ),
        startedAt: fixtureStart,
        source: 'dio',
      );
      final lines = writer.lines(header, [e1, multiline]).toList();

      expect(lines, hasLength(3));
      expect(jsonDecode(lines.first), {
        'format': 'peek',
        'formatVersion': 1,
        'peekVersion': peekVersion,
        'name': 'Acme Shop',
        'platform': 'ios',
        'osVersion': '26.0',
        'startedAt': '2026-09-10T12:00:00.000Z',
      });
      expect(codec.decodeEntry(lines[1]), e1);
      expect(lines.any((line) => line.contains('\n')), isFalse);
      expect(reader.read(lines).entries, [e1, multiline]);
    });

    test('skip a broken line and keep the rest', () {
      final lines =
          writer.lines(header, [e1, e2, e3]).toList()
            ..insert(2, '{"id": "half a li')
            ..insert(3, '{"not": "a call"}');
      final session = reader.read(lines);

      expect(session.entries, [e1, e2, e3]);
      expect(session.skipped, 2);
    });

    test('ignore blank lines, CRLF and a byte order mark', () {
      final text = writer.lines(header, [e1, e2]).join('\r\n');
      expect(reader.readString('$text\r\n\r\n').entries, [e1, e2]);
      expect(reader.readString('\n\n﻿$text').entries, [e1, e2]);
    });

    test('let a later line for a call replace the earlier one in place', () {
      final done = e4.complete(
        PeekResponse(statusCode: 200),
        at: fixtureStart.add(const Duration(seconds: 5)),
      );
      final session = reader.read([
        codec.encodeHeader(header),
        codec.encodeEntry(e4),
        codec.encodeEntry(e1),
        codec.encodeEntry(done),
      ]);

      expect(session.entries, [done, e1]);
      expect(session.skipped, 0);
    });

    test('read a file that holds only a header', () {
      final session = reader.readString(writer.write(header, const []));
      expect(session.header, header);
      expect(session.entries, isEmpty);
      expect(session.skipped, 0);
    });

    test('refuse what is not a session', () {
      expect(() => reader.readString(''), throwsFormatException);
      expect(() => reader.readString('\n\n'), throwsFormatException);
      expect(() => reader.readString('not json'), throwsFormatException);
      expect(() => reader.read([codec.encodeEntry(e1)]), throwsFormatException);
      expect(
        () => reader.readString('{"log": {"version": "1.2"}}'),
        throwsFormatException,
      );
    });

    test('read a newer format as far as it goes and refuse an older one', () {
      final base =
          jsonDecode(codec.encodeHeader(header)) as Map<String, Object?>;
      Map<String, Object?> headerWith(int formatVersion) => {
        ...base,
        'formatVersion': formatVersion,
      };

      final newer = reader.read([
        jsonEncode({...headerWith(2), 'compression': 'none'}),
        codec.encodeEntry(e1),
      ]);
      expect(newer.header.formatVersion, 2);
      expect(newer.header.isNewerFormat, isTrue);
      expect(newer.entries, [e1]);
      expect(header.isNewerFormat, isFalse);

      expect(
        () => reader.read([jsonEncode(headerWith(0))]),
        throwsFormatException,
      );
    });
  });

  group('PeekSessionCodec', () {
    test('leaves out what the header does not know', () {
      final bare = PeekSessionHeader(
        platform: 'android',
        startedAt: fixtureStart,
      );
      final line = codec.encodeHeader(bare);

      expect(jsonDecode(line), {
        'format': 'peek',
        'formatVersion': PeekSessionHeader.currentFormatVersion,
        'peekVersion': peekVersion,
        'platform': 'android',
        'startedAt': '2026-09-10T12:00:00.000Z',
      });
      expect(codec.decodeHeader(line), bare);
    });

    test('refuses a header it cannot read', () {
      final valid =
          jsonDecode(codec.encodeHeader(header)) as Map<String, Object?>;
      String without(String key) => jsonEncode({...valid}..remove(key));

      expect(
        () => codec.decodeHeader(without('format')),
        throwsFormatException,
      );
      expect(
        () => codec.decodeHeader(without('platform')),
        throwsFormatException,
      );
      expect(
        () => codec.decodeHeader(without('startedAt')),
        throwsFormatException,
      );
      expect(
        () => codec.decodeHeader(jsonEncode({...valid, 'name': 42})),
        throwsFormatException,
      );
      expect(
        () => codec.decodeHeader(jsonEncode({...valid, 'startedAt': 'today'})),
        throwsFormatException,
      );
      expect(() => codec.decodeHeader('[]'), throwsFormatException);
    });
  });

  group('PeekSessionHeader', () {
    test('describes the app it runs in', () {
      final current = PeekSessionHeader.current(
        name: 'Acme Shop',
        startedAt: fixtureStart,
      );

      expect(current.platform, Platform.operatingSystem);
      expect(current.name, 'Acme Shop');
      expect(current.peekVersion, peekVersion);
      expect(current.formatVersion, PeekSessionHeader.currentFormatVersion);
      if (Platform.isIOS || Platform.isMacOS) {
        expect(current.osVersion, matches(RegExp(r'^\d+(\.\d+)*$')));
      } else {
        expect(current.osVersion, isNull);
      }
    });

    test('reads the version out of what Apple platforms report', () {
      expect(appleOsVersion('Version 26.0 (Build 25A354)'), '26.0');
      expect(appleOsVersion('Version 17.4.1 (Build 21E236)'), '17.4.1');
      expect(appleOsVersion('Linux 5.10.43 #1 SMP PREEMPT'), isNull);
      expect(appleOsVersion('"Windows 10 Pro" 10.0 (Build 19045)'), isNull);
    });

    test('compares by value and prints the app and the system', () {
      expect(
        header,
        PeekSessionHeader(
          name: 'Acme Shop',
          platform: 'ios',
          osVersion: '26.0',
          startedAt: fixtureStart,
        ),
      );
      expect(
        header,
        isNot(PeekSessionHeader(platform: 'ios', startedAt: fixtureStart)),
      );
      expect(
        header.toString(),
        'PeekSessionHeader(Acme Shop, ios 26.0, format 1)',
      );
    });
  });
}
