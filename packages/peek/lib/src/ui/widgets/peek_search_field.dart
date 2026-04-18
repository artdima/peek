import 'package:flutter/material.dart' show Icons, InputDecoration, TextField;
import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter/widgets.dart';

import '../theme/peek_theme.dart';
import 'peek_tappable.dart';

/// The rounded field Peek searches from.
///
/// The field itself is a bare [TextField]: none of Material's decoration
/// is used, only its text editing, selection handles and IME handling.
final class PeekSearchField extends StatelessWidget {
  /// Creates a field over [controller].
  const PeekSearchField({
    required this.controller,
    required this.onChanged,
    required this.placeholder,
    required this.clearLabel,
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

  /// Names the button that empties the field.
  final String clearLabel;

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
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: theme.fill,
              borderRadius: BorderRadius.circular(theme.radius),
            ),
            child: Row(
              children: [
                Icon(Icons.search, size: 17, color: theme.secondaryLabel),
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    autofocus: autofocus,
                    onChanged: onChanged,
                    textInputAction: TextInputAction.search,
                    style: theme.body,
                    cursorColor: theme.accent,
                    decoration: InputDecoration.collapsed(
                      hintText: placeholder,
                      hintStyle: theme.body.copyWith(
                        color: theme.secondaryLabel,
                      ),
                    ),
                  ),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller,
                  builder: (context, value, _) {
                    if (value.text.isEmpty) return const SizedBox.shrink();
                    return PeekTappable(
                      onTap: onClear,
                      fade: true,
                      child: Semantics(
                        button: true,
                        label: clearLabel,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.cancel,
                            size: 17,
                            color: theme.secondaryLabel,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
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
