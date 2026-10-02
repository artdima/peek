import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:peek/core.dart';

import '../discovery/peek_remote_discovery.dart';
import '../protocol/peek_remote_codec.dart';
import '../protocol/peek_remote_frame.dart';
import '../transport/peek_remote_transport.dart';
import 'peek_remote_endpoint.dart';
import 'peek_remote_memory.dart';

/// Where a [PeekRemote] is in its life.
enum PeekRemoteState {
  /// Not started, or stopped.
  stopped,

  /// Connecting, or waiting for the desktop to answer the hello.
  connecting,

  /// Welcomed: sending what the store holds and every change.
  connected,

  /// The connection failed or dropped; trying again after a pause.
  waiting,

  /// The desktop turned the app away; see [PeekRemote.denial]. It does not
  /// try again until started anew.
  denied,

  /// Nothing to connect to: no desktop was given, and none is remembered.
  /// [PeekRemote.connect] with a code changes that.
  unpaired,
}

/// The desktop turned the app away; reported to `PeekOptions.onError`.
final class PeekRemoteDeniedException implements Exception {
  /// Creates the exception for [denial].
  const PeekRemoteDeniedException(this.denial);

  /// What the desktop said.
  final PeekRemoteDenied denial;

  @override
  String toString() =>
      'PeekRemoteDeniedException(${denial.reason.name}: ${denial.message})';
}

/// Streams what [peek] records to a desktop viewer such as Peek Pro.
///
/// ```dart
/// final remote = peek.attach(
///   PeekRemote(
///     peek,
///     endpoint: PeekRemoteEndpoint.parse('192.168.1.20:9741'),
///     token: 'k7Qx2mP9',
///   ),
/// )..start();
/// ```
///
/// The app is the client: it connects, says hello with the [token] the
/// desktop shows, and after the welcome sends what the store holds and then
/// every change. Bodies larger than [inlineBodyBytes] stay in the app until
/// the desktop asks for one.
///
/// Instead of a token in code, a person can type the short code the desktop
/// shows: [connect] with a `code` sends it, and the desktop answers with a
/// [deviceToken] that this client uses from then on. The desktop and the
/// token go into [PeekRemoteMemory], so a client created without an
/// [endpoint] finds its way back on the next run:
///
/// ```dart
/// peek.attach(PeekRemote(peek)..start());
/// ```
///
/// Recording never waits for the network: a change is written to a queue of
/// at most [maxQueued] frames and sent on the next turn of the event loop.
/// When the queue is full the oldest frames go, and the desktop is told how
/// many with a `dropped` frame. A lost connection is tried again after a
/// pause that grows up to [retryMax]; the history is sent again after every
/// welcome. Nothing here throws into the app: errors reach
/// `PeekOptions.onError`.
final class PeekRemote implements PeekAdapter, PeekDesktopLink {
  /// Creates the client; nothing is sent until [start].
  ///
  /// With [endpoint] (and usually [token]) the desktop is fixed in code;
  /// without it, [start] goes to the desktop remembered in [memory], and a
  /// person pairs with a code when there is none. [name] is what the desktop
  /// calls the app; `PeekOptions.name` when omitted.
  PeekRemote(
    this.peek, {
    PeekRemoteEndpoint? endpoint,
    this.token,
    String? name,
    PeekRemoteMemory? memory,
    PeekRemoteDiscovery? discovery,
    this.maxQueued = 2000,
    this.inlineBodyBytes = 4096,
    this.retryMin = const Duration(milliseconds: 500),
    this.retryMax = const Duration(seconds: 30),
    PeekRemoteTransport? transport,
    math.Random? random,
  }) : appName = name ?? peek.options.name,
       _givenEndpoint = endpoint,
       _endpoint = endpoint,
       _memory = memory ?? PeekRemoteMemory.sharedPreferences(),
       _discovery = discovery ?? PeekRemoteDiscovery.bonjour(),
       _transport = transport ?? PeekRemoteTransport.webSocket(),
       _random = random ?? math.Random(),
       _sessionId = _newSessionId(),
       _startedAt = peek.options.clock.now().toUtc();

