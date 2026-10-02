@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';
import 'package:peek_remote/peek_remote.dart';
import 'package:peek_remote/src/io/web_socket_transport.dart';

import 'support.dart';

void main() {
  const codec = PeekRemoteCodec();

  Matcher failsWith(PeekDesktopFailure failure) => throwsA(
    isA<PeekRemoteConnectException>().having(
      (error) => error.failure,
      'failure',
      failure,
    ),
  );

  group('a connection that fails', () {
    test('says a port nobody listens on refused it', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      await server.close();
      await expectLater(
        PeekRemoteTransport.webSocket().connect(
          Uri.parse('ws://127.0.0.1:$port/'),
        ),
        failsWith(PeekDesktopFailure.refused),
      );
    });

    test('says a desktop that never answers timed out', () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final accepted = <Socket>[];
      server.listen(accepted.add);
      addTearDown(() async {
        for (final socket in accepted) {
          socket.destroy();
        }
        await server.close();
      });
      await expectLater(
        PeekRemoteTransport.webSocket(
          timeout: const Duration(milliseconds: 200),
        ).connect(Uri.parse('ws://127.0.0.1:${server.port}/')),
        failsWith(PeekDesktopFailure.timedOut),
      );
    });

    test('says a name that resolves to nothing was not found', () async {
      await expectLater(
        PeekRemoteTransport.webSocket().connect(
          Uri.parse('ws://peek-remote.invalid/'),
        ),
        failsWith(PeekDesktopFailure.notFound),
      );
    });

    test('reads what each system calls it', () {
      SocketException error(String message, String os, int code) =>
          SocketException(message, osError: OSError(os, code));

      expect(
        peekRemoteFailureOf(
          error('Connection refused', 'Connection refused', 61),
        ),
        PeekDesktopFailure.refused,
      );
      expect(
        peekRemoteFailureOf(error('Connection failed', '', 111)),
        PeekDesktopFailure.refused,
      );
      expect(
        peekRemoteFailureOf(
          error('Connection timed out', 'Operation timed out', 60),
        ),
        PeekDesktopFailure.timedOut,
      );
      expect(
        peekRemoteFailureOf(error('Connection failed', 'No route to host', 65)),
        PeekDesktopFailure.timedOut,
      );
      expect(
        peekRemoteFailureOf(
          error(
            "Failed host lookup: 'desk.local'",
            'nodename nor servname provided, or not known',
            8,
          ),
        ),
        PeekDesktopFailure.notFound,
      );
      expect(
        peekRemoteFailureOf(error('Broken pipe', 'Broken pipe', 32)),
        PeekDesktopFailure.other,
      );
    });
  });

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
