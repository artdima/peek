import 'package:meta/meta.dart';
import 'package:peek/core.dart';

/// One message between an app and a desktop viewer.
///
/// Frames travel as WebSocket text messages, one JSON object each, with a
/// `type` saying which frame it is; `doc/spec/remote-protocol.md` describes
/// them all. Entries and bodies inside use the same JSON as a `.peek` file.
@immutable
sealed class PeekRemoteFrame {
  const PeekRemoteFrame();
}

/// The app introduces itself; its first frame on every connection.
final class PeekRemoteHello extends PeekRemoteFrame {
  /// Creates a hello for [session], speaking [protocolVersion].
  const PeekRemoteHello({
    required this.sessionId,
    required this.session,
    this.protocolVersion = PeekRemoteProtocol.version,
    this.token,
  });

  /// The protocol the app speaks.
  final int protocolVersion;

  /// The token the desktop showed, as the app was given it.
  final String? token;

  /// Stays the same while the app runs, across reconnections, so the
  /// desktop knows a session it has seen before.
  final String sessionId;

  /// What the app says about itself: the header of a `.peek` file.
  final PeekSessionHeader session;

  @override
  bool operator ==(Object other) =>
      other is PeekRemoteHello &&
      other.protocolVersion == protocolVersion &&
      other.token == token &&
      other.sessionId == sessionId &&
      other.session == session;

  @override
  int get hashCode => Object.hash(protocolVersion, token, sessionId, session);

  @override
  String toString() => 'PeekRemoteHello($sessionId, v$protocolVersion)';
}

/// The desktop accepts the app; history and changes may follow.
final class PeekRemoteWelcome extends PeekRemoteFrame {
  /// Creates a welcome from a desktop speaking [protocolVersion].
  const PeekRemoteWelcome({
    this.protocolVersion = PeekRemoteProtocol.version,
    this.serverName,
    this.serverVersion,
  });

  /// The protocol the desktop speaks.
  final int protocolVersion;

  /// What the desktop calls itself, such as `Peek Pro`.
  final String? serverName;

  /// Its version.
  final String? serverVersion;

  @override
  bool operator ==(Object other) =>
      other is PeekRemoteWelcome &&
      other.protocolVersion == protocolVersion &&
      other.serverName == serverName &&
      other.serverVersion == serverVersion;

  @override
  int get hashCode => Object.hash(protocolVersion, serverName, serverVersion);

  @override
  String toString() => 'PeekRemoteWelcome(v$protocolVersion)';
}

/// Why a desktop turned an app away.
enum PeekRemoteDeniedReason {
  /// The token is missing or wrong.
  token,

  /// The desktop does not speak the app's protocol version.
  protocolVersion,

  /// Anything else; also what an unknown reason reads as.
  other,
}

/// The desktop turns the app away and closes the connection.
final class PeekRemoteDenied extends PeekRemoteFrame {
  /// Creates a refusal for [reason], explained by [message].
  const PeekRemoteDenied(this.reason, this.message);

  /// Why.
  final PeekRemoteDeniedReason reason;

  /// Why, for a person to read in the app's log.
  final String message;

  @override
  bool operator ==(Object other) =>
      other is PeekRemoteDenied &&
      other.reason == reason &&
      other.message == message;

  @override
  int get hashCode => Object.hash(reason, message);

  @override
  String toString() => 'PeekRemoteDenied(${reason.name})';
}

/// What happened to an entry.
enum PeekRemoteEntryOp {
  /// It is new to the desktop.
  add,

  /// It replaces the entry with the same id.
  update,

  /// It is gone.
  remove,
}

/// An entry the app added, changed or removed.
final class PeekRemoteEntry extends PeekRemoteFrame {
  /// A new entry.
  const PeekRemoteEntry.add(PeekEntry this.entry)
    : op = PeekRemoteEntryOp.add,
      id = null;