  /// The instance whose store is sent.
  final Peek peek;

  /// The token the desktop shows, as written in code; `null` when it asks
  /// for none or the app pairs with a code instead.
  final String? token;

  /// What the desktop calls the app.
  final String? appName;

  /// How many frames wait to be sent before the oldest are thrown away.
  final int maxQueued;

  /// Bodies up to this many bytes travel with their call; larger ones stay
  /// here until asked for.
  final int inlineBodyBytes;

  /// The pause before the first retry.
  final Duration retryMin;

  /// The longest pause between retries.
  final Duration retryMax;

  final PeekRemoteTransport _transport;
  final PeekRemoteMemory _memory;
  final PeekRemoteDiscovery _discovery;
  final math.Random _random;
  final String _sessionId;
  final DateTime _startedAt;
  final PeekRemoteEndpoint? _givenEndpoint;

  PeekRemoteEndpoint? _endpoint;
  String? _code;
  String? _deviceToken;
  String? _serverId;

  /// What a person called the desktop being connected to, kept until the
  /// welcome makes it a [PeekRemoteDesktop].
  String? _desktopName;
  PeekRemoteDesktop? _desktop;

  static const PeekRemoteCodec _codec = PeekRemoteCodec();

  final ListQueue<String> _queue = ListQueue();
  final StreamController<PeekRemoteState> _states =
      StreamController.broadcast();

  PeekRemoteState _state = PeekRemoteState.stopped;
  PeekRemoteDenied? _denial;
  PeekDesktopFailure? _failure;
  // The desktop let this client in, now or in an earlier run.
  bool _admitted = false;
  PeekRemoteConnection? _connection;
  StreamSubscription<String>? _messages;
  StreamSubscription<PeekStoreChange>? _changes;
  Timer? _retry;
  bool _running = false;
  bool _welcomed = false;
  bool _drainScheduled = false;
  bool _disposed = false;
  int _attempts = 0;
  int _dropped = 0;
  // Bumped whenever a connection ends, so the callbacks of an old one do
  // nothing to the next.
  int _generation = 0;

  @override
  String get name => 'remote';

  @override
  PeekDesktopLinkState get linkState => PeekDesktopLinkState(
    status: switch (_state) {
      PeekRemoteState.stopped => PeekDesktopLinkStatus.stopped,
      PeekRemoteState.connecting => PeekDesktopLinkStatus.connecting,
      PeekRemoteState.connected => PeekDesktopLinkStatus.connected,
      PeekRemoteState.waiting => PeekDesktopLinkStatus.waiting,
      PeekRemoteState.denied => PeekDesktopLinkStatus.denied,
      PeekRemoteState.unpaired => PeekDesktopLinkStatus.unpaired,
    },
    desktopName: _desktop?.name ?? _desktopName ?? _endpoint?.toString(),
    message: _denial?.message,
    denial: switch (_denial?.reason) {
      null => null,
      PeekRemoteDeniedReason.token => PeekDesktopDenial.token,
      PeekRemoteDeniedReason.code => PeekDesktopDenial.code,
      PeekRemoteDeniedReason.protocolVersion =>
        PeekDesktopDenial.protocolVersion,
      PeekRemoteDeniedReason.other => PeekDesktopDenial.other,
    },
    failure: _state == PeekRemoteState.waiting ? _failure : null,
    isPaired: _admitted,
    host: _endpoint?.host,
    port: _endpoint?.port,
  );

  @override
  Stream<PeekDesktopLinkState> get linkChanges =>
      _states.stream.map((_) => linkState);

