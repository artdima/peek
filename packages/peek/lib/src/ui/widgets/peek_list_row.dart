import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../theme/peek_theme.dart';
import 'peek_tappable.dart';

/// One row of a grouped section: a name, what it holds, where it leads.
final class PeekListRow extends StatelessWidget {
  /// Creates a row named [title].
  const PeekListRow({
    required this.title,
    this.leading,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
    this.chevron = false,
    this.enabled = true,
    super.key,
  });

  /// The name of the row.
  final String title;

  /// Shown before the name, such as an icon or a dot.
  final Widget? leading;

  /// A second line under the name.
  final String? subtitle;

  /// What the row holds, shown at its end.
  final String? value;

  /// Shown after the value, such as a copy button.
  final Widget? trailing;

  /// Called on a tap.
  final VoidCallback? onTap;

  /// Whether to show that the row leads somewhere.
  final bool chevron;

  /// Whether the row means anything; a disabled row is greyed and inert.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final subtitle = this.subtitle;
    final value = this.value;
    final leading = this.leading;
    final trailing = this.trailing;
    final titleColor = enabled ? theme.label : theme.secondaryLabel;
    final valueColor = theme.secondaryLabel;

    final tap = enabled ? onTap : null;

    return PeekTappable(
      onTap: tap,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: tap == null ? theme.minRowHeight : theme.minTapTarget,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: theme.gutter, vertical: 8),
          child: Row(
            children: [
              if (leading != null) ...[leading, const SizedBox(width: 10)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title, style: theme.body.copyWith(color: titleColor)),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: theme.footnote.copyWith(
                          color: theme.secondaryLabel,
                        ),
                      ),
                  ],
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: theme.footnote.copyWith(color: valueColor),
                  ),
                ),
              ],
              if (trailing != null) ...[const SizedBox(width: 8), trailing],
              if (chevron) ...[
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 18, color: theme.tertiaryLabel),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
