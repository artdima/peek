import 'package:flutter/widgets.dart';

import '../theme/peek_theme.dart';

/// How a screen wears its name.
enum PeekTitleStyle {
  /// Large and left-aligned, with the actions above it.
  large,

  /// Small and centred, with the actions beside it.
  inline,
}

/// The frame every Peek screen sits in: a name, a row of actions, and the
/// screen itself under them.
///
/// Peek brings its own frame rather than a `Scaffold`: the look has to hold
/// whatever the host app's theme says.
final class PeekScaffold extends StatelessWidget {
  /// Creates a screen named [title] showing [child].
  const PeekScaffold({
    required this.title,
    required this.child,
    this.titleStyle = PeekTitleStyle.large,
    this.actions = const [],
    this.leading,
    this.trailingTitle,
    this.background,
    super.key,
  });

  /// The screen's name.
  final String title;

  /// The screen itself.
  final Widget child;

  /// How the name is worn.
  final PeekTitleStyle titleStyle;

  /// The buttons at the top right.
  final List<Widget> actions;

  /// A button before the name, such as the way back.
  final Widget? leading;

  /// Shown next to a large name, such as a count.
  final Widget? trailingTitle;

  /// An override for what lies behind everything.
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final insets = MediaQuery.viewInsetsOf(context).bottom;

    return ColoredBox(
      color: background ?? theme.background,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(bottom: insets),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              switch (titleStyle) {
                PeekTitleStyle.large => _LargeTitle(
                  title: title,
                  actions: actions,
                  leading: leading,
                  trailing: trailingTitle,
                ),
                PeekTitleStyle.inline => _InlineTitle(
                  title: title,
                  actions: actions,
                  leading: leading,
                ),
              },
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _LargeTitle extends StatelessWidget {
  const _LargeTitle({
    required this.title,
    required this.actions,
    this.leading,
    this.trailing,
  });

  final String title;
  final List<Widget> actions;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final leading = this.leading;
    final trailing = this.trailing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading != null || actions.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: theme.gutter - 10),
            child: Row(
              children: [
                if (leading != null) leading,
                const Spacer(),
                ...actions,
              ],
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(theme.gutter, 2, theme.gutter, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.largeTitle,
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing],
            ],
          ),
        ),
      ],
    );
  }
}

class _InlineTitle extends StatelessWidget {
  const _InlineTitle({
    required this.title,
    required this.actions,
    this.leading,
  });

  final String title;
  final List<Widget> actions;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final leading = this.leading;

    return SizedBox(
      height: theme.minRowHeight,
      child: Row(
        children: [
          if (leading != null) leading,
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: theme.rowSpacing),
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.headline,
              ),
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
