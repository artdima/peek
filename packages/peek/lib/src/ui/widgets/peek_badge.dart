import 'package:flutter/widgets.dart';

import '../theme/peek_theme.dart';

/// A word in a tinted pill, the way a sheet says what it is about.
final class PeekBadge extends StatelessWidget {
  /// Creates a badge reading [label], uppercase, in [color].
  const PeekBadge(this.label, {required this.color, super.key});

  /// What the badge says.
  final String label;

  /// The hue of the text and, faintly, of the pill behind it.
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(theme.radius * 0.6),
      ),
      child: Text(
        label.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.footnote.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
