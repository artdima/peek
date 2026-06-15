import 'package:flutter/widgets.dart';

import '../theme/peek_theme.dart';

/// The hairline between rows.
final class PeekSeparator extends StatelessWidget {
  /// Creates a separator, holding [indent] off the left edge and [endIndent]
  /// off the right.
  const PeekSeparator({this.indent = 0, this.endIndent = 0, super.key});

  /// How far in from the left edge the line starts.
  final double indent;

  /// How far short of the right edge it stops.
  final double endIndent;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    return Padding(
      padding: EdgeInsets.only(left: indent, right: endIndent),
      child: SizedBox(
        height: theme.hairline,
        child: ColoredBox(
          color: theme.separator,
          child: const SizedBox(width: double.infinity),
        ),
      ),
    );
  }
}
