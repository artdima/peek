@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';
import 'package:peek_remote/peek_remote.dart';

import 'support.dart';

void main() {
  const codec = PeekRemoteCodec();

  test('streams over a real WebSocket: history, a change, a body', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));

    final synced = Completer<void>();
    final live = Completer<void>();
    final answer = Completer<PeekRemoteBodyResponse>();
    final hellos = <PeekRemoteHello>[];

    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      addTearDown(socket.close);
      socket.listen((message) {
        final frame = codec.decode(message as String);
        switch (frame) {
          case PeekRemoteHello():
            hellos.add(frame);
            socket.add(
              codec.encode(
                PeekRemoteProtocol.check(frame, token: 'k7Qx2mP9') ??
                    const PeekRemoteWelcome(),
              ),
            );
          case PeekRemoteSynced():
            synced.complete();
            socket.add(
              codec.encode(
                const PeekRemoteBodyRequest(
                  requestId: '1',
                  id: PeekId('big'),
                  side: PeekBodySide.request,
                ),
              ),
            );
          case PeekRemoteEntry() when frame.entryId == const PeekId('live'):
            live.complete();
          case PeekRemoteBodyResponse():
            answer.complete(frame);
          default:
            break;
        }
      });
    });

    final peek = Peek();
    addTearDown(peek.dispose);
    final large = PeekBody.text('x' * 5000);
    peek.store.upsert(call('big', body: large));

    final client = PeekRemote(
      peek,
      endpoint: PeekRemoteEndpoint('127.0.0.1', port: server.port),
      token: 'k7Qx2mP9',
    )..start();
    addTearDown(client.dispose);

    await synced.future.timeout(const Duration(seconds: 5));
    expect(client.state, PeekRemoteState.connected);
    peek.store.upsert(call('live'));
    await live.future.timeout(const Duration(seconds: 5));
    final body = await answer.future.timeout(const Duration(seconds: 5));
    expect(body.body, large);
    expect(hellos, hasLength(1));

    await client.stop();
    expect(client.state, PeekRemoteState.stopped);
  });

  test('is turned away by a desktop with another token', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      socket.listen((message) {
        final frame = codec.decode(message as String);
        if (frame is PeekRemoteHello) {
          socket.add(
            codec.encode(PeekRemoteProtocol.check(frame, token: 'other')!),
          );
          unawaited(socket.close());
        }
      });
    });

    final errors = <Object>[];
    final peek = Peek(
      options: PeekOptions(onError: (error, _) => errors.add(error)),
    );
    addTearDown(peek.dispose);
    final client = PeekRemote(
      peek,
      endpoint: PeekRemoteEndpoint('127.0.0.1', port: server.port),
      token: 'k7Qx2mP9',
    )..start();
    addTearDown(client.dispose);

    await client.stateChanges
        .firstWhere((state) => state == PeekRemoteState.denied)
        .timeout(const Duration(seconds: 5));
    expect(client.denial?.reason, PeekRemoteDeniedReason.token);
    expect(errors.single, isA<PeekRemoteDeniedException>());
  });
}
