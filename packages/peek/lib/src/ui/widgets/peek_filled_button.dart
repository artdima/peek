import 'package:flutter/widgets.dart';

import '../theme/peek_theme.dart';
import 'peek_tappable.dart';

/// The one button on a screen that carries it: Resume, Show 12 requests.
///
/// [expand] gives it the full width and the height of a footer button;
/// without it the button is as wide as what it reads.
final class PeekFilledButton extends StatelessWidget {
  /// Creates a button reading [label], with [icon] before it.
  const PeekFilledButton({
    required this.label,
    this.icon,
    this.onPressed,
    this.expand = false,
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

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final icon = this.icon;
    const onAccent = Color(0xFFFFFFFF);
    final radius = BorderRadius.circular(theme.radius);
    final enabled = onPressed != null;

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
            padding: EdgeInsets.symmetric(horizontal: icon == null ? 16 : 12),
            decoration: BoxDecoration(
              color:
                  enabled ? theme.accent : theme.accent.withValues(alpha: 0.4),
              borderRadius: radius,
            ),
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
                    style: (expand ? theme.headline : theme.body).copyWith(
                      color: onAccent,
                      fontWeight: FontWeight.w600,
                    ),
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
