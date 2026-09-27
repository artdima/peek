import 'dart:async';

import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoTextField;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peek/peek.dart';

import '../../support/entries.dart';
import '../../support/fake_store.dart';
import '../../support/pump.dart';

/// Where the screen asked a link to connect.
typedef Connection =
    ({String host, int port, String? code, String? name, String? serverId});

/// A link the tests drive by hand.
final class FakeDesktopLink implements PeekDesktopLink {
  FakeDesktopLink(this._state);

  PeekDesktopLinkState _state;
  final StreamController<PeekDesktopLinkState> _changes =
      StreamController.broadcast();
  final StreamController<List<PeekDesktopFound>> _found =
      StreamController.broadcast();

  /// What the screen asked for, in order.
  final List<String> calls = [];

  /// Every connection the screen asked for, in order.
  final List<Connection> connections = [];

  /// The link moves on, and says so.
  void moveTo(PeekDesktopLinkState state) {
    _state = state;
    _changes.add(state);
  }

  /// The network hears [desktops].
  void hear(List<PeekDesktopFound> desktops) => _found.add(desktops);

  /// Searching turns out impossible here.
  void cannotSearch() => _found.addError(StateError('no multicast'));

  @override
  String get name => 'fake-link';

  @override
  PeekDesktopLinkState get linkState => _state;

  @override
  Stream<PeekDesktopLinkState> get linkChanges => _changes.stream;

  @override
  Stream<List<PeekDesktopFound>> watchDesktops() => _found.stream;

  @override
  Future<void> connectDesktop(
    String host,
    int port, {
    String? code,
    String? name,
    String? serverId,
  }) async {
    calls.add('connect');
    connections.add((
      host: host,
      port: port,
      code: code,
      name: name,
      serverId: serverId,
    ));
  }

  @override
  Future<void> disconnectDesktop() async => calls.add('disconnect');

  @override
  Future<void> forgetDesktop() async => calls.add('forget');

  @override
  void dispose() {
    unawaited(_changes.close());
    unawaited(_found.close());
  }
}

