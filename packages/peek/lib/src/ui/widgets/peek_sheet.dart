import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../icons/peek_icon.dart';
import '../icons/peek_icon_data.dart';
import '../peek_scope.dart';
import '../peek_strings.dart';
import '../theme/peek_theme.dart';
import 'peek_list_row.dart';
import 'peek_separator.dart';
import 'peek_surface.dart';
import 'peek_tappable.dart';

/// One option of a [showPeekActions] sheet.
@immutable
final class PeekAction<T> {
  /// Creates an option returning [value] when picked.
  const PeekAction({
    required this.value,
    required this.label,
    this.icon,
    this.section,
    this.selected = false,
    this.destructive = false,
  });

  /// What picking it means.
  final T value;

  /// What it reads.
  final String label;

  /// The glyph before the label, when the option has one.
  final PeekIconData? icon;

  /// The heading of the group it belongs to; neighbours sharing one share a
  /// card. Without one, neighbours without one still share a card.
  final String? section;

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
  final share = PeekScope.shareOf(context);

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
          share: share,
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
///
/// [header] names what the actions are about — a call, say — and takes the
/// place of [title], a plain line that does the same for less.
Future<T?> showPeekActions<T>(
  BuildContext context, {
  required List<PeekAction<T>> actions,
  String? title,
  Widget? header,
}) {
  final strings = PeekScope.stringsOf(context);
  return showPeekSheet<T>(
    context,
    builder:
        (context) => _Actions<T>(
          actions: actions,
          title: title,
          header: header,
          strings: strings,
        ),
  );
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final size = MediaQuery.sizeOf(context);

    return PeekSurface(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: size.height * 0.85,
            maxWidth: 560,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(theme.radius * 2),
            ),
            child: ColoredBox(
              color: theme.groupedBackground,
              child: SafeArea(
                top: false,
                minimum: EdgeInsets.only(bottom: theme.rowSpacing),
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
  const _Actions({
    required this.actions,
    required this.strings,
    this.title,
    this.header,
  });

  final List<PeekAction<T>> actions;
  final PeekStrings strings;
  final String? title;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final title = this.title;
    final header = this.header;
    final caption = theme.caption.copyWith(
      color: theme.secondaryLabel,
      letterSpacing: 0.5,
    );

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: theme.gutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: header,
            )
          else if (title != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(title, style: theme.headline),
            ),
          for (final group in _grouped(actions)) ...[
            if (group.section case final section?)
              Padding(
                padding: EdgeInsets.only(top: theme.gutter, bottom: 6),
                child: Text(section.toUpperCase(), style: caption),
              )
            else
              SizedBox(height: theme.gutter),
            _Group(
              indent:
                  group.actions.any((action) => action.icon != null)
                      ? theme.gutter + _ActionRow.iconWidth
                      : theme.gutter,
              children: [
                for (final action in group.actions)
                  _ActionRow(
                    action: action,
                    onTap: () => Navigator.of(context).pop(action.value),
                  ),
              ],
            ),
          ],
          SizedBox(height: theme.gutter),
          _Group(
            indent: 0,
            children: [
              _CancelRow(
                label: strings.cancel,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Neighbours with the same [PeekAction.section] as one group.
List<({String? section, List<PeekAction<T>> actions})> _grouped<T>(
  List<PeekAction<T>> actions,
) {
  final groups = <({String? section, List<PeekAction<T>> actions})>[];
  for (final action in actions) {
    if (groups.isNotEmpty && groups.last.section == action.section) {
      groups.last.actions.add(action);
    } else {
      groups.add((section: action.section, actions: [action]));
    }
  }
  return groups;
}

/// Rows as one card, separated by hairlines that start at [indent].
class _Group extends StatelessWidget {
  const _Group({required this.children, required this.indent});

  final List<Widget> children;
  final double indent;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(theme.radius),
      child: ColoredBox(
        color: theme.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, child) in children.indexed) ...[
              if (index > 0) PeekSeparator(indent: indent),
              child,
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.action, required this.onTap});

  /// The glyph and the gap after it, so a hairline can start at the label.
  static const double iconWidth = 40;

  final PeekAction<Object?> action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final icon = action.icon;
    final color = action.destructive ? theme.failure : theme.label;
    final tint = action.destructive ? theme.failure : theme.accent;

    return PeekListRow(
      title: action.label,
      titleStyle: TextStyle(color: color),
      leading:
          icon == null
              ? null
              : SizedBox(
                width: iconWidth - 6,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: PeekIcon(icon, size: 22, color: tint),
                ),
              ),
      trailing:
          action.selected
              ? Icon(Icons.check, size: 18, color: theme.accent)
              : null,
      onTap: onTap,
    );
  }
}

class _CancelRow extends StatelessWidget {
  const _CancelRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    return PeekTappable(
      onTap: onTap,
      child: Semantics(
        button: true,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: theme.minTapTarget),
          child: Center(child: Text(label, style: theme.headline)),
        ),
      ),
    );
  }
}
