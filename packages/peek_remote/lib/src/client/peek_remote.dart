import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:peek/core.dart';

import '../protocol/peek_remote_codec.dart';
import '../protocol/peek_remote_frame.dart';
import '../transport/peek_remote_transport.dart';
import 'peek_remote_endpoint.dart';

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
/// Recording never waits for the network: a change is written to a queue of
/// at most [maxQueued] frames and sent on the next turn of the event loop.
/// When the queue is full the oldest frames go, and the desktop is told how
/// many with a `dropped` frame. A lost connection is tried again after a
/// pause that grows up to [retryMax]; the history is sent again after every
/// welcome. Nothing here throws into the app: errors reach
/// `PeekOptions.onError`.
final class PeekRemote implements PeekAdapter {
  /// Creates the client; nothing is sent until [start].
  ///
  /// [name] is what the desktop calls the app; `PeekOptions.name` when
  /// omitted.
  PeekRemote(
    this.peek, {
    required this.endpoint,
    this.token,
    String? name,
    this.maxQueued = 2000,
    this.inlineBodyBytes = 4096,
    this.retryMin = const Duration(milliseconds: 500),
    this.retryMax = const Duration(seconds: 30),
    PeekRemoteTransport? transport,
    math.Random? random,
  }) : appName = name ?? peek.options.name,
       _transport = transport ?? PeekRemoteTransport.webSocket(),
       _random = random ?? math.Random(),
       _sessionId = _newSessionId(),
       _startedAt = peek.options.clock.now().toUtc();

  /// The instance whose store is sent.
  final Peek peek;

  /// Where the desktop listens.
  final PeekRemoteEndpoint endpoint;

  /// The token the desktop shows; `null` when it asks for none.
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
  final math.Random _random;
  final String _sessionId;
  final DateTime _startedAt;

  static const PeekRemoteCodec _codec = PeekRemoteCodec();

  final ListQueue<String> _queue = ListQueue();
  final StreamController<PeekRemoteState> _states =
      StreamController.broadcast();

  PeekRemoteState _state = PeekRemoteState.stopped;
  PeekRemoteDenied? _denial;
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

  /// Where the client is now.
  PeekRemoteState get state => _state;

  /// Every change of [state].
  Stream<PeekRemoteState> get stateChanges => _states.stream;

  /// Why the desktop turned the app away, while [state] is
  /// [PeekRemoteState.denied].
  PeekRemoteDenied? get denial => _denial;

  /// Identifies this run of the app to the desktop, across reconnections.
  String get sessionId => _sessionId;

  /// Connects, and keeps connecting until [stop]. Safe to call twice.
  void start() {
    if (_running || _disposed) return;
    _running = true;
    _denial = null;
    _attempts = 0;
    unawaited(_connect());
  }

  /// Disconnects and stops trying. Safe to call twice.
  Future<void> stop() async {
    _running = false;
    final connection = _endConnection();
    _setState(PeekRemoteState.stopped);
    await connection?.close();
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
      connection = await _transport.connect(endpoint.uri);
    } on Object {
      // A desktop that is not listening is the usual case, not an error.
      if (generation == _generation && _running) _waitAndRetry();
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
    _send(
      PeekRemoteHello(
        sessionId: _sessionId,
        token: token,
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
          _onWelcome();
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

  void _onWelcome() {
    _welcomed = true;
    _attempts = 0;
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
    if (_running) _waitAndRetry();
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
      response:
          responseBody == null ? null : response!.copyWith(body: responseBody),
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
