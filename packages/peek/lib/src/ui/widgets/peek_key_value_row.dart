import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter/widgets.dart';

import '../theme/peek_theme.dart';

/// One `name: value` line, with the value free to be selected and copied.
final class PeekKeyValueRow extends StatelessWidget {
  /// Creates a row showing [value] under [name].
  const PeekKeyValueRow({
    required this.name,
    required this.value,
    this.trailing,
    this.subtitle,
    this.emphasised = false,
    super.key,
  });

  /// The label on the left.
  final String name;

  /// The value on the right.
  final String value;

  /// Shown after the value, such as a copy button.
  final Widget? trailing;

  /// A line under the value, such as a cookie's attributes.
  final String? subtitle;

  /// Whether the value stands out, as a masked or notable one might.
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final nameStyle = theme.footnote.copyWith(color: theme.secondaryLabel);
    final valueStyle = theme.mono.copyWith(
      fontWeight: emphasised ? FontWeight.w700 : FontWeight.w400,
    );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: theme.rowSpacing / 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(name, style: nameStyle)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(value, style: valueStyle),
                if (subtitle case final line?)
                  Text(
                    line,
                    style: theme.caption.copyWith(color: theme.tertiaryLabel),
                  ),
              ],
            ),
          ),
          if (trailing case final widget?) ...[
            const SizedBox(width: 8),
            widget,
          ],
        ],
      ),
    );
  }
}

/// A heading above a group of rows.
final class PeekSectionHeader extends StatelessWidget {
  /// Creates a heading reading [title], with an optional [count].
  const PeekSectionHeader(this.title, {this.count, this.trailing, super.key});

  /// The heading text.
  final String title;

  /// How many rows follow, shown next to the title.
  final int? count;

  /// Shown at the end of the heading, such as a copy button.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final style = theme.caption.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      color: theme.secondaryLabel,
    );

    return Padding(
      padding: EdgeInsets.only(top: theme.gutter, bottom: theme.rowSpacing / 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              count == null
                  ? title.toUpperCase()
                  : '${title.toUpperCase()}  $count',
              style: style,
            ),
          ),
          if (trailing case final widget?) widget,
        ],
      ),
    );
  }
}
