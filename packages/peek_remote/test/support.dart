import 'package:peek/core.dart';
import 'package:peek_remote/peek_remote.dart';

/// Pinned, so the reference frames do not move with the clock or a release.
final DateTime frameStart = DateTime.utc(2026, 9, 10, 12);

final PeekSessionHeader frameSession = PeekSessionHeader(
  name: 'Peek fixtures',
  platform: 'ios',
  osVersion: '18.0',
  startedAt: frameStart,
  peekVersion: '2.0.0',
);

final PeekRemoteHello hello = PeekRemoteHello(
  sessionId: '3f2a9c1e0b7d4e56a8c1f0e2d3b4a596',
  token: 'k7Qx2mP9',
  session: frameSession,
);

/// A call as the app first sends it: still running, its body left behind.
final PeekEntry started = PeekEntry(
  id: const PeekId('e1'),
  request: PeekRequest(
    method: 'POST',
    uri: Uri.parse('https://api.example.com/orders'),
    headers: PeekHeaders.fromMap({'Content-Type': 'application/json'}),
    body: const PeekBody.remote(size: 18, contentType: PeekMediaType.json),
  ),
  startedAt: frameStart,
  source: 'dio',
);

/// The same call once it completed.
final PeekEntry completed = started.complete(
  PeekResponse(
    statusCode: 201,
    statusMessage: 'Created',
    headers: PeekHeaders.fromMap({'Content-Type': 'application/json'}),
    body: const PeekBody.remote(size: 48213, contentType: PeekMediaType.json),
  ),
  at: frameStart.add(const Duration(milliseconds: 320)),
);

/// Every frame the protocol has, by the name of its reference file.
final Map<String, PeekRemoteFrame> referenceFrames = {
  'hello': hello,
  'welcome': const PeekRemoteWelcome(
    serverName: 'Peek Pro',
    serverVersion: '1.0.0',
  ),
  'denied': const PeekRemoteDenied(
    PeekRemoteDeniedReason.token,
    'The token does not match the one the desktop shows.',
  ),
  'entry-add': PeekRemoteEntry.add(started),
  'entry-update': PeekRemoteEntry.update(completed),
  'entry-remove': const PeekRemoteEntry.remove(PeekId('e1')),
  'cleared': const PeekRemoteCleared(),
  'synced': const PeekRemoteSynced(42),
  'dropped': const PeekRemoteDropped(37),
  'body-request': const PeekRemoteBodyRequest(
    requestId: '7',
    id: PeekId('e1'),
    side: PeekBodySide.response,
  ),
  'body-response': PeekRemoteBodyResponse.body(
    '7',
    PeekBody.text('{"id":9,"status":"new"}', contentType: PeekMediaType.json),
  ),
  'body-error': const PeekRemoteBodyResponse.error(
    '8',
    PeekRemoteBodyError.notFound,
    'No call e404 on this device.',
  ),
  'ping': const PeekRemotePing(),
  'pong': const PeekRemotePong(),
};

/// A call named [id], with [body] sent and, when given, [response] back.
PeekEntry call(
  String id, {
  PeekBody body = const PeekBody.empty(),
  PeekResponse? response,
}) {
  final entry = PeekEntry(
    id: PeekId(id),
    request: PeekRequest(
      method: 'POST',
      uri: Uri.parse('https://api.example.com/$id'),
      body: body,
    ),
    startedAt: frameStart,
    source: 'dio',
  );
  return response == null ? entry : entry.complete(response, at: frameStart);
}
