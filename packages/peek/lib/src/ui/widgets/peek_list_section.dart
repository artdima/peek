import 'package:flutter/widgets.dart';

import '../theme/peek_theme.dart';
import 'peek_separator.dart';

/// A group of rows as one card, the way a settings screen groups them.
final class PeekListSection extends StatelessWidget {
  /// Creates a section holding [children], under an optional [title].
  const PeekListSection({
    required this.children,
    this.title,
    this.trailing,
    this.footer,
    super.key,
  });

  /// The rows, separated by hairlines.
  final List<Widget> children;

  /// The heading above the card.
  final String? title;

  /// Shown at the end of the heading, such as a control.
  final Widget? trailing;

  /// A note under the card.
  final String? footer;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final theme = PeekTheme.of(context);
    final title = this.title;
    final trailing = this.trailing;
    final footer = this.footer;
    final caption = theme.caption.copyWith(color: theme.secondaryLabel);

    return Padding(
      padding: EdgeInsets.only(bottom: theme.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null || trailing != null)
            Padding(
              padding: EdgeInsets.fromLTRB(theme.gutter, 0, theme.gutter, 6),
              child: Row(
                children: [
                  Expanded(
                    child:
                        title == null
                            ? const SizedBox.shrink()
                            : Text(
                              title.toUpperCase(),
                              style: caption.copyWith(letterSpacing: 0.5),
                            ),
                  ),
                  if (trailing != null) trailing,
                ],
              ),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(theme.radius),
            child: ColoredBox(
              color: theme.card,
              child: Column(
                children: [
                  for (final (index, child) in children.indexed) ...[
                    if (index > 0) PeekSeparator(indent: theme.gutter),
                    child,
                  ],
                ],
              ),
            ),
          ),
          if (footer != null)
            Padding(
              padding: EdgeInsets.fromLTRB(theme.gutter, 6, theme.gutter, 0),
              child: Text(footer, style: caption),
            ),
        ],
      ),
    );
  }
}
