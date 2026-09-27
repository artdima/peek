import 'package:meta/meta.dart';

import 'peek_adapter.dart';

/// Where a link to a desktop viewer stands.
enum PeekDesktopLinkStatus {
  /// Nothing to connect to yet: no desktop is known. A code changes that.
  unpaired,

  /// Connecting, or waiting for the desktop to answer.
  connecting,

  /// Streaming to the desktop.
  connected,

  /// The connection dropped; trying again.
  waiting,

  /// The desktop turned the app away; see [PeekDesktopLinkState.message].
  denied,

  /// Told to stop.
  stopped,
}

/// Why a desktop turned the app away.
enum PeekDesktopDenial {
  /// The desktop does not know the app's token; a code pairs it again.
  token,

  /// The code is wrong or has expired.
  code,

  /// The desktop speaks another version of the protocol.
  protocolVersion,

  /// Anything else.
  other,
}

/// A link's status and the desktop it concerns, for the screen to show.
@immutable
final class PeekDesktopLinkState {
  /// Creates the state.
  const PeekDesktopLinkState({
    required this.status,
    this.desktopName,
    this.message,
    this.denial,
    this.host,
    this.port,
  });

  /// Where the link stands.
  final PeekDesktopLinkStatus status;

  /// The desktop as a person knows it — its name, or its address — when
  /// one is known.
  final String? desktopName;

  /// Why the desktop turned the app away, while [status] is
  /// [PeekDesktopLinkStatus.denied].
  final String? message;

  /// The kind of refusal behind [message].
  final PeekDesktopDenial? denial;

  /// Where the desktop listens, when the link knows.
  final String? host;

  /// The port it listens on, beside [host].
  final int? port;

  @override
  bool operator ==(Object other) =>
      other is PeekDesktopLinkState &&
      other.status == status &&
      other.desktopName == desktopName &&
      other.message == message &&
      other.denial == denial &&
      other.host == host &&
      other.port == port;

  @override
  int get hashCode =>
      Object.hash(status, desktopName, message, denial, host, port);

  @override
  String toString() => 'PeekDesktopLinkState(${status.name}, $desktopName)';
}

/// A desktop viewer heard on the local network.
@immutable
final class PeekDesktopFound {
  /// Creates the record.
  const PeekDesktopFound({
    required this.name,
    required this.host,
    required this.port,
    this.serverId,
    this.isPaired = false,
    this.isCompatible = true,
  });

  /// The name the desktop goes by on the network.
  final String name;

  /// The address to connect to.
  final String host;

  /// The port it listens on.
  final int port;

  /// The desktop's id, when it announces one; pairs it with a token held
  /// from before.
  final String? serverId;

  /// Whether the app holds a token from this desktop, so no code is needed.
  final bool isPaired;

  /// Whether it speaks the app's protocol; one that does not would turn the
  /// app away.
  final bool isCompatible;

  @override
  bool operator ==(Object other) =>
      other is PeekDesktopFound &&
      other.name == name &&
      other.host == host &&
      other.port == port &&
      other.serverId == serverId &&
      other.isPaired == isPaired &&
      other.isCompatible == isCompatible;

  @override
  int get hashCode =>
      Object.hash(name, host, port, serverId, isPaired, isCompatible);

  @override
  String toString() => 'PeekDesktopFound($name, $host:$port)';
}

/// An adapter that streams to a desktop viewer such as Peek Pro and can be
/// told where to connect — what the screen's "Connect to Peek Pro" needs,
/// with no word about how the streaming works. `peek_remote` provides one;
/// the screen finds it among `Peek.adapters`.
abstract interface class PeekDesktopLink implements PeekAdapter {
  /// The port a desktop listens on unless told otherwise.
  static const int defaultPort = 9741;

  /// Where the link stands now.
  PeekDesktopLinkState get linkState;

  /// Every change of [linkState].
  Stream<PeekDesktopLinkState> get linkChanges;

  /// The desktops on the local network, as they come and go; listening
  /// starts the search and cancelling stops it. An error means the search
  /// is not possible here, not that nothing is there.
  Stream<List<PeekDesktopFound>> watchDesktops();

  /// Connects to the desktop at [host]:[port]: with the [code] it shows to
  /// pair, or without one to a desktop that knows this device. [name] is what
  /// a person knows the desktop as; [serverId], when known, says which token
  /// to send.
  Future<void> connectDesktop(
    String host,
    int port, {
    String? code,
    String? name,
    String? serverId,
  });

  /// Disconnects; [connectDesktop] connects again.
  Future<void> disconnectDesktop();

  /// Drops the desktop and whatever let the app in without a code.
  Future<void> forgetDesktop();
}
