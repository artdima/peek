import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// An adapter maps its logger's objects onto Peek's events and nothing else,
/// so it reaches for Peek's core and never for Peek's user interface — nor
/// for Flutter, which the core does not need either. `dart:io` is out too:
/// Chopper runs on the web, and an adapter that sorts errors by
/// `SocketException` would not compile there.
const String libraryDirectory = 'lib';

final RegExp _forbidden = RegExp(
  r'''^\s*(?:import|export)\s+['"](?:package:(?:peek/peek\.dart|flutter/)|dart:io)''',
  multiLine: true,
);

/// Whether [source] reaches past the core.
bool reachesPastCore(String source) => _forbidden.hasMatch(source);

/// Every file under [directory] that does.
List<String> dartFilesReachingPastCore(Directory directory) =>
    directory
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) => reachesPastCore(file.readAsStringSync()))
        .map((file) => file.path)
        .toList();

void main() {
  test("the adapter imports Peek's core and nothing beyond it", () {
    final directory = Directory(libraryDirectory);
    expect(
      directory.existsSync(),
      isTrue,
      reason: '$libraryDirectory is missing; the adapter lives there.',
    );

    expect(dartFilesReachingPastCore(directory), isEmpty);
  });

  test('the scan finds a planted import', () {
    final directory = Directory.systemTemp.createTempSync('peek_chopper_arch');
    addTearDown(() => directory.deleteSync(recursive: true));

    final nested = Directory('${directory.path}/nested')..createSync();
    File('${nested.path}/offender.dart')
      ..createSync()
      ..writeAsStringSync("import 'dart:io';");
    File('${directory.path}/clean.dart')
      ..createSync()
      ..writeAsStringSync("import 'package:peek/core.dart';");

    expect(dartFilesReachingPastCore(directory), [endsWith('offender.dart')]);
  });

  test('the detector reads directives, not any mention of the library', () {
    expect(reachesPastCore("import 'package:peek/peek.dart';"), isTrue);
    expect(reachesPastCore("export 'package:peek/peek.dart';"), isTrue);
    expect(reachesPastCore("import 'package:flutter/widgets.dart';"), isTrue);
    expect(reachesPastCore("import 'dart:io';"), isTrue);
    expect(reachesPastCore("import 'package:peek/core.dart';"), isFalse);
    expect(reachesPastCore("import 'package:chopper/chopper.dart';"), isFalse);
    expect(reachesPastCore("import 'dart:async';"), isFalse);
    expect(reachesPastCore("// import 'package:peek/peek.dart';"), isFalse);
  });
}
