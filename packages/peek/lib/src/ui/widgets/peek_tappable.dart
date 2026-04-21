import 'package:flutter/widgets.dart';

import '../theme/peek_theme.dart';

/// A region that answers a tap, with Peek's own feedback.
///
/// Rows take a wash of [PeekTheme.fill] while pressed, the way a grouped
/// list does; controls that are already coloured fade instead.
final class PeekTappable extends StatefulWidget {
  /// Creates a tappable region around [child].
  const PeekTappable({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.fade = false,
    super.key,
  });

  /// What to show.
  final Widget child;

  /// Called on a tap; the region is inert when this is `null`.
  final VoidCallback? onTap;

  /// Called on a long press.
  final VoidCallback? onLongPress;

  /// Whether the region stays washed, as an open row does.
  final bool selected;

  /// Whether pressing fades the child instead of washing it.
  final bool fade;

  @override
  State<PeekTappable> createState() => _PeekTappableState();
}

class _PeekTappableState extends State<PeekTappable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final inert = widget.onTap == null && widget.onLongPress == null;
    final down = _pressed && !inert;

    var child = widget.child;
    if (widget.fade) {
      child = Opacity(opacity: down ? 0.4 : 1, child: child);
    } else if (down || widget.selected) {
      child = ColoredBox(color: theme.fill, child: child);
    }

    if (inert) return child;
    final tap = widget.onTap;
    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      actions: {
        if (tap != null)
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              tap();
              return null;
            },
          ),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tap,
        onLongPress: widget.onLongPress,
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        child: child,
      ),
    );
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }
}
