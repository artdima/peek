import 'package:flutter/widgets.dart';

import '../theme/peek_theme.dart';
import 'peek_tappable.dart';

/// The one button on a screen that carries it: Resume, Show 12 requests.
///
/// [expand] gives it the full width and the height of a footer button;
/// without it the button is as wide as what it reads. [tinted] turns the
/// fill down to a wash of the accent, for a button that offers rather than
/// carries — Clear filters under an empty list.
final class PeekFilledButton extends StatelessWidget {
  /// Creates a button reading [label], with [icon] before it.
  const PeekFilledButton({
    required this.label,
    this.icon,
    this.onPressed,
    this.expand = false,
    this.tinted = false,
    super.key,
  });

  /// What it reads.
  final String label;

  /// The glyph before the label, when the button has one.
  final IconData? icon;

  /// Called on a tap; the button is disabled when this is `null`.
  final VoidCallback? onPressed;

  /// Whether it fills the width it is given.
  final bool expand;

  /// Whether it is a wash of the accent with the accent on it, rather than
  /// the accent with white on it.
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final icon = this.icon;
    final onAccent = tinted ? theme.accent : const Color(0xFFFFFFFF);
    final radius = BorderRadius.circular(theme.radius);
    final enabled = onPressed != null;
    final fill = theme.accent.withValues(
      alpha: switch ((tinted, enabled)) {
        (true, true) => 0.12,
        (true, false) => 0.06,
        (false, true) => 1.0,
        (false, false) => 0.4,
      },
    );

    return MergeSemantics(
      child: PeekTappable(
        onTap: onPressed,
        fade: true,
        focusRadius: radius,
        child: Semantics(
          button: true,
          enabled: enabled,
          child: Container(
            constraints: BoxConstraints(
              minWidth: theme.minTapTarget,
              minHeight: expand ? 52 : theme.minTapTarget,
            ),
            width: expand ? double.infinity : null,
            padding: EdgeInsets.symmetric(
              horizontal: tinted ? 20 : (icon == null ? 16 : 12),
            ),
            decoration: BoxDecoration(color: fill, borderRadius: radius),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: onAccent),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: (expand || tinted ? theme.headline : theme.body)
                        .copyWith(color: onAccent, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
