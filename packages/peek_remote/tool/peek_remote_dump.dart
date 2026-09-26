// A stand-in for a desktop viewer, for trying peek_remote without Peek Pro:
// it listens the way Peek Pro does, checks the token, prints every frame and
// writes it to a .jsonl file — one received message per line, which is what
// Peek Pro's tests read back.
//
//   dart run tool/peek_remote_dump.dart --token k7Qx2mP9 --out session.jsonl
//
// Options: --port (9741), --token (none: any app is welcomed), --code (a
// pairing code; a right one is answered with a device token that is good
// until this process ends — the code stays good too, unlike on a desktop),
// --out (no file), --fetch-bodies (ask for every body the app holds back).

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:peek/core.dart';
import 'package:peek_remote/peek_remote.dart';

const PeekRemoteCodec _codec = PeekRemoteCodec();

Future<void> main(List<String> arguments) async {
  final options = _Options.parse(arguments);
  final server = await HttpServer.bind(InternetAddress.anyIPv4, options.port);
  final out =
      options.out == null
          ? null
          : File(options.out!).openWrite(mode: FileMode.append);
  stdout.writeln(
    'Listening on ws://<this machine>:${server.port}/ '
    '— token: ${options.token ?? 'none'}'
    '${options.code == null ? '' : ', code: ${options.code}'}'
    '${out == null ? '' : ', writing to ${options.out}'}',
  );
  var requests = 0;
  final issued = <String>{};
  await for (final request in server) {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.upgradeRequired;
      unawaited(request.response.close());
      continue;
    }
    final socket = await WebSocketTransformer.upgrade(request);
    unawaited(_serve(socket, options, out, issued, () => '${++requests}'));
  }
}

/// A random hex string of [bytes] bytes: device tokens and the server id.
String _random(int bytes) {
  final random = math.Random.secure();
  return [
    for (var i = 0; i < bytes; i++)
      random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}

final String _serverId = _random(8);

Future<void> _serve(
  WebSocket socket,
  _Options options,
  IOSink? out,
  Set<String> issued,
  String Function() nextRequestId,
) async {
  var welcomed = false;
  await for (final message in socket) {
    if (message is! String) continue;
    out?.writeln(message);
    final PeekRemoteFrame frame;
    try {
      frame = _codec.decode(message);
    } on FormatException catch (error) {
      stdout.writeln('unreadable frame: ${error.message}');
      continue;
    }
    stdout.writeln(_describe(frame));

    if (!welcomed) {
      if (frame is! PeekRemoteHello) continue;
      final denial = PeekRemoteProtocol.check(
        frame,
        token: options.token,
        code: options.code,
        deviceTokens: issued,
      );
      if (denial != null) {
        stdout.writeln('denied ${denial.reason.name}: ${denial.message}');
        socket.add(_codec.encode(denial));
        await socket.close();
        return;
      }
      String? deviceToken;
      if (frame.code != null) {
        deviceToken = _random(32);
        issued.add(deviceToken);
        stdout.writeln('paired: issued a device token');
      }
      socket.add(
        _codec.encode(
          PeekRemoteWelcome(
            serverName: 'peek_remote_dump',
            serverId: _serverId,
            deviceToken: deviceToken,
          ),
        ),
      );
      welcomed = true;
      continue;
    }

    if (frame case PeekRemotePing()) {
      socket.add(_codec.encode(const PeekRemotePong()));
    }
    if (options.fetchBodies && frame is PeekRemoteEntry) {
      final entry = frame.entry;
      if (entry == null) continue;
      for (final side in PeekBodySide.values) {
        if (entry.bodyOn(side) is PeekRemoteBody) {
          socket.add(
            _codec.encode(
              PeekRemoteBodyRequest(
                requestId: nextRequestId(),
                id: entry.id,
                side: side,
              ),
            ),
          );
        }
      }
    }
  }
  stdout.writeln('connection closed');
}

String _describe(PeekRemoteFrame frame) => switch (frame) {
  PeekRemoteHello(:final session) =>
    'hello  ${session.name ?? session.platform} '
        '${session.osVersion ?? ''} · Peek ${session.peekVersion} '
        '· ${frame.sessionId}',
  PeekRemoteEntry(:final entry?) =>
    '${frame.op.name.padRight(6)} ${entry.id} ${entry.request.method} '
        '${entry.request.uri} ${entry.statusCode ?? entry.state.name}',
  PeekRemoteEntry() => 'remove ${frame.entryId}',
  PeekRemoteBodyResponse(:final body?) => 'body   #${frame.requestId}: $body',
  PeekRemoteBodyResponse() =>
    'body   #${frame.requestId}: ${frame.error?.name} ${frame.message ?? ''}',
  _ => '$frame',
};

final class _Options {
  const _Options({
    required this.port,
    required this.token,
    required this.code,
    required this.out,
    required this.fetchBodies,
  });

  factory _Options.parse(List<String> arguments) {
    String? valueOf(String name) {
      final index = arguments.indexOf(name);
      return index == -1 || index + 1 >= arguments.length
          ? null
          : arguments[index + 1];
    }

    return _Options(
      port:
          int.tryParse(valueOf('--port') ?? '') ??
          PeekRemoteProtocol.defaultPort,
      token: valueOf('--token'),
      code: valueOf('--code'),
      out: valueOf('--out'),
      fetchBodies: arguments.contains('--fetch-bodies'),
    );
  }

  final int port;
  final String? token;
  final String? code;
  final String? out;
  final bool fetchBodies;
}
