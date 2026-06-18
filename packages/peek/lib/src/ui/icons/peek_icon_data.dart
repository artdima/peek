import 'dart:ui' show Path;

import 'package:flutter/foundation.dart';

/// One glyph, as the outlines it is drawn from.
///
/// The outlines are in the symbol's own coordinates; [width] and [height]
/// say how large that space is, so a glyph can be scaled to any size
/// without losing its proportions. Subpaths wind against each other where
/// a shape has a hole, the way a font does.
@immutable
final class PeekIconData {
  /// Creates a glyph [width] by [height] in its own coordinates.
  const PeekIconData({
    required this.width,
    required this.height,
    required this.paths,
    this.strokeWidth = 0,
    this.filled = 0,
  });

  /// How wide the glyph's own coordinate space is.
  final double width;

  /// How tall that space is.
  final double height;

  /// The outlines, as SVG path data.
  final List<String> paths;

  /// How thick the outlines are drawn, in the glyph's own coordinates; a
  /// glyph whose shapes are filled rather than stroked leaves this at zero.
  final double strokeWidth;

  /// How many of the leading outlines are filled rather than stroked, so a
  /// glyph can be a solid shape with a mark cut out of it.
  final int filled;

  /// The outlines that are filled, in the glyph's own coordinates.
  ///
  /// Parsing is done once per glyph and kept: the outlines are constants,
  /// so the result never goes stale.
  Path get solid => _solid[this] ??= _parse(paths.take(filled));

  /// The outlines that are stroked.
  Path get stroked => _stroked[this] ??= _parse(paths.skip(filled));

  static final Map<PeekIconData, Path> _solid = {};
  static final Map<PeekIconData, Path> _stroked = {};
}

// The outlines Peek ships use absolute moves, lines and cubics only — what
// a symbol exported from a vector editor comes out as. Anything else is
// skipped rather than guessed at.
final RegExp _commands = RegExp('([A-Za-z])([^A-Za-z]*)');
final RegExp _number = RegExp(r'-?\d*\.?\d+(?:[eE][-+]?\d+)?');

Path _parse(Iterable<String> outlines) {
  final path = Path();
  for (final outline in outlines) {
    for (final match in _commands.allMatches(outline)) {
      final numbers =
          _number
              .allMatches(match.group(2)!)
              .map((number) => double.parse(number.group(0)!))
              .toList();
      switch (match.group(1)) {
        case 'M':
          for (var i = 0; i + 1 < numbers.length; i += 2) {
            if (i == 0) {
              path.moveTo(numbers[i], numbers[i + 1]);
            } else {
              path.lineTo(numbers[i], numbers[i + 1]);
            }
          }
        case 'L':
          for (var i = 0; i + 1 < numbers.length; i += 2) {
            path.lineTo(numbers[i], numbers[i + 1]);
          }
        case 'C':
          for (var i = 0; i + 5 < numbers.length; i += 6) {
            path.cubicTo(
              numbers[i],
              numbers[i + 1],
              numbers[i + 2],
              numbers[i + 3],
              numbers[i + 4],
              numbers[i + 5],
            );
          }
        case 'Z' || 'z':
          path.close();
      }
    }
  }
  return path;
}