const studio = PeekDesktopFound(
  name: 'Studio Mac',
  host: '10.0.0.2',
  port: 9741,
  serverId: 'mac-1',
);
const air = PeekDesktopFound(
  name: 'MacBook Air',
  host: '10.0.0.3',
  port: 9741,
  serverId: 'mac-2',
  isPaired: true,
);
const old = PeekDesktopFound(
  name: 'Old iMac',
  host: '10.0.0.4',
  port: 9741,
  isCompatible: false,
);

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

    testWidgets('reads in the dark too', (tester) async {
      final link = FakeDesktopLink(
        const PeekDesktopLinkState(
          status: PeekDesktopLinkStatus.connected,
          desktopName: 'Studio Mac',
        ),
      );
      await pumpScreen(tester, link: link, brightness: Brightness.dark);
      await openMenu(tester);
      await tester.tap(find.text('Connected to Studio Mac'));
      await settle(tester);
      expect(find.text('Disconnect'), findsOneWidget);
      await expectGolden(find.byType(MaterialApp), 'desktop-link-dark');
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
  group('pairing', () {
    const unpaired = PeekDesktopLinkState(
      status: PeekDesktopLinkStatus.unpaired,
    );
    final address = find.descendant(
      of: find.byWidgetPredicate(
        (widget) =>
            widget is CupertinoTextField &&
            widget.placeholder == '192.168.1.20:9741',
      ),
      matching: find.byType(EditableText),
    );
    final code = find.descendant(
      of: find.byType(PeekCodeField),
      matching: find.byType(EditableText),
    );

    Future<FakeDesktopLink> openPairing(
      WidgetTester tester, {
      PeekDesktopLinkState state = unpaired,
      String menu = 'Connect to Peek Pro',
      Brightness brightness = Brightness.light,
    }) async {
      final link = FakeDesktopLink(state);
      await pumpScreen(
        tester,
        link: link,
        brightness: brightness,
        size: const Size(420, 900),
      );
      await openMenu(tester);
      await tester.tap(find.text(menu));
      await settle(tester);
      return link;
    }

    Future<void> typeAddress(WidgetTester tester, String text) async {
      await tester.enterText(address, text);
      await settle(tester);
    }

    Future<void> typeCode(WidgetTester tester, String text) async {
      await tester.enterText(code, text);
      await settle(tester);
    }

    Future<void> unfocus(WidgetTester tester) async {
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(tester);
    }

    test('reads an address the way a person types it', () {
      expect(peekDesktopAddress('192.168.1.20'), (
        host: '192.168.1.20',
        port: 9741,
      ));
      expect(peekDesktopAddress(' 192.168.1.20:9000 '), (
        host: '192.168.1.20',
        port: 9000,
      ));
      expect(peekDesktopAddress('localhost'), (host: 'localhost', port: 9741));
      expect(peekDesktopAddress('ws://desk.local:9741/'), (
        host: 'desk.local',
        port: 9741,
      ));
      expect(peekDesktopAddress('[fe80::1]:9000'), (
        host: 'fe80::1',
        port: 9000,
      ));
      expect(peekDesktopAddress('[::1]'), (host: '::1', port: 9741));
      expect(peekDesktopAddress('fe80::1'), (host: 'fe80::1', port: 9741));
      for (final wrong in [
        '',
        'desk:port',
        'desk:0',
        'desk:70000',
        ':9741',
        'a b',
        'desk/path',
        '[::1',
        '[::1]x',
        '[]',
      ]) {
        expect(peekDesktopAddress(wrong), isNull, reason: wrong);
      }
    });

    testWidgets('lists the Macs nearby and pairs with the one picked', (
      tester,
    ) async {
      final link = await openPairing(tester);
      expect(find.text('Looking for Peek Pro…'), findsOneWidget);

      link.hear([studio, air, old]);
      await settle(tester);
      expect(find.text('Looking for Peek Pro…'), findsNothing);
      expect(find.text('Studio Mac'), findsOneWidget);
      expect(find.text('10.0.0.2'), findsOneWidget);
      expect(find.text('Paired — no code needed'), findsOneWidget);
      expect(find.text('Needs another version of Peek'), findsOneWidget);

      await tester.tap(find.text('Studio Mac'));
      await settle(tester);
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(link.connections, isEmpty);

      await typeCode(tester, '4719');
      expect(link.connections, [
        (
          host: '10.0.0.2',
          port: 9741,
          code: '4719',
          name: 'Studio Mac',
          serverId: 'mac-1',
        ),
      ]);

      link.moveTo(
        const PeekDesktopLinkState(
          status: PeekDesktopLinkStatus.connecting,
          desktopName: 'Studio Mac',
        ),
      );
      await settle(tester);
      expect(find.text('Connecting to Studio Mac…'), findsOneWidget);
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(find.text('ON THIS NETWORK'), findsOneWidget);

      link.moveTo(
        const PeekDesktopLinkState(
          status: PeekDesktopLinkStatus.connected,
          desktopName: 'Studio Mac',
        ),
      );
      await settle(tester);
      expect(find.text('Connected to Studio Mac'), findsOneWidget);
      expect(find.text('Disconnect'), findsOneWidget);
      expect(find.text('ON THIS NETWORK'), findsNothing);
    });

    testWidgets('connects to a paired Mac without a code', (tester) async {
      final link = await openPairing(tester);
      link.hear([studio, air, old]);
      await settle(tester);

      await tester.tap(find.text('Old iMac'));
      await settle(tester);
      expect(link.connections, isEmpty);

      await tester.tap(find.text('MacBook Air'));
      await settle(tester);
      expect(link.connections, [
        (
          host: '10.0.0.3',
          port: 9741,
          code: null,
          name: 'MacBook Air',
          serverId: 'mac-2',
        ),
      ]);
    });

    testWidgets('sends a code typed first once a Mac is picked', (
      tester,
    ) async {
      final link = await openPairing(tester);
      await typeCode(tester, '4719');
      expect(
        find.text('Choose a Mac above or type its address.'),
        findsOneWidget,
      );
      expect(link.connections, isEmpty);

      link.hear([studio]);
      await settle(tester);
      await tester.tap(find.text('Studio Mac'));
      await settle(tester);
      expect(
        find.text('Choose a Mac above or type its address.'),
        findsNothing,
      );
      expect(link.connections.single.code, '4719');
      expect(link.connections.single.serverId, 'mac-1');
    });

    testWidgets('takes an address typed by hand', (tester) async {
      final link = await openPairing(tester);
      expect(find.textContaining('10.0.2.2'), findsOneWidget);
      expect(find.textContaining('adb reverse tcp:9741'), findsOneWidget);

      await typeAddress(tester, 'desk:port');
      await typeCode(tester, '4719');
      expect(find.text("That doesn't look like an address."), findsOneWidget);
      expect(link.connections, isEmpty);

      await typeAddress(tester, '10.0.2.2');
      expect(find.text("That doesn't look like an address."), findsNothing);
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await settle(tester);
      expect(link.connections, [
        (
          host: '10.0.2.2',
          port: 9741,
          code: '4719',
          name: null,
          serverId: null,
        ),
      ]);
    });

    testWidgets('shakes off a refused code and asks to check it', (
      tester,
    ) async {
      final link = await openPairing(tester);
      await typeAddress(tester, '10.0.2.2');
      await typeCode(tester, '4719');
      expect(link.connections, hasLength(1));

      link.moveTo(
        const PeekDesktopLinkState(
          status: PeekDesktopLinkStatus.denied,
          desktopName: '10.0.2.2:9741',
          message: 'The code is wrong or has expired.',
          denial: PeekDesktopDenial.code,
          host: '10.0.2.2',
          port: 9741,
        ),
      );
      await settle(tester);
      expect(find.text('Check the code on the Mac.'), findsOneWidget);
      expect(find.text('The code is wrong or has expired.'), findsNothing);
      expect(
        tester.state<PeekCodeFieldState>(find.byType(PeekCodeField)).code,
        isEmpty,
      );

      await typeCode(tester, '1');
      expect(find.text('Check the code on the Mac.'), findsNothing);
      await typeCode(tester, '1234');
      expect(link.connections.last.code, '1234');
      expect(link.connections.last.host, '10.0.2.2');
    });

    testWidgets('says when the Mac does not answer, and lets it go', (
      tester,
    ) async {
      final link = await openPairing(tester);
      await typeAddress(tester, '10.0.2.2');
      await typeCode(tester, '4719');
      link.moveTo(
        const PeekDesktopLinkState(
          status: PeekDesktopLinkStatus.waiting,
          desktopName: '10.0.2.2:9741',
          host: '10.0.2.2',
          port: 9741,
        ),
      );
      await settle(tester);
      expect(
        find.text(
          "Can't reach 10.0.2.2:9741. Check that Peek Pro is open and on the "
          'same network.',
        ),
        findsOneWidget,
      );
      expect(find.text('ADDRESS'), findsOneWidget);

      await tester.tap(find.text('Disconnect'));
      await settle(tester);
      expect(link.calls.last, 'disconnect');
    });

    testWidgets('says when the versions differ', (tester) async {
      await openPairing(
        tester,
        state: const PeekDesktopLinkState(
          status: PeekDesktopLinkStatus.denied,
          desktopName: 'Studio Mac',
          message: 'protocol 2',
          denial: PeekDesktopDenial.protocolVersion,
        ),
        menu: 'Peek Pro turned the app away',
      );
      expect(
        find.textContaining('another version of the protocol'),
        findsOneWidget,
      );
      expect(find.text('protocol 2'), findsNothing);
    });

    testWidgets('connects again after a disconnect', (tester) async {
      final link = await openPairing(
        tester,
        state: const PeekDesktopLinkState(
          status: PeekDesktopLinkStatus.stopped,
          desktopName: 'Studio Mac',
          host: '10.0.0.2',
          port: 9741,
        ),
        menu: 'Not connected to Peek Pro',
      );
      expect(find.text('10.0.0.2'), findsOneWidget);
      await tester.tap(find.text('Connect again'));
      await settle(tester);
      expect(link.connections, [
        (
          host: '10.0.0.2',
          port: 9741,
          code: null,
          name: 'Studio Mac',
          serverId: null,
        ),
      ]);
    });

    testWidgets('says when the network cannot be searched', (tester) async {
      final link = await openPairing(tester);
      link.cannotSearch();
      await settle(tester);
      expect(find.textContaining("Can't look for Peek Pro"), findsOneWidget);
      expect(find.text('Looking for Peek Pro…'), findsNothing);
    });

    for (final brightness in Brightness.values) {
      final suffix = brightness.name;

      testWidgets('looks the part while pairing, $suffix', (tester) async {
        final link = await openPairing(tester, brightness: brightness);
        link.hear([studio, air, old]);
        await settle(tester);
        await expectGolden(find.byType(MaterialApp), 'desktop-pairing-$suffix');

        await typeAddress(tester, '10.0.2.2');
        await typeCode(tester, '4719');
        link.moveTo(
          const PeekDesktopLinkState(
            status: PeekDesktopLinkStatus.connecting,
            desktopName: '10.0.2.2:9741',
          ),
        );
        await settle(tester);
        await expectGolden(
          find.byType(MaterialApp),
          'desktop-connecting-$suffix',
        );

        link.moveTo(
          const PeekDesktopLinkState(
            status: PeekDesktopLinkStatus.denied,
            desktopName: '10.0.2.2:9741',
            denial: PeekDesktopDenial.code,
          ),
        );
        await settle(tester);
        await unfocus(tester);
        await expectGolden(
          find.byType(MaterialApp),
          'desktop-code-wrong-$suffix',
        );

        await typeCode(tester, '1234');
        link.moveTo(
          const PeekDesktopLinkState(
            status: PeekDesktopLinkStatus.waiting,
            desktopName: '10.0.2.2:9741',
          ),
        );
        await settle(tester);
        await unfocus(tester);
        await expectGolden(
          find.byType(MaterialApp),
          'desktop-unreachable-$suffix',
        );

        link.moveTo(
          const PeekDesktopLinkState(
            status: PeekDesktopLinkStatus.denied,
            desktopName: '10.0.2.2:9741',
            denial: PeekDesktopDenial.protocolVersion,
          ),
        );
        await settle(tester);
        await expectGolden(find.byType(MaterialApp), 'desktop-version-$suffix');
      });
    }
  });
}
