import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/widgets.dart';

import '../theme/peek_theme.dart';

/// The ancestors every Peek screen and panel expects around it.
///
/// Two of them. A `Material`, because text editing and text selection
/// refuse to live without one. And a text style of Peek's own, because
/// whatever a `Text` leaves unsaid it inherits — and what a route or an
/// overlay inherits, above the app's own content, is the yellow-underlined
/// style Flutter draws to mark a mistake.
final class PeekSurface extends StatelessWidget {
  /// Creates a host around [child].
  const PeekSurface({required this.child, this.theme, super.key});

  /// What the host holds.
  final Widget child;

  /// Where the text style comes from.
  ///
  /// Defaults to the theme registered on the context. Pass one where the
  /// host builds outside Peek's tree, such as inside an overlay entry.
  final PeekTheme? theme;

  @override
  Widget build(BuildContext context) => Material(
    type: MaterialType.transparency,
    child: DefaultTextStyle(
      style: (theme ?? PeekTheme.of(context)).body,
      child: child,
    ),
  );
}