  /// A changed entry, replacing the one with the same id.
  const PeekRemoteEntry.update(PeekEntry this.entry)
    : op = PeekRemoteEntryOp.update,
      id = null;

  /// An entry that is gone.
  const PeekRemoteEntry.remove(PeekId this.id)
    : op = PeekRemoteEntryOp.remove,
      entry = null;

  /// What happened.
  final PeekRemoteEntryOp op;

  /// The entry, for [PeekRemoteEntryOp.add] and [PeekRemoteEntryOp.update].
  final PeekEntry? entry;

  /// The id, for [PeekRemoteEntryOp.remove].
  final PeekId? id;

  /// The id of the entry concerned, whichever the operation.
  PeekId get entryId => entry?.id ?? id!;

  @override
  bool operator ==(Object other) =>
      other is PeekRemoteEntry &&
      other.op == op &&
      other.entry == entry &&
      other.id == id;

  @override
  int get hashCode => Object.hash(op, entry, id);

  @override
  String toString() => 'PeekRemoteEntry(${op.name} $entryId)';
}

/// The app's store was emptied.
final class PeekRemoteCleared extends PeekRemoteFrame {
  /// Creates the frame.
  const PeekRemoteCleared();

  @override
  bool operator ==(Object other) => other is PeekRemoteCleared;

  @override
  int get hashCode => (PeekRemoteCleared).hashCode;

  @override
  String toString() => 'PeekRemoteCleared()';
}

/// The history the app sent after a welcome ends here; live changes follow.
final class PeekRemoteSynced extends PeekRemoteFrame {
  /// Creates the frame after [count] entries of history.
  const PeekRemoteSynced(this.count);

  /// How many entries the history held.
  final int count;

  @override
  bool operator ==(Object other) =>
      other is PeekRemoteSynced && other.count == count;

  @override
  int get hashCode => Object.hash(PeekRemoteSynced, count);

  @override
  String toString() => 'PeekRemoteSynced($count)';
}

/// The app could not keep up and threw frames away.
final class PeekRemoteDropped extends PeekRemoteFrame {
  /// Creates the frame for [count] frames thrown away.
  const PeekRemoteDropped(this.count);

  /// How many frames were lost since the last such frame.
  final int count;

  @override
  bool operator ==(Object other) =>
      other is PeekRemoteDropped && other.count == count;

  @override
  int get hashCode => Object.hash(PeekRemoteDropped, count);

  @override
  String toString() => 'PeekRemoteDropped($count)';
}

/// The desktop asks for a body the app held back.
final class PeekRemoteBodyRequest extends PeekRemoteFrame {
  /// Creates a request, named [requestId], for the body of [id] on [side].
  const PeekRemoteBodyRequest({
    required this.requestId,
    required this.id,
    required this.side,
  });

  /// Pairs the answer with the question.
  final String requestId;

  /// The entry.
  final PeekId id;

  /// Which of its bodies.
  final PeekBodySide side;

  @override
  bool operator ==(Object other) =>
      other is PeekRemoteBodyRequest &&
      other.requestId == requestId &&
      other.id == id &&
      other.side == side;

  @override
  int get hashCode => Object.hash(requestId, id, side);

  @override
  String toString() => 'PeekRemoteBodyRequest($requestId, $id ${side.name})';
}

/// Why the app could not answer a body request.
enum PeekRemoteBodyError {
  /// There is no such entry, or no response to hold the body.
  notFound,

  /// The entry is there but the body is not: it was never captured.
  notHeld,

  /// Anything else; also what an unknown error reads as.
  failed,
}

/// The app answers a body request: the body, or why not.
final class PeekRemoteBodyResponse extends PeekRemoteFrame {
  /// The body asked for.
  const PeekRemoteBodyResponse.body(this.requestId, PeekBody this.body)
    : error = null,
      message = null;

  /// Why the body cannot be had.
  const PeekRemoteBodyResponse.error(
    this.requestId,
    PeekRemoteBodyError this.error, [
    this.message,
  ]) : body = null;

