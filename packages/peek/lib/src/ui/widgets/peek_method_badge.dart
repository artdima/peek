import 'package:flutter/widgets.dart';

import '../theme/peek_theme.dart';

/// The HTTP method, in its own colour.
final class PeekMethodBadge extends StatelessWidget {
  /// Creates a badge for [method].
  const PeekMethodBadge(this.method, {super.key});

  /// The method, shown uppercase.
  final String method;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final color = theme.colorForMethod(method);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(theme.radius / 2),
      ),
      child: Text(
        method.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
