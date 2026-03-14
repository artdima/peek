import 'package:flutter/widgets.dart';

import '../core/peek.dart';
import 'peek_controller.dart';

/// Hands the [PeekController] to the widgets below it.
///
/// [PeekScope.of] rebuilds its caller when the controller changes;
/// [PeekScope.read] does not, which is what callbacks want.
final class PeekScope extends InheritedNotifier<PeekController> {
  /// Creates a scope over [controller].
  const PeekScope({
    required PeekController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

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
}
