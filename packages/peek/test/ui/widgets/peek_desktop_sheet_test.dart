import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peek/peek.dart';

import '../../support/entries.dart';
import '../../support/fake_store.dart';
import '../../support/pump.dart';

/// A link the tests drive by hand.
final class FakeDesktopLink implements PeekDesktopLink {
  FakeDesktopLink(this._state);

  PeekDesktopLinkState _state;
  final StreamController<PeekDesktopLinkState> _changes =
      StreamController.broadcast();

  /// What the screen asked for, in order.
  final List<String> calls = [];

  /// The link moves on, and says so.
  void moveTo(PeekDesktopLinkState state) {
    _state = state;
    _changes.add(state);
  }

  @override
  String get name => 'fake-link';

  @override
  PeekDesktopLinkState get linkState => _state;

  @override
  Stream<PeekDesktopLinkState> get linkChanges => _changes.stream;

  @override
  Stream<List<PeekDesktopFound>> watchDesktops() => const Stream.empty();

  @override
  Future<void> connectDesktop(
    String host,
    int port, {
    String? code,
    String? name,
    String? serverId,
  }) async {
    calls.add('connect $host:$port ${code ?? ''}'.trim());
  }

  @override
  Future<void> disconnectDesktop() async => calls.add('disconnect');

  @override
  Future<void> forgetDesktop() async => calls.add('forget');

  @override
  void dispose() {
    unawaited(_changes.close());
  }
}

