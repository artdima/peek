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

/// A link's status and the desktop it concerns, for the screen to show.
@immutable
final class PeekDesktopLinkState {
  /// Creates the state.
  const PeekDesktopLinkState({
    required this.status,
    this.desktopName,
    this.message,
  });

  /// Where the link stands.
  final PeekDesktopLinkStatus status;

  /// The desktop as a person knows it — its name, or its address — when
  /// one is known.
  final String? desktopName;

  /// Why the desktop turned the app away, while [status] is
  /// [PeekDesktopLinkStatus.denied].
  final String? message;

  @override
  bool operator ==(Object other) =>
      other is PeekDesktopLinkState &&
      other.status == status &&
      other.desktopName == desktopName &&
      other.message == message;

  @override
  int get hashCode => Object.hash(status, desktopName, message);

  @override
  String toString() => 'PeekDesktopLinkState(${status.name}, $desktopName)';
}

/// An adapter that streams to a desktop viewer such as Peek Pro and can be
/// told where to connect — what the screen's "Connect to Peek Pro" needs,
/// with no word about how the streaming works. `peek_remote` provides one;
/// the screen finds it among `Peek.adapters`.
abstract interface class PeekDesktopLink implements PeekAdapter {
  /// Where the link stands now.
  PeekDesktopLinkState get linkState;

  /// Every change of [linkState].
  Stream<PeekDesktopLinkState> get linkChanges;

  /// Connects to the desktop at [host]:[port]: with the [code] it shows to
  /// pair, or without one to a desktop that knows this device. [name] is what
  /// a person knows the desktop as.
  Future<void> connectDesktop(
    String host,
    int port, {
    String? code,
    String? name,
  });

  /// Disconnects; [connectDesktop] connects again.
  Future<void> disconnectDesktop();

  /// Drops the desktop and whatever let the app in without a code.
  Future<void> forgetDesktop();
}
