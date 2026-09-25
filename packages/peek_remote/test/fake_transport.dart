import 'dart:async';

import 'package:peek_remote/peek_remote.dart';

const PeekRemoteCodec _codec = PeekRemoteCodec();

/// Connections in memory, with the desktop's end in the test's hands.
final class FakeTransport implements PeekRemoteTransport {
  /// Every connection opened, oldest first.
  final List<FakeConnection> connections = [];

  /// How many times a connection was asked for, refused ones included.
  int attempts = 0;

  /// Whether the next connections fail, as with no desktop listening.
  bool refuse = false;

  @override
  Future<PeekRemoteConnection> connect(Uri uri) async {
    attempts++;
    if (refuse) throw StateError('nobody listens at $uri');
    final connection = FakeConnection(uri);
    connections.add(connection);
    return connection;
  }

  /// The latest connection.
  FakeConnection get last => connections.last;
}

/// One connection: what the app sent, and a way to answer.
final class FakeConnection implements PeekRemoteConnection {
  FakeConnection(this.uri);

  /// Where the app connected.
  final Uri uri;

  final StreamController<String> _incoming = StreamController();

  /// Every message the app sent, in order.
  final List<String> sent = [];

  /// Whether the app closed it.
  bool closed = false;

  /// What the app sent, read back.
  List<PeekRemoteFrame> get frames => [
    for (final text in sent) _codec.decode(text),
  ];

  @override
  Stream<String> get messages => _incoming.stream;

  @override
  void send(String message) {
    if (!closed) sent.add(message);
  }

  @override
  Future<void> close() async {
    closed = true;
    await _incoming.close();
  }

  /// The desktop sends [frame].
  void reply(PeekRemoteFrame frame) => replyText(_codec.encode(frame));

  /// The desktop sends [text] as it is.
  void replyText(String text) {
    if (!_incoming.isClosed) _incoming.add(text);
  }

  /// The desktop goes away.
  Future<void> hangUp() => _incoming.close();
}

/// Lets timers of zero length, microtasks and stream events run.
Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
