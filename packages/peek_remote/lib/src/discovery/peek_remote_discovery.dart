import 'package:meta/meta.dart';

import '../client/peek_remote_endpoint.dart';
import '../protocol/peek_remote_frame.dart';
import 'bonjour_discovery.dart';

/// A desktop heard on the local network: what its Bonjour record says.
@immutable
final class PeekRemoteDiscovered {
  /// Creates the record.
  const PeekRemoteDiscovered({
    required this.name,
    required this.endpoint,
    this.protocolVersion,
    this.serverId,
  });

  /// The name the desktop goes by on the network, such as `MacBook Pro`.
  final String name;

  /// Where to connect.
  final PeekRemoteEndpoint endpoint;

  /// The newest protocol the desktop speaks, when it says.
  final int? protocolVersion;

  /// The desktop's id, when it says: the one a device token is kept under.
  final String? serverId;

  /// Whether the desktop speaks this package's protocol; one that does not
  /// say is given the benefit of the doubt.
  bool get isCompatible =>
      protocolVersion == null || protocolVersion == PeekRemoteProtocol.version;

  @override
  bool operator ==(Object other) =>
      other is PeekRemoteDiscovered &&
      other.name == name &&
      other.endpoint == endpoint &&
      other.protocolVersion == protocolVersion &&
      other.serverId == serverId;

  @override
  int get hashCode => Object.hash(name, endpoint, protocolVersion, serverId);

  @override
  String toString() => 'PeekRemoteDiscovered($name, $endpoint)';
}

/// Finds desktops on the local network.
///
/// [PeekRemoteDiscovery.bonjour] browses `_peek._tcp` with the platform's own
/// Bonjour; on iOS the app needs `NSLocalNetworkUsageDescription` and
/// `_peek._tcp` in `NSBonjourServices`. Many networks block multicast, so
/// an address typed in always works too.
abstract interface class PeekRemoteDiscovery {
  /// Browses with the platform's Bonjour — `NSNetService` on Apple
  /// platforms, `NsdManager` on Android — through `bonsoir`.
  factory PeekRemoteDiscovery.bonjour() = BonjourDiscovery;

  /// The Bonjour service type desktops announce.
  static const String serviceType = '_peek._tcp';

  /// Every change of what is found, in name order; listening starts the
  /// search and cancelling stops it. An error means the search is not
  /// possible here — no plugin on this platform, say.
  Stream<List<PeekRemoteDiscovered>> watch();
}

/// What a Bonjour search has found so far, from the records as they come
/// and go; kept apart from the plugin so it can be tested without one.
@internal
final class DiscoveredDesktops {
  final Map<String, PeekRemoteDiscovered> _byName = {};

  /// Everything found, in name order.
  List<PeekRemoteDiscovered> get list =>
      _byName.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  /// A resolved record; `false` when it names nowhere to connect.
  bool found({
    required String name,
    required List<String> addresses,
    required String? hostname,
    required int port,
    required Map<String, String> attributes,
  }) {
    final host = peekRemoteHostOf(addresses, hostname);
    if (host == null || port <= 0) return false;
    _byName[name] = PeekRemoteDiscovered(
      name: name,
      endpoint: PeekRemoteEndpoint(host, port: port),
      protocolVersion: int.tryParse(attributes['protocolVersion'] ?? ''),
      serverId: switch (attributes['serverId']) {
        final String id when id.isNotEmpty => id,
        _ => null,
      },
    );
    return true;
  }

  /// A record gone; `false` when it was never on the list.
  bool lost(String name) => _byName.remove(name) != null;
}

/// The address to connect to among what a record resolved to: IPv4 first,
/// because every client and network handles it; then the `.local` name;
/// then IPv6 without a zone, which a URI cannot carry.
@internal
String? peekRemoteHostOf(List<String> addresses, String? hostname) {
  final ipv4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');
  for (final address in addresses) {
    if (ipv4.hasMatch(address)) return address;
  }
  final name = hostname?.trim();
  if (name != null && name.isNotEmpty) {
    return name.endsWith('.') ? name.substring(0, name.length - 1) : name;
  }
  for (final address in addresses) {
    if (address.contains(':') && !address.contains('%')) return address;
  }
  return null;
}
