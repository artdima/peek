import 'package:flutter/widgets.dart';

import '../core/peek.dart';
import 'peek_controller.dart';
import 'peek_share.dart';
import 'peek_strings.dart';

/// Hands the [PeekController] and the [PeekStrings] to the widgets below.
///
/// [PeekScope.of] rebuilds its caller when the controller changes;
/// [PeekScope.read] does not, which is what callbacks want.
final class PeekScope extends InheritedNotifier<PeekController> {
  /// Creates a scope over [controller], showing [strings].
  const PeekScope({
    required PeekController controller,
    required super.child,
    this.strings = const PeekStrings(),
    this.share,
    super.key,
  }) : super(notifier: controller);

  /// The words to show.
  final PeekStrings strings;

  /// What hands exported content to the platform, when the app gave one.
  final PeekShareDelegate? share;

  /// The controller above [context], rebuilding on every change.
  static PeekController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<PeekScope>()?.notifier;
    assert(scope != null, 'No PeekScope found above this widget');
    return scope!;
  }

  /// The controller above [context] without depending on it.
  static PeekController read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<PeekScope>()?.notifier;
    assert(scope != null, 'No PeekScope found above this widget');
    return scope!;
  }

  /// The instance the controller shows.
  static Peek peekOf(BuildContext context) => of(context).peek;

  /// What shares content: the app's delegate, or what the platform can do
  /// on its own — a download on the web, nothing anywhere else.
  static PeekShareDelegate? shareOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PeekScope>()?.share ??
      peekPlatformShareDelegate();

  /// The words to show, without subscribing to the controller.
  static PeekStrings stringsOf(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<PeekScope>();
    assert(scope != null, 'No PeekScope found above this widget');
    return scope!.strings;
  }

  @override
  bool updateShouldNotify(PeekScope oldWidget) =>
      strings != oldWidget.strings ||
      share != oldWidget.share ||
      super.updateShouldNotify(oldWidget);
}
