import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/widgets.dart';

import '../theme/peek_theme.dart';
import 'peek_tappable.dart';

/// A rounded label that can be chosen, counted and let go of.
///
/// Drawn 32 tall inside a taller tap target, so a row of pills stays easy
/// to hit without looking heavy.
final class PeekPill extends StatelessWidget {
  /// Creates a pill reading [label].
  const PeekPill({
    required this.label,
    this.count,
    this.selected = false,
    this.enabled = true,
    this.onTap,
    this.onRemove,
    this.removeLabel,
    super.key,
  });

  /// What it reads.
  final String label;

  /// How many entries it stands for, shown beside the label.
  final int? count;

  /// Whether it is the chosen one.
  final bool selected;

  /// Whether it can be chosen at all.
  final bool enabled;

  /// Called when the pill is tapped.
  final VoidCallback? onTap;

  /// Called when its cross is tapped; the cross is hidden without this.
  final VoidCallback? onRemove;

  /// Names that cross for assistive tech.
  final String? removeLabel;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final count = this.count;
    final onRemove = this.onRemove;
    const onAccent = Color(0xFFFFFFFF);
    final foreground =
        !enabled
            ? theme.tertiaryLabel
            : selected
            ? onAccent
            : theme.label;

    return PeekTappable(
      onTap: enabled ? onTap : null,
      fade: true,
      child: SizedBox(
        height: theme.minRowHeight,
        child: Align(
          widthFactor: 1,
          child: Container(
            height: 32,
            padding: EdgeInsets.only(
              left: 12,
              right: onRemove == null ? 12 : 6,
            ),
            decoration: BoxDecoration(
              color: selected ? theme.accent : theme.fill,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.footnote.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 5),
                  Text(
                    '$count',
                    style: theme.footnote.copyWith(
                      color:
                          selected
                              ? onAccent.withValues(alpha: 0.8)
                              : theme.secondaryLabel,
                    ),
                  ),
                ],
                if (onRemove != null) ...[
                  const SizedBox(width: 2),
                  PeekTappable(
                    onTap: onRemove,
                    fade: true,
                    child: Tooltip(
                      message: removeLabel ?? '',
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Icon(
                          CupertinoIcons.xmark,
                          size: 14,
                          color: selected ? onAccent : theme.secondaryLabel,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
