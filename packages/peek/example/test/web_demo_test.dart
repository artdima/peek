import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peek_example/web_demo.dart';

void main() {
  Future<void> pumpPhone(
    WidgetTester tester, {
    Size room = PhoneScreen.size,
    double textScale = 1,
  }) async {
    tester.view
      ..physicalSize = room
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(textScale)),
              child: PhoneScreen(child: child!),
            ),
        home: const SizedBox.expand(key: Key('home')),
      ),
    );
  }

  BuildContext homeOf(WidgetTester tester) =>
      tester.element(find.byKey(const Key('home')));

  group('PhoneScreen', () {
    testWidgets('lays the app out at the size of a phone, inside its bars', (
      tester,
    ) async {
      await pumpPhone(tester);

      final media = MediaQuery.of(homeOf(tester));
      expect(media.size, PhoneScreen.size);
      expect(media.padding, PhoneScreen.insets);
      expect(media.viewPadding, PhoneScreen.insets);
      expect(find.text('9:41'), findsOneWidget);
    });

    testWidgets('scales the phone to the room the page gives it', (
      tester,
    ) async {
      const room = Size(294.75, 639);
      await pumpPhone(tester, room: room);

      expect(MediaQuery.sizeOf(homeOf(tester)), PhoneScreen.size);
      expect(tester.getRect(find.byKey(const Key('home'))), Offset.zero & room);
    });

    testWidgets('behaves as an iPhone whatever the browser runs on', (
      tester,
    ) async {
      await pumpPhone(tester);

      final home = homeOf(tester);
      expect(Theme.of(home).platform, TargetPlatform.iOS);
      final scrolling = ScrollConfiguration.of(home);
      expect(scrolling.getPlatform(home), TargetPlatform.iOS);
      expect(scrolling.dragDevices, contains(PointerDeviceKind.mouse));
    });

    testWidgets('keeps the status bar its size at twice the text size', (
      tester,
    ) async {
      await pumpPhone(tester, textScale: 2);

      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.text('9:41')).height, lessThan(20));
    });
  });

  group('DemoTheme', () {
    test('follows the system while no page has picked a theme', () {
      expect(DemoTheme.current, ThemeMode.system);
    });
  });
}