  @override
  Stream<List<PeekDesktopFound>> watchDesktops() => _discovery.watch().map(
    (desktops) => [
      for (final desktop in desktops)
        PeekDesktopFound(
          name: desktop.name,
          host: desktop.endpoint.host,
          port: desktop.endpoint.port,
          serverId: desktop.serverId,
          isPaired:
              desktop.serverId != null &&
              desktop.serverId == (_serverId ?? _desktop?.serverId) &&
              _deviceToken != null,
          isCompatible: desktop.isCompatible,
        ),
    ],
  );

  /// Desktops on the local network, as [PeekRemoteDiscovery] finds them.
  Stream<List<PeekRemoteDiscovered>> discover() => _discovery.watch();

  @override
  Future<void> connectDesktop(
    String host,
    int port, {
    String? code,
    String? name,
    String? serverId,
  }) => connect(
    PeekRemoteEndpoint(host, port: port),
    code: code,
    name: name,
    serverId: serverId,
  );

  @override
  Future<void> disconnectDesktop() => stop();

  @override
  Future<void> forgetDesktop() => forget();

  /// Where the client is now.
  PeekRemoteState get state => _state;

  /// Every change of [state].
  Stream<PeekRemoteState> get stateChanges => _states.stream;

  /// Why the desktop turned the app away, while [state] is
  /// [PeekRemoteState.denied].
  PeekRemoteDenied? get denial => _denial;

  /// Identifies this run of the app to the desktop, across reconnections.
  String get sessionId => _sessionId;

  /// Where the desktop listens: what the client was created with, what it
  /// remembers, or where it was last told to connect; `null` until one of
  /// those.
  PeekRemoteEndpoint? get endpoint => _endpoint;

  /// The token a desktop issued for a right code, sent as the token from
  /// then on; `null` until a pairing succeeds, and again once a desktop
  /// refuses it.
  String? get deviceToken => _deviceToken;

  /// The desktop the [deviceToken] came from, as its `welcome` named it.
  String? get serverId => _serverId;

  /// The desktop paired with, once its welcome has been heard.
  PeekRemoteDesktop? get desktop => _desktop;

  /// Connects, and keeps connecting until [stop]. Safe to call twice.
  ///
  /// Without an endpoint the remembered desktop is tried; with none
  /// remembered the state becomes [PeekRemoteState.unpaired] and nothing
  /// happens until [connect].
  void start() {
    if (_running || _disposed) return;
    _running = true;
    _denial = null;
    _failure = null;
    _attempts = 0;
    if (_endpoint != null) {
      unawaited(_connect());
    } else {
      unawaited(_startFromMemory());
    }
  }

  /// Connects to [endpoint] and keeps connecting until [stop]: with the
  /// [code] the desktop shows in place of a token, or, without one, with the
  /// token this client holds — a device token from an earlier pairing, or
  /// the one written in code.
  ///
  /// A right code is answered with a [deviceToken], which replaces the code
  /// from then on and is remembered with the desktop; a wrong one ends in
  /// [PeekRemoteState.denied] with [PeekRemoteDeniedReason.code]. [name] is
  /// what a person knows the desktop as, kept with it. [serverId], when the
  /// network said it, picks the token: this desktop's own, or none — never
  /// another desktop's.
  Future<void> connect(
    PeekRemoteEndpoint endpoint, {
    String? code,
    String? name,
    String? serverId,
  }) async {
    if (_disposed) return;
    final typed = code?.trim();
    if (typed != null && typed.isEmpty) {
      throw ArgumentError.value(code, 'code', 'must not be empty');
    }
    final previous = _endConnection();
    final known = _serverId ?? _desktop?.serverId;
    _endpoint = endpoint;
    _code = typed;
    _desktopName = name;
    if (typed != null || (serverId != null && serverId != known)) {
      _deviceToken = null;
      _serverId = null;
      _desktop = null;
      _admitted = false;
    }
    _denial = null;
    _failure = null;
    _attempts = 0;
    _running = true;
    if (typed != null || _deviceToken != null) {
      unawaited(_connect());
    } else {
      // A known desktop at a new address: its token is in memory.
      unawaited(_connectRecalling(serverId));
    }
    await previous?.close();
  }

