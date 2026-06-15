import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/widgets.dart';

import '../theme/peek_theme.dart';
import 'peek_tappable.dart';

/// One of the icons at the top of a screen.
///
/// The tap target is [width] across — Apple's minimum, and what keeps a
/// row of them from drifting apart — by the full height a tap target
/// asks for, or the bar's height when that is shorter.
///
/// [Tooltip] is the single Material widget Peek keeps: it is what names the
/// button for assistive tech, and it draws nothing until asked.
final class PeekIconButton extends StatelessWidget {
  /// Creates a button showing [icon], named [tooltip].
  const PeekIconButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
    this.color,
    this.badgeCount = 0,
    this.size = 22,
    super.key,
  });

  /// How wide the tap target is.
  static const double width = 44;

  /// The glyph to show.
  final IconData icon;

  /// What the button does, for tooltips and screen readers.
  final String tooltip;

  /// Called on a tap; the button is disabled when this is `null`.
  final VoidCallback? onPressed;

  /// An override for the icon colour.
  final Color? color;

  /// A number to show over the icon; hidden when zero.
  final int badgeCount;

  /// How large the glyph is drawn; the tap target does not change.
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final tint =
        onPressed == null ? theme.tertiaryLabel : color ?? theme.accent;

    return MergeSemantics(
      child: Tooltip(
        message: tooltip,
        child: PeekTappable(
          onTap: onPressed,
          fade: true,
          focusRadius: BorderRadius.circular(PeekIconButton.width / 2),
          child: Semantics(
            button: true,
            enabled: onPressed != null,
            child: SizedBox(
              width: PeekIconButton.width,
              height: theme.minTapTarget,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(icon, size: size, color: tint),
                  if (badgeCount > 0)
                    Positioned(
                      top: 8,
                      right: 4,
                      child: _Badge(count: badgeCount, color: theme.accent),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 15),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: theme.caption.copyWith(
          color: const Color(0xFFFFFFFF),
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}
