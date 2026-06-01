import 'package:flutter/cupertino.dart' show CupertinoSearchTextField;
import 'package:flutter/widgets.dart';

import '../theme/peek_theme.dart';
import 'peek_tappable.dart';

/// The rounded field Peek searches from.
///
/// This is Flutter's own search field: it already is the field Peek wants,
/// down to the clear button, and it brings the platform's text editing
/// with it. Only the colours are ours.
final class PeekSearchField extends StatelessWidget {
  /// Creates a field over [controller].
  const PeekSearchField({
    required this.controller,
    required this.onChanged,
    required this.placeholder,
    this.focusNode,
    this.onClear,
    this.cancelLabel,
    this.onCancel,
    this.autofocus = false,
    super.key,
  });

  /// What holds the text.
  final TextEditingController controller;

  /// Called as the text changes.
  final ValueChanged<String> onChanged;

  /// Shown while the field is empty.
  final String placeholder;

  /// The field's focus, when the caller keeps one.
  final FocusNode? focusNode;

  /// Called when the field is emptied by its button.
  final VoidCallback? onClear;

  /// Reads on the button that leaves the search.
  final String? cancelLabel;

  /// Called when that button is tapped; hidden when `null`.
  final VoidCallback? onCancel;

  /// Whether the field takes focus as soon as it is shown.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final onCancel = this.onCancel;
    final cancelLabel = this.cancelLabel;

    return Row(
      children: [
        Expanded(
          child: CupertinoSearchTextField(
            controller: controller,
            focusNode: focusNode,
            autofocus: autofocus,
            placeholder: placeholder,
            onChanged: onChanged,
            onSuffixTap: onClear,
            style: theme.body,
            placeholderStyle: theme.body.copyWith(color: theme.secondaryLabel),
            itemColor: theme.secondaryLabel,
            backgroundColor: theme.fill,
            borderRadius: BorderRadius.circular(theme.radius),
          ),
        ),
        if (onCancel != null && cancelLabel != null)
          PeekTappable(
            onTap: onCancel,
            fade: true,
            child: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Text(
                cancelLabel,
                style: theme.body.copyWith(color: theme.accent),
              ),
            ),
          ),
      ],
    );
  }
}