  /// Disconnects and stops trying. Safe to call twice.
  Future<void> stop() async {
    _running = false;
    _failure = null;
    final connection = _endConnection();
    _setState(PeekRemoteState.stopped);
    await connection?.close();
  }

  /// Drops the desktop and its token, here and in memory, and disconnects:
  /// the next connection needs a code again.
  Future<void> forget() async {
    final serverId = _serverId ?? _desktop?.serverId;
    _running = false;
    final connection = _endConnection();
    _deviceToken = null;
    _serverId = null;
    _desktop = null;
    _desktopName = null;
    _code = null;
    _admitted = false;
    _failure = null;
    _endpoint = _givenEndpoint;
    _setState(
      _endpoint == null ? PeekRemoteState.unpaired : PeekRemoteState.stopped,
    );
    await connection?.close();
    if (serverId != null) await _remember(() => _memory.forget(serverId));
  }

  Future<void> _startFromMemory() async {
    final generation = _generation;
    _setState(PeekRemoteState.connecting);
    final recalled = await _recall(generation);
    if (generation != _generation || !_running) return;
    if (!recalled) {
      _running = false;
      _setState(PeekRemoteState.unpaired);
      return;
    }
    _endpoint = _desktop!.endpoint;
    unawaited(_connect());
  }

  Future<void> _connectRecalling(String? serverId) async {
    final generation = _generation;
    _setState(PeekRemoteState.connecting);
    await _recall(generation, serverId: serverId);
    if (generation != _generation || !_running) return;
    unawaited(_connect());
  }

  /// Takes a desktop and its token from memory — the one [serverId] names,
  /// or else the last one; `false` when there is none, or the client moved
  /// on meanwhile.
  Future<bool> _recall(int generation, {String? serverId}) async {
    PeekRemoteDesktop? desktop;
    String? deviceToken;
    try {
      final last = await _memory.lastDesktop();
      if (serverId == null) {
        desktop = last;
      } else if (last?.serverId == serverId) {
        desktop = last;
      } else if (_endpoint case final endpoint?) {
        desktop = PeekRemoteDesktop(
          serverId: serverId,
          endpoint: endpoint,
          name: _desktopName,
        );
      }
      if (desktop != null) deviceToken = await _memory.token(desktop.serverId);
    } on Object catch (error, stackTrace) {
      peek.reportAdapterError(error, stackTrace);
    }
    if (generation != _generation || !_running) return false;
    if (desktop == null || deviceToken == null) return false;
    _desktop = desktop;
    _desktopName ??= desktop.name;
    _serverId = desktop.serverId;
    _deviceToken = deviceToken;
    _admitted = true;
    return true;
  }

