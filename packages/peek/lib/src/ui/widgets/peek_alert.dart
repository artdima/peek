import 'package:flutter/widgets.dart';

import '../peek_scope.dart';
import '../theme/peek_theme.dart';
import 'peek_separator.dart';
import 'peek_surface.dart';
import 'peek_tappable.dart';

/// Asks before doing something that cannot be taken back.
///
/// Resolves to `true` when the person confirms, `false` otherwise.
Future<bool> showPeekAlert(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = true,
}) async {
  final controller = PeekScope.read(context);
  final strings = PeekScope.stringsOf(context);
  final share = PeekScope.shareOf(context);

  final confirmed = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: strings.dismiss,
    barrierColor: const Color(0x59000000),
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder:
        (context, animation, secondaryAnimation) => PeekScope(
          controller: controller,
          strings: strings,
          share: share,
          child: _Alert(
            title: title,
            message: message,
            confirmLabel: confirmLabel,
            cancelLabel: strings.cancel,
            destructive: destructive,
          ),
        ),
    transitionBuilder:
        (context, animation, secondaryAnimation, child) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: 1.08, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            child: child,
          ),
        ),
  );
  return confirmed ?? false;
}

class _Alert extends StatelessWidget {
  const _Alert({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);

    return PeekSurface(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(theme.radius * 1.4),
            child: ColoredBox(
              color: theme.card,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: EdgeInsets.all(theme.gutter),
                    child: Column(
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: theme.headline,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: theme.footnote.copyWith(
                            color: theme.secondaryLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const PeekSeparator(),
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: _AlertButton(
                            label: cancelLabel,
                            onTap: () => Navigator.of(context).pop(false),
                          ),
                        ),
                        SizedBox(
                          width: theme.hairline,
                          child: ColoredBox(
                            color: theme.separator,
                            child: const SizedBox(height: double.infinity),
                          ),
                        ),
                        Expanded(
                          child: _AlertButton(
                            label: confirmLabel,
                            emphasised: true,
                            destructive: destructive,
                            onTap: () => Navigator.of(context).pop(true),
                          ),
                        ),
                      ],
                    ),
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

class _AlertButton extends StatelessWidget {
  const _AlertButton({
    required this.label,
    required this.onTap,
    this.emphasised = false,
    this.destructive = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool emphasised;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    return PeekTappable(
      onTap: onTap,
      child: Semantics(
        button: true,
        child: SizedBox(
          height: theme.minTapTarget,
          child: Center(
            child: Text(
              label,
              style: theme.body.copyWith(
                color: destructive ? theme.failure : theme.accent,
                fontWeight: emphasised ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
