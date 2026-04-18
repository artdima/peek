import 'package:flutter/widgets.dart';

import '../theme/peek_theme.dart';

/// The hairline between rows.
final class PeekSeparator extends StatelessWidget {
  /// Creates a separator, starting [indent] from the left.
  const PeekSeparator({this.indent = 0, super.key});

  /// How far in from the left edge the line starts.
  final double indent;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    return Padding(
      padding: EdgeInsets.only(left: indent),
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