  /// Memory is best effort: a store that fails must not take the stream down.
  Future<void> _remember(Future<void> Function() write) async {
    try {
      await write();
    } on Object catch (error, stackTrace) {
      peek.reportAdapterError(error, stackTrace);
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(stop().whenComplete(_states.close));
  }

  Future<void> _connect() async {
    final generation = ++_generation;
    _setState(PeekRemoteState.connecting);
    final PeekRemoteConnection connection;
    try {
      connection = await _transport.connect(_endpoint!.uri);
    } on Object catch (error) {
      // A desktop that is not listening is the usual case, not an error.
      if (generation == _generation && _running) {
        _failure = error is PeekRemoteConnectException
            ? error.failure
            : PeekDesktopFailure.other;
        _waitAndRetry();
      }
      return;
    }
    if (generation != _generation || !_running) {
      unawaited(connection.close());
      return;
    }
    _connection = connection;
    _welcomed = false;
    _messages = connection.messages.listen(
      (message) => _onMessage(generation, message),
      onError: (Object _) => _onClosed(generation),
      onDone: () => _onClosed(generation),
      cancelOnError: true,
    );
    // The code goes alone; once the desktop has answered it with a device
    // token, that token goes instead, ahead of any written in code.
    _send(
      PeekRemoteHello(
        sessionId: _sessionId,
        token: _code == null ? _deviceToken ?? token : null,
        code: _code,
        session: PeekSessionHeader.current(
          startedAt: _startedAt,
          name: appName,
        ),
      ),
    );
  }

  void _onMessage(int generation, String message) {
    if (generation != _generation) return;
    final PeekRemoteFrame frame;
    try {
      frame = _codec.decode(message);
    } on FormatException {
      // The protocol drops a frame it cannot read and carries on.
      return;
    }
    try {
      switch (frame) {
        case PeekRemoteWelcome() when !_welcomed:
          _onWelcome(frame);
        case PeekRemoteDenied() when !_welcomed:
          _onDenied(frame);
        case PeekRemoteBodyRequest() when _welcomed:
          _answer(frame);
        case PeekRemotePing():
          _send(const PeekRemotePong());
        default:
          break;
      }
    } on Object catch (error, stackTrace) {
      peek.reportAdapterError(error, stackTrace);
    }
  }

  void _onWelcome(PeekRemoteWelcome welcome) {
    _welcomed = true;
    _admitted = true;
    _failure = null;
    _attempts = 0;
    if (welcome.deviceToken case final issued?) {
      _deviceToken = issued;
      _serverId = welcome.serverId;
      _code = null;
    }
    // A paired desktop is remembered where it answered from, with the token
    // it issued; one taking the token written in code is not the app's to keep.
    if (_deviceToken case final deviceToken?) {
      if (_serverId case final serverId?) {
        final desktop = PeekRemoteDesktop(
          serverId: serverId,
          endpoint: _endpoint!,
          name: _desktopName ?? _desktop?.name,
        );
        final issued = welcome.deviceToken != null;
        if (desktop != _desktop || issued) {
          _desktop = desktop;
          unawaited(
            _remember(
              () =>
                  _memory.remember(desktop, token: issued ? deviceToken : null),
            ),
          );
        }
      }
    }
    _setState(PeekRemoteState.connected);
    final history = peek.store.entries;
    _changes = peek.store.changes.listen(_onChange);
    for (final entry in history) {
      _enqueue(PeekRemoteEntry.add(_outgoing(entry)));
    }
    _enqueue(PeekRemoteSynced(history.length));
  }

  void _onDenied(PeekRemoteDenied denial) {
    _running = false;
    _denial = denial;
    switch (denial.reason) {
      case PeekRemoteDeniedReason.code:
        // Burnt on the desktop's side too; the next try needs a fresh one.
        _code = null;
      case PeekRemoteDeniedReason.token when _deviceToken != null:
        // The desktop forgot this device: pair again.
        _deviceToken = null;
        _admitted = false;
        final serverId = _serverId ?? _desktop?.serverId;
        _serverId = null;
        _desktop = null;
        if (serverId != null) {
          unawaited(_remember(() => _memory.forget(serverId)));
        }
      default:
        break;
    }
    final connection = _endConnection();
    _setState(PeekRemoteState.denied);
    unawaited(connection?.close());
    peek.reportAdapterError(
      PeekRemoteDeniedException(denial),
      StackTrace.current,
    );
  }

  void _onClosed(int generation) {
    if (generation != _generation) return;
    final connection = _endConnection();
    unawaited(connection?.close());
    if (_running) {
      _failure = PeekDesktopFailure.dropped;
      _waitAndRetry();
    }
  }

  void _waitAndRetry() {
    _setState(PeekRemoteState.waiting);
    final exponent = math.min(_attempts, 16);
    _attempts++;
    final ceiling = math.min(
      retryMin.inMicroseconds * math.pow(2, exponent),
      retryMax.inMicroseconds.toDouble(),
    );
    // Half fixed, half random: apps that lost the desktop together do not
    // all come back in the same instant.
    final delay = Duration(
      microseconds: (ceiling * (0.5 + _random.nextDouble() / 2)).round(),
    );
    _retry = Timer(delay, () {
      if (_running) unawaited(_connect());
    });
  }

  /// Forgets the current connection and returns it for closing.
  PeekRemoteConnection? _endConnection() {
    _generation++;
    _retry?.cancel();
    _retry = null;
    unawaited(_messages?.cancel());
    _messages = null;
    unawaited(_changes?.cancel());
    _changes = null;
    _queue.clear();
    _dropped = 0;
    _welcomed = false;
    final connection = _connection;
    _connection = null;
    return connection;
  }

  void _onChange(PeekStoreChange change) {
    try {
      _enqueue(switch (change) {
        PeekEntryAdded(:final entry) => PeekRemoteEntry.add(_outgoing(entry)),
        PeekEntryUpdated(:final entry) => PeekRemoteEntry.update(
          _outgoing(entry),
        ),
        PeekEntryRemoved(:final entry) => PeekRemoteEntry.remove(entry.id),
        PeekStoreCleared() => const PeekRemoteCleared(),
      });
    } on Object catch (error, stackTrace) {
      peek.reportAdapterError(error, stackTrace);
    }
  }

  void _answer(PeekRemoteBodyRequest request) {
    final body = peek.store.find(request.id)?.bodyOn(request.side);
    _send(switch (body) {
      null => PeekRemoteBodyResponse.error(
        request.requestId,
        PeekRemoteBodyError.notFound,
        'No ${request.side.name} body for ${request.id} in the app.',
      ),
      PeekUnavailableBody() || PeekRemoteBody() => PeekRemoteBodyResponse.error(
        request.requestId,
        PeekRemoteBodyError.notHeld,
        'The app never had this body.',
      ),
      _ => PeekRemoteBodyResponse.body(request.requestId, body),
    });
  }

  /// [entry] with its large bodies held back.
  PeekEntry _outgoing(PeekEntry entry) {
    final request = _holdBack(entry.request.body);
    final response = entry.response;
    final responseBody = response == null ? null : _holdBack(response.body);
    if (request == null && responseBody == null) return entry;
    return entry.copyWith(
      request: request == null ? null : entry.request.copyWith(body: request),
      response: responseBody == null
          ? null
          : response!.copyWith(body: responseBody),
    );
  }

  /// The marker to send in place of [body], or `null` to send it as it is.
  PeekBody? _holdBack(PeekBody body) {
    final held = switch (body) {
      PeekTextBody(:final capturedSize) => capturedSize,
      PeekBytesBody(:final bytes) => bytes.length,
      _ => 0,
    };
    if (held <= inlineBodyBytes) return null;
    return PeekBody.remote(
      size: body.size ?? held,
      contentType: body.contentType,
      isTruncated: body.isTruncated,
    );
  }

  void _enqueue(PeekRemoteFrame frame) {
    if (!_welcomed) return;
    if (_queue.length >= maxQueued) {
      _queue.removeFirst();
      _dropped++;
    }
    _queue.add(_codec.encode(frame));
    if (_drainScheduled) return;
    _drainScheduled = true;
    Timer.run(_drain);
  }

  void _drain() {
    _drainScheduled = false;
    final connection = _connection;
    if (connection == null || !_welcomed) return;
    if (_dropped > 0) {
      connection.send(_codec.encode(PeekRemoteDropped(_dropped)));
      _dropped = 0;
    }
    while (_queue.isNotEmpty) {
      connection.send(_queue.removeFirst());
    }
  }

  /// Sends [frame] now, ahead of the queue: answers and the hello must not
  /// be the frames that get thrown away.
  void _send(PeekRemoteFrame frame) => _connection?.send(_codec.encode(frame));

  void _setState(PeekRemoteState state) {
    if (_state == state || _states.isClosed) return;
    _state = state;
    _states.add(state);
  }

  static String _newSessionId() {
    final random = math.Random.secure();
    return [
      for (var i = 0; i < 16; i++)
        random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
  }
}
