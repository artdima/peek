import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The core layer must stay pure Dart so it can be reused outside Flutter and
/// extracted into its own package without touching the public API.
const String coreDirectory = 'lib/src/core';

final RegExp _flutterDirective = RegExp(
  r'''^\s*(?:import|export)\s+['"]package:flutter(?:_test)?/''',
  multiLine: true,
);

bool importsFlutter(String source) => _flutterDirective.hasMatch(source);

List<String> dartFilesImportingFlutter(Directory directory) => directory
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'))
    .where((file) => importsFlutter(file.readAsStringSync()))
    .map((file) => file.path)
    .toList();

void main() {
  test('core imports no Flutter', () {
    final directory = Directory(coreDirectory);
    expect(
      directory.existsSync(),
      isTrue,
      reason: '$coreDirectory is missing; the core layer lives there.',
    );

    expect(dartFilesImportingFlutter(directory), isEmpty);
  });

  test('the scan finds a planted Flutter import', () {
    final directory = Directory.systemTemp.createTempSync('peek_arch');
    addTearDown(() => directory.deleteSync(recursive: true));

    final nested = Directory('${directory.path}/nested')..createSync();
    File('${nested.path}/offender.dart')
        .writeAsStringSync("import 'package:flutter/material.dart';");
    File('${directory.path}/clean.dart')
        .writeAsStringSync("import 'package:meta/meta.dart';");

    expect(
      dartFilesImportingFlutter(directory),
      [endsWith('offender.dart')],
    );
  });

  test('the detector reads directives, not any mention of Flutter', () {
    expect(importsFlutter("import 'package:flutter/material.dart';"), isTrue);
    expect(importsFlutter("export 'package:flutter/widgets.dart';"), isTrue);
    expect(
      importsFlutter("import 'package:flutter_test/flutter_test.dart';"),
      isTrue,
    );
    expect(importsFlutter("import 'dart:async';"), isFalse);
    expect(importsFlutter("import 'package:meta/meta.dart';"), isFalse);
    expect(
      importsFlutter("// import 'package:flutter/material.dart';"),
      isFalse,
    );
  });
}
