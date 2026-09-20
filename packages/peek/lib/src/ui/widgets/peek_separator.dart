import 'package:flutter/widgets.dart';

import '../theme/peek_theme.dart';

/// The hairline between rows, or between panes standing side by side.
final class PeekSeparator extends StatelessWidget {
  /// Creates a separator across the width it is given.
  const PeekSeparator({this.indent = 0, this.endIndent = 0, super.key})
    : axis = Axis.horizontal;

  /// Creates an upright separator down the height it is given.
  ///
  /// It asks for every pixel of that height, so it belongs in a [Row] laid
  /// out with [CrossAxisAlignment.stretch], or somewhere else the height is
  /// bounded.
  const PeekSeparator.vertical({this.indent = 0, this.endIndent = 0, super.key})
    : axis = Axis.vertical;

  /// Which way the line runs.
  final Axis axis;

  /// How far in from the left edge the line starts, or from the top when it
  /// is upright. Measured left to right whichever way the text runs.
  final double indent;

  /// How far short of the right edge the line stops, or of the bottom when
  /// it is upright.
  final double endIndent;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final line = ColoredBox(color: theme.separator);

    return switch (axis) {
      Axis.horizontal => Padding(
        padding: EdgeInsets.only(left: indent, right: endIndent),
        child: SizedBox(
          height: theme.hairline,
          child: SizedBox(width: double.infinity, child: line),
        ),
      ),
      Axis.vertical => Padding(
        padding: EdgeInsets.only(top: indent, bottom: endIndent),
        child: SizedBox(
          width: theme.hairline,
          child: SizedBox(height: double.infinity, child: line),
        ),
      ),
    };
  }
}
