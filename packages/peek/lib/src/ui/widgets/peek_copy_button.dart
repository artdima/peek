import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../peek_scope.dart';
import '../peek_strings.dart';
import '../theme/peek_theme.dart';

/// Copies text to the clipboard and says so.
final class PeekCopyButton extends StatelessWidget {
  /// Creates a button that copies [text] when pressed.
  const PeekCopyButton({
    required this.text,
    this.tooltip,
    this.dense = true,
    super.key,
  });

  /// What lands on the clipboard; `null` disables the button.
  final String? text;

  /// An override for the tooltip.
  final String? tooltip;

  /// Whether the button takes as little room as possible.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final strings = PeekScope.stringsOf(context);
    final value = text;

    return IconButton(
      onPressed: value == null ? null : () => _copy(context, value, strings),
      icon: const Icon(Icons.copy_rounded),
      iconSize: dense ? 16 : 20,
      visualDensity: dense ? VisualDensity.compact : null,
      padding: dense ? const EdgeInsets.all(4) : null,
      constraints:
          dense ? const BoxConstraints(minWidth: 32, minHeight: 32) : null,
      tooltip: tooltip ?? strings.copy,
      color: theme.monoTextStyle.color?.withValues(alpha: 0.7),
    );
  }

  Future<void> _copy(
    BuildContext context,
    String value,
    PeekStrings strings,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    await Clipboard.setData(ClipboardData(text: value));
    messenger?.showSnackBar(
      SnackBar(
        content: Text(strings.copied),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