  /// The request this answers.
  final String requestId;

  /// The body, when there is one.
  final PeekBody? body;

  /// Why not, when there is no body.
  final PeekRemoteBodyError? error;

  /// Why not, for a person to read.
  final String? message;

  @override
  bool operator ==(Object other) =>
      other is PeekRemoteBodyResponse &&
      other.requestId == requestId &&
      other.body == body &&
      other.error == error &&
      other.message == message;

  @override
  int get hashCode => Object.hash(requestId, body, error, message);

  @override
  String toString() =>
      'PeekRemoteBodyResponse($requestId, ${error?.name ?? 'body'})';
}

/// Asks the other side to show it is still there.
final class PeekRemotePing extends PeekRemoteFrame {
  /// Creates the frame.
  const PeekRemotePing();

  @override
  bool operator ==(Object other) => other is PeekRemotePing;

  @override
  int get hashCode => (PeekRemotePing).hashCode;

  @override
  String toString() => 'PeekRemotePing()';
}

/// Answers a ping.
final class PeekRemotePong extends PeekRemoteFrame {
  /// Creates the frame.
  const PeekRemotePong();

  @override
  bool operator ==(Object other) => other is PeekRemotePong;

  @override
  int get hashCode => (PeekRemotePong).hashCode;

  @override
  String toString() => 'PeekRemotePong()';
}

/// A frame of a type this side does not know, from a newer peer.
///
/// Ignore it and carry on: a new frame type never needs a new protocol
/// version, because an older peer loses nothing it could have used.
final class PeekRemoteUnknownFrame extends PeekRemoteFrame {
  /// Creates the frame for a [type] nobody here knows.
  const PeekRemoteUnknownFrame(this.type);

  /// The `type` it arrived with.
  final String type;

  @override
  bool operator ==(Object other) =>
      other is PeekRemoteUnknownFrame && other.type == type;

  @override
  int get hashCode => Object.hash(PeekRemoteUnknownFrame, type);

  @override
  String toString() => 'PeekRemoteUnknownFrame($type)';
}

/// The fixed parts of the protocol.
abstract final class PeekRemoteProtocol {
  /// The protocol version this package speaks.
  ///
  /// It goes up only when an older peer would misread a frame; new frame
  /// types, keys and values do not raise it.
  static const int version = 1;

  /// The port a desktop listens on unless told otherwise.
  static const int defaultPort = 9741;

  /// Decides whether a desktop accepts [hello]: `null` to welcome it, or the
  /// refusal to send.
  ///
  /// [token] is the one the desktop showed; `null` accepts any app. The
  /// desktop speaks versions [oldest] to [newest].
  static PeekRemoteDenied? check(
    PeekRemoteHello hello, {
    required String? token,
    int oldest = version,
    int newest = version,
  }) {
    final spoken = hello.protocolVersion;
    if (spoken < oldest || spoken > newest) {
      return PeekRemoteDenied(
        PeekRemoteDeniedReason.protocolVersion,
        'The app speaks protocol $spoken, this desktop '
        '${oldest == newest ? '$newest' : '$oldest to $newest'}. '
        'Update ${spoken < oldest ? 'Peek in the app' : 'the desktop'}.',
      );
    }
    if (token != null && !_sameToken(hello.token, token)) {
      return const PeekRemoteDenied(
        PeekRemoteDeniedReason.token,
        'The token does not match the one the desktop shows.',
      );
    }
    return null;
  }

  // Compares every character, so the time taken says nothing about how much
  // of a guess was right.
  static bool _sameToken(String? given, String expected) {
    if (given == null || given.length != expected.length) return false;
    var difference = 0;
    for (var i = 0; i < expected.length; i++) {
      difference |= given.codeUnitAt(i) ^ expected.codeUnitAt(i);
    }
    return difference == 0;
  }
}