void main() {
  late PeekController controller;

  Future<void> pumpScreen(
    WidgetTester tester, {
    List<PeekEntry> entries = const [],
    FakeDesktopLink? link,
    Brightness brightness = Brightness.light,
    Size size = const Size(420, 760),
  }) async {
    final wired = fakePeek(entries: entries);
    if (link != null) wired.peek.attach(link);
    controller = PeekController(wired.peek);
    addTearDown(controller.dispose);
    addTearDown(wired.peek.dispose);

    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(brightness: brightness),
        home: PeekScreen(peek: wired.peek, controller: controller),
      ),
    );
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester) async {
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 60));
    }
  }

  List<String> mockClipboard(WidgetTester tester) {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    return copied;
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byTooltip('More'));
    await settle(tester);
  }

  group('the menu', () {
    testWidgets('offers Peek Pro even with nothing recorded', (tester) async {
      await pumpScreen(tester);
      await openMenu(tester);
      expect(find.text('PEEK PRO'), findsOneWidget);
      expect(find.text('Connect to Peek Pro'), findsOneWidget);
      expect(find.text('Export HAR'), findsNothing);
    });

    testWidgets('keeps the exports beside it once there is something', (
      tester,
    ) async {
      await pumpScreen(tester, entries: [e1]);
      await openMenu(tester);
      expect(find.text('Export HAR'), findsOneWidget);
      expect(find.text('Connect to Peek Pro'), findsOneWidget);
    });

    testWidgets('says where a link stands', (tester) async {
      final link = FakeDesktopLink(
        const PeekDesktopLinkState(
          status: PeekDesktopLinkStatus.connected,
          desktopName: 'Studio Mac',
        ),
      );
      await pumpScreen(tester, link: link);
      await openMenu(tester);
      expect(find.text('Connected to Studio Mac'), findsOneWidget);
    });

    testWidgets('looks the part in both layouts', (tester) async {
      await pumpScreen(tester, entries: [e1]);
      await openMenu(tester);
      await expectGolden(find.byType(MaterialApp), 'desktop-menu-narrow');
      await tester.tap(find.text('Cancel'));
      await settle(tester);

      final link = FakeDesktopLink(
        const PeekDesktopLinkState(
          status: PeekDesktopLinkStatus.connected,
          desktopName: 'Studio Mac',
        ),
      );
      await pumpScreen(
        tester,
        entries: [e1],
        link: link,
        size: const Size(900, 640),
      );
      await openMenu(tester);
      expect(find.text('Connected to Studio Mac'), findsOneWidget);
      await expectGolden(find.byType(MaterialApp), 'desktop-menu-wide');
    });
  });

  group('without a link', () {
    testWidgets('explains what to add, and hands out the addresses', (
      tester,
    ) async {
      final copied = mockClipboard(tester);
      await pumpScreen(tester);
      await openMenu(tester);
      await tester.tap(find.text('Connect to Peek Pro'));
      await settle(tester);

      expect(find.text('ADD TO PUBSPEC.YAML'), findsOneWidget);
      expect(find.text('peek_remote: ^2.0.0'), findsOneWidget);
      expect(
        find.text('peek.attach(PeekRemote(peek)..start());'),
        findsOneWidget,
      );
      expect(find.text('Peek Pro on GitHub'), findsOneWidget);
      expect(find.text('peek_remote on pub.dev'), findsOneWidget);
      expect(find.text('Setting up remote viewing'), findsOneWidget);

      final copies = find.byType(PeekCopyButton);
      expect(copies, findsNWidgets(5));
      await tester.tap(copies.at(2));
      await settle(tester);
      expect(copied.single, 'https://github.com/artdima/peek-pro');
      await tester.pump(const Duration(seconds: 2));

      await expectGolden(find.byType(MaterialApp), 'desktop-setup-light');
      await tester.tap(find.text('Close'));
      await settle(tester);
      expect(find.text('ADD TO PUBSPEC.YAML'), findsNothing);
    });

    testWidgets('reads in the dark too', (tester) async {
      await pumpScreen(tester, brightness: Brightness.dark);
      await openMenu(tester);
      await tester.tap(find.text('Connect to Peek Pro'));
      await settle(tester);
      expect(find.text('peek_remote: ^2.0.0'), findsOneWidget);
      await expectGolden(find.byType(MaterialApp), 'desktop-setup-dark');
    });
  });

  group('with a link', () {
    testWidgets('shows the status and follows it', (tester) async {
      final link = FakeDesktopLink(
        const PeekDesktopLinkState(status: PeekDesktopLinkStatus.unpaired),
      );
      await pumpScreen(tester, link: link);
      await openMenu(tester);
      await tester.tap(find.text('Connect to Peek Pro'));
      await settle(tester);

      expect(find.text('Status'), findsOneWidget);
      expect(find.text('Not paired'), findsNWidgets(2));
      expect(find.text('Disconnect'), findsNothing);
      expect(find.text('Forget this Mac'), findsNothing);

      link.moveTo(
        const PeekDesktopLinkState(
          status: PeekDesktopLinkStatus.connected,
          desktopName: 'Studio Mac',
        ),
      );
      await settle(tester);
      expect(find.text('Connected to Studio Mac'), findsOneWidget);
      expect(find.text('Studio Mac'), findsOneWidget);
      expect(find.text('Disconnect'), findsOneWidget);
      expect(find.text('Forget this Mac'), findsOneWidget);
      await expectGolden(find.byType(MaterialApp), 'desktop-link-light');

      await tester.tap(find.text('Disconnect'));
      await settle(tester);
      await tester.tap(find.text('Forget this Mac'));
      await settle(tester);
      expect(link.calls, ['disconnect', 'forget']);
    });

    testWidgets('says why the desktop turned the app away', (tester) async {
      final link = FakeDesktopLink(
        const PeekDesktopLinkState(
          status: PeekDesktopLinkStatus.denied,
          desktopName: '192.168.1.20:9741',
          message: 'The code is wrong or has expired.',
        ),
      );
      await pumpScreen(tester, link: link);
      await openMenu(tester);
      await tester.tap(find.text('Peek Pro turned the app away'));
      await settle(tester);
      expect(find.text('The code is wrong or has expired.'), findsOneWidget);
      expect(find.text('Forget this Mac'), findsOneWidget);
      expect(find.text('Disconnect'), findsNothing);
    });
  });
}
