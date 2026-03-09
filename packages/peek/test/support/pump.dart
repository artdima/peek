import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether golden files are compared in this run.
///
/// Rendering differs between platforms, so goldens are authored and checked
/// on Linux — in CI, or locally through a container. Elsewhere the golden
/// tests are skipped rather than failing for the wrong reason.
final bool goldensEnabled =
    Platform.isLinux || Platform.environment['PEEK_GOLDENS'] == '1';

/// The value passed to `skip:`: `false` when goldens run, otherwise the
/// reason they are skipped.
final Object skipGoldens =
    goldensEnabled
        ? false
        : 'Goldens are only compared on Linux; set PEEK_GOLDENS=1 to force.';

/// Pumps [child] inside a minimal app, ready for a widget or golden test.
///
/// [size] sets the surface, so a golden is the same size everywhere;
/// [textScale] exercises large-text layouts.
Future<void> pumpPeek(
  WidgetTester tester,
  Widget child, {
  ThemeData? theme,
  Brightness brightness = Brightness.light,
  double textScale = 1,
  Size size = const Size(400, 800),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme:
          theme ??
          ThemeData(
            brightness: brightness,
            colorSchemeSeed: const Color(0xFF3DDC84),
          ),
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(body: child),
      ),
    ),
  );
}

/// Compares the widget found by [finder] against `test/goldens/<name>.png`.
///
/// A no-op where goldens are not compared, so the surrounding test still
/// exercises the widget.
Future<void> expectGolden(Finder finder, String name) async {
  if (!goldensEnabled) return;
  await expectLater(finder, matchesGoldenFile('goldens/$name.png'));
}
