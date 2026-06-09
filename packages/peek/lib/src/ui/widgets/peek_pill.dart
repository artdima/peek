import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../theme/peek_theme.dart';
import 'peek_tappable.dart';

/// A rounded label that can be chosen, counted and let go of.
///
/// Drawn 32 tall inside a [PeekTheme.minTapTarget] target, so a row of
/// pills stays easy to hit without looking heavy. A pill that can be let
/// go of shows a cross and removes itself when tapped: a cross of its own
/// would be far too small to aim at.
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
    this.group = false,
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

  /// Called when a pill showing a cross is tapped; without this there is
  /// no cross and nothing to remove.
  final VoidCallback? onRemove;

  /// What removing means, for assistive tech: 'Remove 401'.
  final String? removeLabel;

  /// Whether this pill is one of a set where only one may be chosen.
  final bool group;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final count = this.count;
    final onRemove = this.onRemove;
    const onAccent = Color(0xFFFFFFFF);
    final foreground =
        !enabled
            ? theme.secondaryLabel
            : selected
            ? onAccent
            : theme.label;

    final acts = onTap != null || onRemove != null;

    return MergeSemantics(
      child: PeekTappable(
        onTap: enabled ? (onTap ?? onRemove) : null,
        fade: true,
        focusRadius: BorderRadius.circular(16),
        child: Semantics(
          button: acts,
          enabled: acts ? enabled : null,
          selected: acts || selected ? selected : null,
          inMutuallyExclusiveGroup: group ? true : null,
          label: removeLabel,
          excludeSemantics: removeLabel != null,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: theme.minTapTarget,
              minHeight: theme.minTapTarget,
            ),
            child: Align(
              widthFactor: 1,
              heightFactor: 1,
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
                      const SizedBox(width: 5),
                      Icon(
                        Icons.close,
                        size: 14,
                        color: selected ? onAccent : theme.secondaryLabel,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
