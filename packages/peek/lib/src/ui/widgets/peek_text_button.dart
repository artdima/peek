import 'package:flutter/widgets.dart';

import '../theme/peek_theme.dart';
import 'peek_tappable.dart';

/// A word that acts: Cancel, Clear filters, Reset.
final class PeekTextButton extends StatelessWidget {
  /// Creates a button reading [label].
  const PeekTextButton({
    required this.label,
    this.onPressed,
    this.destructive = false,
    super.key,
  });

  /// What it reads.
  final String label;

  /// Called on a tap; the button is disabled when this is `null`.
  final VoidCallback? onPressed;

  /// Whether it undoes something, and so reads in the failure colour.
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final color =
        onPressed == null
            ? theme.tertiaryLabel
            : destructive
            ? theme.failure
            : theme.accent;

    return PeekTappable(
      onTap: onPressed,
      fade: true,
      child: Semantics(
        button: true,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: theme.minRowHeight),
          child: Align(
            widthFactor: 1,
            heightFactor: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(label, style: theme.body.copyWith(color: color)),
            ),
          ),
        ),
      ),
    );
  }
}
