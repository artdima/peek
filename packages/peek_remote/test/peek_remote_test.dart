import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';
import 'package:peek_remote/peek_remote.dart';

import 'fake_transport.dart';
import 'support.dart';

void main() {
  late Peek peek;
  late FakeTransport transport;
  late List<Object> errors;

  PeekRemote remote({
    int maxQueued = 2000,
    Duration retryMin = const Duration(milliseconds: 10),
    Duration retryMax = const Duration(milliseconds: 40),
  }) {
    final client = PeekRemote(
      peek,
      endpoint: const PeekRemoteEndpoint('desk.local'),
      token: 'k7Qx2mP9',
      maxQueued: maxQueued,
      retryMin: retryMin,
      retryMax: retryMax,
      transport: transport,
      random: math.Random(1),
    );
    addTearDown(client.dispose);
    return client;
  }

  /// Starts [client] and has the desktop welcome it.
  Future<FakeConnection> welcomed(PeekRemote client) async {
    client.start();
    await settle();
    transport.last.reply(const PeekRemoteWelcome());
    await settle();
    return transport.last;
  }

  setUp(() {
    errors = [];
    peek = Peek(
      options: PeekOptions(
        name: 'Shop',
        clock: PeekFakeClock(frameStart),
        onError: (error, stackTrace) => errors.add(error),
      ),
    );
    addTearDown(peek.dispose);
    transport = FakeTransport();
  });

  group('connecting', () {
    test('says hello with the token, the session and nothing else', () async {
      final client = remote()..start();
      expect(client.state, PeekRemoteState.connecting);
      await settle();

      final connection = transport.last;
      expect(connection.uri, Uri.parse('ws://desk.local:9741/'));
      final hello = connection.frames.single as PeekRemoteHello;
      expect(hello.token, 'k7Qx2mP9');
      expect(hello.protocolVersion, PeekRemoteProtocol.version);
      expect(hello.sessionId, client.sessionId);
      expect(hello.sessionId, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(hello.session.name, 'Shop');
      expect(hello.session.startedAt, frameStart);
      expect(client.state, PeekRemoteState.connecting);
    });

    test('after the welcome sends the history, then synced', () async {
      peek.store
        ..upsert(call('a'))
        ..upsert(call('b'));
      final client = remote();
      final connection = await welcomed(client);

      expect(client.state, PeekRemoteState.connected);
      expect(connection.frames.skip(1), [
        PeekRemoteEntry.add(call('a')),
        PeekRemoteEntry.add(call('b')),
        const PeekRemoteSynced(2),
      ]);
    });

    test('sends nothing of the store before the welcome', () async {
      final client = remote()..start();
      await settle();
      peek.store.upsert(call('early'));
      await settle();
      expect(transport.last.frames, hasLength(1));
      expect(client.state, PeekRemoteState.connecting);
    });

    test('takes one welcome per connection', () async {
      final connection = await welcomed(remote());
      connection.reply(const PeekRemoteWelcome());
      await settle();
      expect(connection.frames.whereType<PeekRemoteSynced>(), hasLength(1));
      expect(connection.frames.whereType<PeekRemoteHello>(), hasLength(1));
    });
  });

  group('streaming', () {
    test('sends every change as it happens', () async {
      final connection = await welcomed(remote());
      peek.store
        ..upsert(call('a'))
        ..upsert(call('a', response: PeekResponse(statusCode: 200)))
        ..remove(const PeekId('a'))
        ..upsert(call('b'))
        ..clear();
      await settle();

      expect(connection.frames.skip(2), [
        PeekRemoteEntry.add(call('a')),
        PeekRemoteEntry.update(
          call('a', response: PeekResponse(statusCode: 200)),
        ),
        const PeekRemoteEntry.remove(PeekId('a')),
        PeekRemoteEntry.add(call('b')),
        const PeekRemoteCleared(),
      ]);
    });

    test('never sends while the app is recording', () async {
      final connection = await welcomed(remote());
      final before = connection.sent.length;
      for (var i = 0; i < 50; i++) {
        peek.store.upsert(call('c$i'));
      }
      expect(connection.sent.length, before);
      await settle();
      expect(connection.sent.length, before + 50);
    });

    test(
      'throws the oldest frames away when the queue is full, and says so',
      () async {
        final connection = await welcomed(remote(maxQueued: 5));
        final before = connection.sent.length;
        for (var i = 0; i < 20; i++) {
          peek.store.upsert(call('c$i'));
        }
        await settle();

        final frames = connection.frames.skip(before).toList();
        expect(frames.first, const PeekRemoteDropped(15));
        expect(frames.skip(1), [
          for (var i = 15; i < 20; i++) PeekRemoteEntry.add(call('c$i')),
        ]);
      },
    );
  });

  group('bodies', () {
    final large = PeekBody.text('x' * 5000, contentType: PeekMediaType.json);

    test('holds back large bodies and sends small ones', () async {
      peek.store
        ..upsert(call('big', body: large))
        ..upsert(call('small', body: PeekBody.text('{"a":1}')));
      final connection = await welcomed(remote());
      final entries = connection.frames.whereType<PeekRemoteEntry>().toList();

      expect(
        entries.first.entry!.request.body,
        const PeekBody.remote(size: 5000, contentType: PeekMediaType.json),
      );
      expect(entries.last.entry!.request.body, PeekBody.text('{"a":1}'));
      expect(peek.store.find(const PeekId('big'))!.request.body, large);
    });

    test('sends a held-back body when asked, and says why it cannot', () async {
      peek.store
        ..upsert(call('big', body: large))
        ..upsert(
          call(
            'streamed',
            response: PeekResponse(
              statusCode: 200,
              body: const PeekBody.unavailable(
                PeekBodyUnavailableReason.streamed,
              ),
            ),
          ),
        )
        ..upsert(call('pending'));
      final connection = await welcomed(remote());
      final before = connection.sent.length;

      connection
        ..reply(
          const PeekRemoteBodyRequest(
            requestId: '1',
            id: PeekId('big'),
            side: PeekBodySide.request,
          ),
        )
        ..reply(
          const PeekRemoteBodyRequest(
            requestId: '2',
            id: PeekId('streamed'),
            side: PeekBodySide.response,
          ),
        )
        ..reply(
          const PeekRemoteBodyRequest(
            requestId: '3',
            id: PeekId('pending'),
            side: PeekBodySide.response,
          ),
        )
        ..reply(
          const PeekRemoteBodyRequest(
            requestId: '4',
            id: PeekId('nobody'),
            side: PeekBodySide.request,
          ),
        );
      await settle();

      final answers =
          connection.frames
              .skip(before)
              .cast<PeekRemoteBodyResponse>()
              .toList();
      expect(answers[0], PeekRemoteBodyResponse.body('1', large));
      expect(answers[1].error, PeekRemoteBodyError.notHeld);
      expect(answers[2].error, PeekRemoteBodyError.notFound);
      expect(answers[3].error, PeekRemoteBodyError.notFound);
      expect(answers.map((answer) => answer.requestId), ['1', '2', '3', '4']);
    });
  });

  group('the conversation', () {
    test('answers ping and ignores what it cannot use', () async {
      final connection = await welcomed(remote());
      final before = connection.sent.length;
      connection
        ..replyText('not json')
        ..replyText('{"type":"hologram"}')
        ..reply(const PeekRemoteSynced(3))
        ..reply(const PeekRemotePing());
      await settle();

      expect(connection.frames.skip(before), [const PeekRemotePong()]);
      expect(connection.closed, isFalse);
      expect(errors, isEmpty);
    });

    test('stops for good when turned away, and says why', () async {
      final client = remote()..start();
      await settle();
      transport.last.reply(
        const PeekRemoteDenied(PeekRemoteDeniedReason.token, 'wrong token'),
      );
      await settle();

      expect(client.state, PeekRemoteState.denied);
      expect(client.denial?.reason, PeekRemoteDeniedReason.token);
      expect(transport.last.closed, isTrue);
      expect(errors.single, isA<PeekRemoteDeniedException>());
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(transport.attempts, 1);
    });

    test(
      'tries again after a lost connection and resends the history',
      () async {
        peek.store.upsert(call('a'));
        final client = remote();
        final first = await welcomed(client);

        await first.hangUp();
        await settle();
        expect(client.state, PeekRemoteState.waiting);

        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(transport.connections, hasLength(2));
        final second = transport.last;
        expect(
          (second.frames.single as PeekRemoteHello).sessionId,
          client.sessionId,
        );

        second.reply(const PeekRemoteWelcome());
        await settle();
        expect(second.frames.skip(1), [
          PeekRemoteEntry.add(call('a')),
          const PeekRemoteSynced(1),
        ]);
        expect(client.state, PeekRemoteState.connected);
      },
    );

    test(
      'keeps trying while nobody listens, without reporting errors',
      () async {
        transport.refuse = true;
        final client = remote()..start();
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(transport.attempts, greaterThan(2));
        expect(client.state, PeekRemoteState.waiting);
        expect(errors, isEmpty);

        transport.refuse = false;
        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(transport.connections, isNotEmpty);
      },
    );

    test('stop closes the connection and ends the retries', () async {
      final client = remote();
      final connection = await welcomed(client);
      await client.stop();
      peek.store.upsert(call('late'));
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(client.state, PeekRemoteState.stopped);
      expect(connection.closed, isTrue);
      expect(connection.frames.whereType<PeekRemoteEntry>(), isEmpty);
      expect(transport.attempts, 1);

      client
        ..dispose()
        ..dispose()
        ..start();
      await settle();
      expect(transport.attempts, 1);
    });

    test('names itself remote and is disposed with Peek', () async {
      final client = peek.attach(remote());
      expect(client.name, 'remote');
      final connection = await welcomed(client);
      peek.dispose();
      await settle();
      expect(connection.closed, isTrue);
    });
  });

  group('PeekRemoteEndpoint', () {
    test('reads host or host:port', () {
      expect(
        PeekRemoteEndpoint.parse('192.168.1.20'),
        const PeekRemoteEndpoint('192.168.1.20'),
      );
      expect(
        PeekRemoteEndpoint.parse(' desk.local:9000 '),
        const PeekRemoteEndpoint('desk.local', port: 9000),
      );
      expect(
        const PeekRemoteEndpoint('10.0.2.2').uri,
        Uri.parse('ws://10.0.2.2:9741/'),
      );
      expect(const PeekRemoteEndpoint('h', port: 1).toString(), 'h:1');
      expect(
        () => PeekRemoteEndpoint.parse('host:port'),
        throwsFormatException,
      );
      expect(
        () => PeekRemoteEndpoint.parse('host:70000'),
        throwsFormatException,
      );
    });
  });
}
