import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../theme/peek_theme.dart';

/// What fills the screen when there is nothing to show.
final class PeekEmptyState extends StatelessWidget {
  /// Creates an empty state reading [title] over [message].
  const PeekEmptyState({
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
    super.key,
  });

  /// The headline.
  final String title;

  /// The line explaining what to do.
  final String message;

  /// The icon above the headline.
  final IconData icon;

  /// An optional button below the message.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final muted = theme.secondaryLabel;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(theme.gutter * 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: muted),
            SizedBox(height: theme.gutter),
            Text(title, textAlign: TextAlign.center, style: theme.headline),
            SizedBox(height: theme.rowSpacing / 2),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.footnote.copyWith(color: muted),
            ),
            if (action case final widget?) ...[
              SizedBox(height: theme.gutter),
              widget,
            ],
          ],
        ),
      ),
    );
  }
}
