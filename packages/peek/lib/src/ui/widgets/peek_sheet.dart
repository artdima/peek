import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../peek_scope.dart';
import '../peek_strings.dart';
import '../theme/peek_theme.dart';
import 'peek_list_row.dart';
import 'peek_separator.dart';

/// One option of a [showPeekActions] sheet.
@immutable
final class PeekAction<T> {
  /// Creates an option returning [value] when picked.
  const PeekAction({
    required this.value,
    required this.label,
    this.selected = false,
    this.destructive = false,
  });

  /// What picking it means.
  final T value;

  /// What it reads.
  final String label;

  /// Whether it is what is already in force.
  final bool selected;

  /// Whether it undoes something, and so reads in the failure colour.
  final bool destructive;
}

/// Shows [builder] in a panel rising from the bottom of the screen.
///
/// The scope is handed over explicitly: a modal route builds beside the
/// screen that opened it, not under it.
Future<T?> showPeekSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final controller = PeekScope.read(context);
  final strings = PeekScope.stringsOf(context);

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: strings.dismiss,
    barrierColor: const Color(0x59000000),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder:
        (context, animation, secondaryAnimation) => PeekScope(
          controller: controller,
          strings: strings,
          child: _SheetFrame(builder: builder),
        ),
    transitionBuilder:
        (context, animation, secondaryAnimation, child) => SlideTransition(
          position: Tween(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
  );
}

/// Asks which of [actions] to take, in a sheet.
Future<T?> showPeekActions<T>(
  BuildContext context, {
  required List<PeekAction<T>> actions,
  String? title,
}) {
  final strings = PeekScope.stringsOf(context);
  return showPeekSheet<T>(
    context,
    builder:
        (context) =>
            _Actions<T>(actions: actions, title: title, strings: strings),
  );
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final size = MediaQuery.sizeOf(context);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.all(theme.rowSpacing),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: size.height * 0.85,
              maxWidth: 560,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(theme.radius * 1.4),
              child: ColoredBox(
                color: theme.card,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 4),
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.separator,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Flexible(child: builder(context)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Actions<T> extends StatelessWidget {
  const _Actions({required this.actions, required this.strings, this.title});

  final List<PeekAction<T>> actions;
  final PeekStrings strings;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final title = this.title;

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Padding(
              padding: EdgeInsets.fromLTRB(theme.gutter, 6, theme.gutter, 10),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: theme.caption.copyWith(color: theme.secondaryLabel),
              ),
            ),
          for (final action in actions) ...[
            const PeekSeparator(),
            PeekListRow(
              title: action.label,
              trailing:
                  action.selected
                      ? Icon(Icons.check, size: 18, color: theme.accent)
                      : null,
              onTap: () => Navigator.of(context).pop(action.value),
            ),
          ],
          const PeekSeparator(),
          PeekListRow(
            title: strings.cancel,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
