import 'package:flutter_test/flutter_test.dart';
import 'package:peek_remote/peek_remote.dart';
import 'package:peek_remote/src/discovery/peek_remote_discovery.dart';

void main() {
  group('peekRemoteHostOf', () {
    test('prefers IPv4, then the .local name, then IPv6 without a zone', () {
      expect(
        peekRemoteHostOf(['fe80::1%en0', '192.168.1.20'], 'mac.local.'),
        '192.168.1.20',
      );
      expect(peekRemoteHostOf(['fe80::1%en0'], 'mac.local.'), 'mac.local');
      expect(peekRemoteHostOf(['fe80::1%en0', 'fd00::5'], null), 'fd00::5');
      expect(peekRemoteHostOf(['fe80::1%en0'], ' '), isNull);
      expect(peekRemoteHostOf(const [], null), isNull);
    });
  });

  group('DiscoveredDesktops', () {
    test('keeps what resolved, by name, in name order', () {
      final desktops = DiscoveredDesktops();
      expect(
        desktops.found(
          name: 'studio',
          addresses: ['10.0.0.2'],
          hostname: null,
          port: 9741,
          attributes: {'protocolVersion': '1', 'serverId': 'mac-1'},
        ),
        isTrue,
      );
      desktops.found(
        name: 'Air',
        addresses: const [],
        hostname: 'air.local.',
        port: 9800,
        attributes: const {},
      );
      expect(desktops.list, [
        const PeekRemoteDiscovered(
          name: 'Air',
          endpoint: PeekRemoteEndpoint('air.local', port: 9800),
        ),
        const PeekRemoteDiscovered(
          name: 'studio',
          endpoint: PeekRemoteEndpoint('10.0.0.2'),
          protocolVersion: 1,
          serverId: 'mac-1',
        ),
      ]);
    });

    test('replaces a record that changed, and drops one that went', () {
      final desktops = DiscoveredDesktops()
        ..found(
          name: 'studio',
          addresses: ['10.0.0.2'],
          hostname: null,
          port: 9741,
          attributes: const {},
        )
        ..found(
          name: 'studio',
          addresses: ['10.0.0.9'],
          hostname: null,
          port: 9741,
          attributes: const {},
        );
      expect(desktops.list.single.endpoint.host, '10.0.0.9');
      expect(desktops.lost('studio'), isTrue);
      expect(desktops.lost('studio'), isFalse);
      expect(desktops.list, isEmpty);
    });

    test('ignores a record with nowhere to connect', () {
      final desktops = DiscoveredDesktops();
      expect(
        desktops.found(
          name: 'ghost',
          addresses: const [],
          hostname: null,
          port: 9741,
          attributes: const {},
        ),
        isFalse,
      );
      expect(
        desktops.found(
          name: 'zero',
          addresses: ['10.0.0.2'],
          hostname: null,
          port: 0,
          attributes: const {},
        ),
        isFalse,
      );
      expect(desktops.list, isEmpty);
    });

    test('reads what the record says leniently', () {
      final desktops = DiscoveredDesktops()
        ..found(
          name: 'odd',
          addresses: ['10.0.0.2'],
          hostname: null,
          port: 9741,
          attributes: {'protocolVersion': 'two', 'serverId': ''},
        );
      final desktop = desktops.list.single;
      expect(desktop.protocolVersion, isNull);
      expect(desktop.serverId, isNull);
      expect(desktop.isCompatible, isTrue);
    });
  });

  test('a desktop on another protocol is not compatible', () {
    const newer = PeekRemoteDiscovered(
      name: 'future',
      endpoint: PeekRemoteEndpoint('10.0.0.2'),
      protocolVersion: PeekRemoteProtocol.version + 1,
    );
    expect(newer.isCompatible, isFalse);
    expect(PeekRemoteDiscovery.serviceType, '_peek._tcp');
  });
}
