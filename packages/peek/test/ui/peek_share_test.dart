import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peek/peek.dart';

import '../support/fake_store.dart';
import '../support/pump.dart';

void main() {
  /// The scope's view of what can carry an export off.
  Future<PeekShareDelegate?> shareIn(
    WidgetTester tester, {
    PeekShareDelegate? given,
  }) async {
    final peek = fakePeek().peek;
    final controller = PeekController(peek);
    addTearDown(controller.dispose);
    addTearDown(peek.dispose);

    late BuildContext inner;
    await pumpPeek(
      tester,
      PeekScope(
        controller: controller,
        share: given,
        child: Builder(
          builder: (context) {
            inner = context;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    return PeekScope.shareOf(inner);
  }

  group('sharing', () {
    // The web build swaps in a delegate that downloads the file; every other
    // platform leaves sharing to the app, which owns the package that does it.
    test('the platform offers nothing of its own here', () {
      expect(peekPlatformShareDelegate(), isNull);
    });

    testWidgets('takes the delegate the app gave', (tester) async {
      final given = PeekShareDelegate.from((_) async {});
      expect(await shareIn(tester, given: given), same(given));
    });

    testWidgets('falls back to what the platform can do', (tester) async {
      expect(await shareIn(tester), peekPlatformShareDelegate());
    });
  });
}
