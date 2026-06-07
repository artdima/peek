import 'package:flutter/material.dart' show MaterialPageRoute;
import 'package:flutter/widgets.dart';

import '../core/peek.dart';
import 'peek_share.dart';
import 'peek_strings.dart';
import 'screens/peek_screen.dart';

/// Opens Peek over [context] and completes when it is closed.
///
/// ```dart
/// await showPeek(context);
/// ```
///
/// Shows [peek], or [Peek.instance] when omitted. [rootNavigator] keeps the
/// screen above a nested navigator, such as a tab bar.
///
/// Works from `MaterialApp.builder` too, where the app's navigator is below
/// [context] rather than above it.
Future<void> showPeek(
  BuildContext context, {
  Peek? peek,
  PeekStrings strings = const PeekStrings(),
  PeekShareDelegate? share,
  bool fullscreenDialog = true,
  bool rootNavigator = true,
}) => _navigatorFor(context, rootNavigator).push(
  PeekRoute(
    peek: peek,
    strings: strings,
    share: share,
    fullscreenDialog: fullscreenDialog,
  ),
);

/// The navigator to open on: the one around [context], or — for a caller
/// wrapping the whole app, such as `PeekOverlay` — the outermost one under
/// it. Falls back to `Navigator.of`, whose error says what is missing.
NavigatorState _navigatorFor(BuildContext context, bool rootNavigator) =>
    Navigator.maybeOf(context, rootNavigator: rootNavigator) ??
    _navigatorBelow(context) ??
    Navigator.of(context, rootNavigator: rootNavigator);

NavigatorState? _navigatorBelow(BuildContext context) {
  NavigatorState? found;
  void visit(Element element) {
    if (found != null) return;
    if (element is StatefulElement && element.state is NavigatorState) {
      found = element.state as NavigatorState;
      return;
    }
    element.visitChildren(visit);
  }

  context.visitChildElements(visit);
  return found;
}

/// The route [showPeek] pushes, for apps that build their own.
///
/// Register it with a named route:
///
/// ```dart
/// MaterialApp(
///   onGenerateRoute: (settings) => settings.name == PeekRoute.name
///       ? PeekRoute(settings: settings)
///       : null,
/// );
/// ```
final class PeekRoute extends MaterialPageRoute<void> {
  /// Creates the route over [peek], or [Peek.instance] when omitted.
  PeekRoute({
    Peek? peek,
    PeekStrings strings = const PeekStrings(),
    PeekShareDelegate? share,
    super.fullscreenDialog = true,
    super.settings,
  }) : super(
         builder: (_) => PeekScreen(peek: peek, strings: strings, share: share),
       );

  /// The name this route is usually registered under.
  static const String name = '/peek';
}

/// Opening Peek from the instance itself.
extension PeekNavigation on Peek {
  /// Opens this instance over [context]; see [showPeek].
  ///
  /// ```dart
  /// peek.open(context);
  /// ```
  Future<void> open(
    BuildContext context, {
    PeekStrings strings = const PeekStrings(),
    PeekShareDelegate? share,
    bool fullscreenDialog = true,
    bool rootNavigator = true,
  }) => showPeek(
    context,
    peek: this,
    strings: strings,
    share: share,
    fullscreenDialog: fullscreenDialog,
    rootNavigator: rootNavigator,
  );
}
