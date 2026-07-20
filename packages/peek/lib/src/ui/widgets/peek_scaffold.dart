import 'package:flutter/cupertino.dart' show CupertinoSliverNavigationBar;
import 'package:flutter/widgets.dart';

import '../theme/peek_theme.dart';
import 'peek_surface.dart';

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
      child: PeekSurface(
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
      // The bar is as tall as the buttons in it, not as a row of text.
      height: theme.minTapTarget,
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

/// A screen whose name is large until the content scrolls under it.
///
/// This is the one place Peek borrows a whole chrome widget: the
/// collapsing large title is a behaviour worth having and a tedious one
/// to rebuild. Everything inside the scroll view is still Peek's own.
final class PeekSliverScaffold extends StatelessWidget {
  /// Creates a screen named [title] over [slivers].
  const PeekSliverScaffold({
    required this.title,
    required this.slivers,
    this.actions = const [],
    this.leading,
    this.controller,
    this.background,
    this.overlay,
    super.key,
  });

  /// The screen's name.
  final String title;

  /// What the screen shows, as slivers.
  final List<Widget> slivers;

  /// The buttons at the top right.
  final List<Widget> actions;

  /// A button before the name, such as the way back.
  final Widget? leading;

  /// The scroll position, when the caller keeps one.
  final ScrollController? controller;

  /// An override for what lies behind everything.
  final Color? background;

  /// Drawn over the scroll view, such as a floating button.
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final overlay = this.overlay;

    return ColoredBox(
      color: background ?? theme.background,
      child: PeekSurface(
        child: Stack(
          children: [
            CustomScrollView(
              controller: controller,
              slivers: [
                CupertinoSliverNavigationBar(
                  largeTitle: Text(title, style: theme.largeTitle),
                  backgroundColor: theme.background,
                  automaticallyImplyLeading: false,
                  leading: leading,
                  padding: EdgeInsetsDirectional.only(
                    start: theme.gutter - 10,
                    end: theme.gutter - 10,
                  ),
                  // No hairline under the name: the chrome under it draws
                  // its own lines, and two in a row read as a mistake.
                  border: null,
                  trailing:
                      actions.isEmpty
                          ? null
                          : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: actions,
                          ),
                ),
                ...slivers,
              ],
            ),
            if (overlay != null) overlay,
          ],
        ),
      ),
    );
  }
}
