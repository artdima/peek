import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String libraryDirectory = 'lib';

final RegExp _pastCore = RegExp(
  r'''^\s*(?:import|export)\s+['"]package:(?:peek/peek\.dart|flutter/)''',
  multiLine: true,
);

final RegExp _dartIo = RegExp(
  r'''^\s*(?:import|export)\s+['"]dart:io['"]''',
  multiLine: true,
);

final RegExp _directive = RegExp(
  r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]'''
  r'''((?:\s*if\s*\([^)]*\)\s*['"][^'"]+['"])*)''',
  multiLine: true,
);

final RegExp _branch = RegExp(r'''if\s*\(([^)]*)\)\s*['"]([^'"]+)['"]''');

/// Whether [source] reaches for Peek's user interface or for Flutter.
bool reachesPastCore(String source) => _pastCore.hasMatch(source);

/// Whether [source] imports `dart:io` directly.
bool importsDartIo(String source) => _dartIo.hasMatch(source);

/// Whether [source] reaches the `io` directory other than through
/// `if (dart.library.io)` — the web build would compile it otherwise.
bool reachesIoUnguarded(String source) {
  for (final directive in _directive.allMatches(source)) {
    if (_pointsIntoIo(directive[1]!)) return true;
    for (final branch in _branch.allMatches(directive[2]!)) {
      if (_pointsIntoIo(branch[2]!) && branch[1]!.trim() != 'dart.library.io') {
        return true;
      }
    }
  }
  return false;
}

bool _pointsIntoIo(String uri) =>
    (!uri.startsWith('package:') || uri.startsWith('package:peek_http/')) &&
    uri.split('/').contains('io');

bool _insideIo(File file) {
  final segments = file.uri.pathSegments;
  for (var i = 0; i + 1 < segments.length; i++) {
    if (segments[i] == 'src' && segments[i + 1] == 'io') return true;
  }
  return false;
}

/// Every file under [directory] that breaks the rules above; `dart:io` is
/// allowed under `src/io/` and nowhere else.
List<String> offendingDartFiles(Directory directory) =>
    directory
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where((file) {
          final source = file.readAsStringSync();
          if (reachesPastCore(source)) return true;
          if (_insideIo(file)) return false;
          return importsDartIo(source) || reachesIoUnguarded(source);
        })
        .map((file) => file.path)
        .toList();

void main() {
  test("the adapter imports Peek's core and keeps dart:io in its place", () {
    final directory = Directory(libraryDirectory);
    expect(
      directory.existsSync(),
      isTrue,
      reason: '$libraryDirectory is missing; the adapter lives there.',
    );

    expect(offendingDartFiles(directory), isEmpty);
  });

  test('the scan finds planted offenders and spares the io directory', () {
    final directory = Directory.systemTemp.createTempSync('peek_http_arch');
    addTearDown(() => directory.deleteSync(recursive: true));

    void plant(String path, String source) =>
        File('${directory.path}/$path')
          ..createSync(recursive: true)
          ..writeAsStringSync(source);

    plant('nested/offender.dart', "import 'dart:io';");
    plant('src/io/allowed.dart', "import 'dart:io';");
    plant('src/io/ui.dart', "import 'package:flutter/widgets.dart';");
    plant('unguarded.dart', "import 'src/io/allowed.dart';");
    plant(
      'guarded.dart',
      "import 'src/stub.dart'\n"
          "    if (dart.library.io) 'src/io/allowed.dart';",
    );
    plant('clean.dart', "import 'package:peek/core.dart';");

    expect(
      offendingDartFiles(directory),
      unorderedEquals([
        endsWith('offender.dart'),
        endsWith('ui.dart'),
        endsWith('unguarded.dart'),
      ]),
    );
  });

  test('the detectors read directives, not any mention of a library', () {
    expect(reachesPastCore("import 'package:peek/peek.dart';"), isTrue);
    expect(reachesPastCore("export 'package:peek/peek.dart';"), isTrue);
    expect(reachesPastCore("import 'package:flutter/widgets.dart';"), isTrue);
    expect(reachesPastCore("import 'package:peek/core.dart';"), isFalse);
    expect(reachesPastCore("// import 'package:peek/peek.dart';"), isFalse);

    expect(importsDartIo("import 'dart:io';"), isTrue);
    expect(importsDartIo("import 'dart:async';"), isFalse);
    expect(importsDartIo("// import 'dart:io';"), isFalse);

    expect(reachesIoUnguarded("import 'src/io/response.dart';"), isTrue);
    expect(
      reachesIoUnguarded("export 'package:peek_http/src/io/response.dart';"),
      isTrue,
    );
    expect(
      reachesIoUnguarded(
        "import 'src/stub.dart' if (dart.library.html) 'src/io/a.dart';",
      ),
      isTrue,
    );
    expect(
      reachesIoUnguarded(
        "import 'src/stub.dart' if (dart.library.io) 'src/io/a.dart';",
      ),
      isFalse,
    );
    expect(
      reachesIoUnguarded("import 'package:http/io_client.dart';"),
      isFalse,
    );
    expect(
      reachesIoUnguarded("import 'package:other/io/thing.dart';"),
      isFalse,
    );
  });
}
