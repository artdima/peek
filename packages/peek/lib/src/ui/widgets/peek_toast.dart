import 'dart:async';

import 'package:flutter/widgets.dart';

import '../theme/peek_theme.dart';
import 'peek_surface.dart';

/// Says something happened, briefly, near the bottom of the screen.
///
/// Peek's own, because a `SnackBar` needs a `Scaffold` and looks nothing
/// like the rest of this.
void showPeekToast(BuildContext context, String message) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;
  final theme = PeekTheme.of(context);

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder:
        (context) => Positioned(
          left: 0,
          right: 0,
          bottom: MediaQuery.paddingOf(context).bottom + 32,
          child: _Toast(message: message, theme: theme),
        ),
  );

  overlay.insert(entry);
  Timer(const Duration(seconds: 2), entry.remove);
}

class _Toast extends StatelessWidget {
  const _Toast({required this.message, required this.theme});

  final String message;
  final PeekTheme theme;

  @override
  Widget build(BuildContext context) => PeekSurface(
    theme: theme,
    child: Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 140),
        builder:
            (context, value, child) => Opacity(opacity: value, child: child),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: theme.label,
            borderRadius: BorderRadius.circular(theme.radius * 2),
          ),
          child: Text(
            message,
            style: theme.footnote.copyWith(color: theme.background),
          ),
        ),
      ),
    ),
  );
}
