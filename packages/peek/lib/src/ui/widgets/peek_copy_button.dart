import 'package:flutter/material.dart' show Icons;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../peek_scope.dart';
import '../peek_strings.dart';
import 'peek_icon_button.dart';
import 'peek_toast.dart';

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
    final strings = PeekScope.stringsOf(context);
    final value = text;

    return PeekIconButton(
      icon: Icons.copy_rounded,
      tooltip: tooltip ?? strings.copy,
      size: dense ? 16 : 20,
      onPressed: value == null ? null : () => _copy(context, value, strings),
    );
  }

  Future<void> _copy(BuildContext context, String value, PeekStrings strings) =>
      peekCopy(context, value);
}

/// Puts [text] on the clipboard and says so where [context] is.
Future<void> peekCopy(BuildContext context, String text) async {
  final strings = PeekScope.stringsOf(context);
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) showPeekToast(context, strings.copied);
}
