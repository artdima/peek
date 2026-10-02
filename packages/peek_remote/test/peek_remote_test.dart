import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';
import 'package:peek_remote/peek_remote.dart';

import 'fake_discovery.dart';
import 'fake_transport.dart';
import 'support.dart';

void main() {
  late Peek peek;
  late FakeTransport transport;
  late List<Object> errors;

  late PeekRemoteMemory memory;
  late FakeDiscovery discovery;

  PeekRemote remote({
    int maxQueued = 2000,
    Duration retryMin = const Duration(milliseconds: 10),
    Duration retryMax = const Duration(milliseconds: 40),
    PeekRemoteEndpoint? endpoint = const PeekRemoteEndpoint('desk.local'),
    String? token = 'k7Qx2mP9',
  }) {
    final client = PeekRemote(
      peek,
      endpoint: endpoint,
      token: token,
      memory: memory,
      discovery: discovery,
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
    memory = PeekRemoteMemory.inMemory();
    discovery = FakeDiscovery();
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

      final answers = connection.frames
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

  group('pairing', () {
    const desk = PeekRemoteEndpoint('desk.local');
    const issued = 'c1f6a2e9d4b8074f3e5a19c2b7d0e6f4';

    test('sends the code alone, then the device token it got', () async {
      final client = remote();
      await client.connect(desk, code: ' 4719 ');
      await settle();
      final first = transport.last.frames.single as PeekRemoteHello;
      expect(first.code, '4719');
      expect(first.token, isNull);
      expect(client.deviceToken, isNull);

      transport.last.reply(
        const PeekRemoteWelcome(serverId: 'mac-1', deviceToken: issued),
      );
      await settle();
      expect(client.state, PeekRemoteState.connected);
      expect(client.deviceToken, issued);
      expect(client.serverId, 'mac-1');

      await transport.last.hangUp();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final again = transport.last.frames.single as PeekRemoteHello;
      expect(again.token, issued);
      expect(again.code, isNull);
      expect(again.sessionId, client.sessionId);
    });

    test('keeps the code until a desktop answers it with a token', () async {
      final client = remote();
      await client.connect(desk, code: '4719');
      await settle();
      transport.last.reply(const PeekRemoteWelcome());
      await settle();
      expect(client.state, PeekRemoteState.connected);
      expect(client.deviceToken, isNull);

      await transport.last.hangUp();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect((transport.last.frames.single as PeekRemoteHello).code, '4719');
    });

    test('stops on a wrong code, and says so', () async {
      final client = remote();
      await client.connect(desk, code: '0000');
      await settle();
      transport.last.reply(
        const PeekRemoteDenied(PeekRemoteDeniedReason.code, 'wrong code'),
      );
      await settle();
      expect(client.state, PeekRemoteState.denied);
      expect(client.denial?.reason, PeekRemoteDeniedReason.code);
      expect(errors.single, isA<PeekRemoteDeniedException>());
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(transport.attempts, 1);

      // A fresh code starts over, without the burnt one.
      await client.connect(desk, code: '4719');
      await settle();
      expect((transport.last.frames.single as PeekRemoteHello).code, '4719');
      expect(client.denial, isNull);
    });

    test('drops a device token the desktop no longer knows', () async {
      final client = remote();
      await client.connect(desk, code: '4719');
      await settle();
      transport.last.reply(const PeekRemoteWelcome(deviceToken: issued));
      await settle();
      await transport.last.hangUp();
      await Future<void>.delayed(const Duration(milliseconds: 60));

      transport.last.reply(
        const PeekRemoteDenied(PeekRemoteDeniedReason.token, 'who?'),
      );
      await settle();
      expect(client.state, PeekRemoteState.denied);
      expect(client.deviceToken, isNull);
      expect(client.serverId, isNull);
    });

    test('pairs anew where told, leaving the old desktop', () async {
      final client = remote();
      final old = await welcomed(client);
      await client.connect(
        const PeekRemoteEndpoint('other.local', port: 9800),
        code: '2222',
      );
      await settle();
      expect(old.closed, isTrue);
      expect(
        client.endpoint,
        const PeekRemoteEndpoint('other.local', port: 9800),
      );
      expect(transport.last.uri, Uri.parse('ws://other.local:9800/'));
      expect((transport.last.frames.single as PeekRemoteHello).code, '2222');
    });

    test('refuses an empty code', () async {
      final client = remote();
      await expectLater(client.connect(desk, code: '  '), throwsArgumentError);
      expect(client.state, PeekRemoteState.stopped);
    });

    test('connects again to a known desktop with the token it holds', () async {
      final client = remote();
      await client.connect(desk, code: '4719', name: 'Studio Mac');
      await settle();
      transport.last.reply(
        const PeekRemoteWelcome(serverId: 'mac-1', deviceToken: issued),
      );
      await settle();

      await client.connect(const PeekRemoteEndpoint('10.0.0.9'));
      await settle();
      final hello = transport.last.frames.single as PeekRemoteHello;
      expect(hello.token, issued);
      expect(hello.code, isNull);
      expect(client.desktop?.name, 'Studio Mac');
    });
  });

  group('memory', () {
    const desk = PeekRemoteEndpoint('desk.local');
    const issued = 'c1f6a2e9d4b8074f3e5a19c2b7d0e6f4';

    /// Pairs [client] with the desktop at [desk], named [name].
    Future<void> paired(PeekRemote client, {String? name}) async {
      await client.connect(desk, code: '4719', name: name);
      await settle();
      transport.last.reply(
        const PeekRemoteWelcome(serverId: 'mac-1', deviceToken: issued),
      );
      await settle();
    }

    test('remembers the desktop and its token once paired', () async {
      final client = remote(endpoint: null, token: null);
      await paired(client, name: 'Studio Mac');
      expect(
        await memory.lastDesktop(),
        const PeekRemoteDesktop(
          serverId: 'mac-1',
          endpoint: desk,
          name: 'Studio Mac',
        ),
      );
      expect(await memory.token('mac-1'), issued);
      expect(client.desktop?.name, 'Studio Mac');
    });

    test('finds its way back on the next run, without a code', () async {
      await paired(remote(endpoint: null, token: null));

      final next = remote(endpoint: null, token: null)..start();
      expect(next.state, PeekRemoteState.connecting);
      await settle();
      expect(transport.last.uri, desk.uri);
      final hello = transport.last.frames.single as PeekRemoteHello;
      expect(hello.token, issued);
      expect(hello.code, isNull);
      expect(next.endpoint, desk);
      expect(next.deviceToken, issued);
      expect(next.serverId, 'mac-1');
    });

    test('is unpaired with nothing remembered', () async {
      final client = remote(endpoint: null, token: null)..start();
      await settle();
      expect(client.state, PeekRemoteState.unpaired);
      expect(transport.attempts, 0);
      expect(errors, isEmpty);
    });

    test('sends the token of the last desktop, not another one', () async {
      await memory.remember(
        const PeekRemoteDesktop(
          serverId: 'mac-0',
          endpoint: PeekRemoteEndpoint('old.local'),
        ),
        token: 'old-token',
      );
      await paired(remote(endpoint: null, token: null));

      remote(endpoint: null, token: null).start();
      await settle();
      expect((transport.last.frames.single as PeekRemoteHello).token, issued);
      expect(await memory.token('mac-0'), 'old-token');
    });

    test('keeps a new address of a remembered desktop', () async {
      await paired(remote(endpoint: null, token: null), name: 'Studio Mac');
      final next = remote(endpoint: null, token: null);
      await next.connect(const PeekRemoteEndpoint('10.0.0.9'));
      await settle();
      transport.last.reply(const PeekRemoteWelcome(serverId: 'mac-1'));
      await settle();
      expect(
        await memory.lastDesktop(),
        const PeekRemoteDesktop(
          serverId: 'mac-1',
          endpoint: PeekRemoteEndpoint('10.0.0.9'),
          name: 'Studio Mac',
        ),
      );
      expect(await memory.token('mac-1'), issued);
    });

    test('forget drops the desktop here and in memory', () async {
      final client = remote(endpoint: null, token: null);
      await paired(client);
      await client.forget();
      expect(client.state, PeekRemoteState.unpaired);
      expect(client.deviceToken, isNull);
      expect(client.desktop, isNull);
      expect(transport.last.closed, isTrue);
      expect(await memory.lastDesktop(), isNull);
      expect(await memory.token('mac-1'), isNull);

      client.start();
      await settle();
      expect(client.state, PeekRemoteState.unpaired);
    });

    test('forgets a desktop that no longer knows the device', () async {
      await paired(remote(endpoint: null, token: null));
      final next = remote(endpoint: null, token: null)..start();
      await settle();
      transport.last.reply(
        const PeekRemoteDenied(PeekRemoteDeniedReason.token, 'who?'),
      );
      await settle();
      expect(next.state, PeekRemoteState.denied);
      expect(await memory.lastDesktop(), isNull);
      expect(await memory.token('mac-1'), isNull);
    });

    test('leaves memory alone with a token written in code', () async {
      final client = remote();
      await welcomed(client);
      expect(await memory.lastDesktop(), isNull);
    });

    test('a memory that fails is reported, not fatal', () async {
      final client = PeekRemote(
        peek,
        memory: _BrokenMemory(),
        transport: transport,
      );
      addTearDown(client.dispose);
      client.start();
      await settle();
      expect(client.state, PeekRemoteState.unpaired);
      expect(errors.single, isA<StateError>());
    });
  });

  group('as a desktop link', () {
    test('shows the screen where it stands and who the desktop is', () async {
      final client = remote(endpoint: null, token: null);
      expect(client.linkState.status, PeekDesktopLinkStatus.stopped);
      expect(client.linkState.desktopName, isNull);

      final seen = <PeekDesktopLinkState>[];
      client.linkChanges.listen(seen.add);
      await client.connectDesktop(
        'desk.local',
        9741,
        code: '4719',
        name: 'Studio Mac',
      );
      await settle();
      expect(client.linkState.status, PeekDesktopLinkStatus.connecting);
      expect(client.linkState.desktopName, 'Studio Mac');
      expect(client.linkState.host, 'desk.local');
      expect(client.linkState.port, 9741);
      expect(transport.last.uri, Uri.parse('ws://desk.local:9741/'));
      expect((transport.last.frames.single as PeekRemoteHello).code, '4719');

      transport.last.reply(
        const PeekRemoteWelcome(serverId: 'mac-1', deviceToken: 'issued'),
      );
      await settle();
      expect(client.linkState.status, PeekDesktopLinkStatus.connected);
      expect(seen.map((state) => state.status), [
        PeekDesktopLinkStatus.connecting,
        PeekDesktopLinkStatus.connected,
      ]);

      await client.disconnectDesktop();
      expect(client.linkState.status, PeekDesktopLinkStatus.stopped);
      expect(client.linkState.desktopName, 'Studio Mac');

      await client.forgetDesktop();
      expect(client.linkState.status, PeekDesktopLinkStatus.unpaired);
      expect(client.linkState.desktopName, isNull);
      expect(client.linkState.host, isNull);
    });

    test('names an address when that is all it knows', () async {
      final client = remote();
      expect(client.linkState.desktopName, 'desk.local:9741');
      client.start();
      await settle();
      transport.last.reply(
        const PeekRemoteDenied(PeekRemoteDeniedReason.token, 'wrong token'),
      );
      await settle();
      expect(client.linkState.status, PeekDesktopLinkStatus.denied);
      expect(client.linkState.message, 'wrong token');
      expect(client.linkState.denial, PeekDesktopDenial.token);
    });

    test('says why the desktop cannot be reached', () async {
      final client = remote(endpoint: null, token: null);
      transport.failWith = const PeekRemoteConnectException(
        PeekDesktopFailure.timedOut,
      );
      await client.connectDesktop('desk.local', 9741, code: '4719');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(client.linkState.status, PeekDesktopLinkStatus.waiting);
      expect(client.linkState.failure, PeekDesktopFailure.timedOut);

      transport.failWith = Exception('something else');
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(client.linkState.failure, PeekDesktopFailure.other);

      transport.failWith = null;
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(client.linkState.status, PeekDesktopLinkStatus.connecting);
      expect(client.linkState.failure, isNull);
      transport.last.reply(
        const PeekRemoteWelcome(serverId: 'mac-1', deviceToken: 'issued'),
      );
      await settle();
      expect(client.linkState.status, PeekDesktopLinkStatus.connected);

      final seen = <PeekDesktopLinkState>[];
      client.linkChanges.listen(seen.add);
      await transport.last.hangUp();
      await settle();
      expect(
        seen.first,
        isA<PeekDesktopLinkState>()
            .having(
              (state) => state.status,
              'status',
              PeekDesktopLinkStatus.waiting,
            )
            .having(
              (state) => state.failure,
              'failure',
              PeekDesktopFailure.dropped,
            ),
      );

      await client.stop();
      expect(client.linkState.failure, isNull);
    });

    test(
      'is paired once the desktop lets it in, and until it forgets',
      () async {
        final client = remote(endpoint: null, token: null);
        await client.connectDesktop('desk.local', 9741, code: '4719');
        await settle();
        expect(client.linkState.isPaired, isFalse);

        transport.last.reply(
          const PeekRemoteWelcome(serverId: 'mac-1', deviceToken: 'issued'),
        );
        await settle();
        expect(client.linkState.isPaired, isTrue);

        await client.disconnectDesktop();
        expect(client.linkState.isPaired, isTrue);

        final again = remote(endpoint: null, token: null)..start();
        await settle();
        expect(again.linkState.isPaired, isTrue);

        await client.connectDesktop('other.local', 9741, code: '1111');
        expect(client.linkState.isPaired, isFalse);
        await client.forgetDesktop();
        expect(client.linkState.isPaired, isFalse);
      },
    );

    test('says what kind of refusal it was', () async {
      final client = remote(endpoint: null, token: null);
      for (final (reason, denial) in [
        (PeekRemoteDeniedReason.code, PeekDesktopDenial.code),
        (
          PeekRemoteDeniedReason.protocolVersion,
          PeekDesktopDenial.protocolVersion,
        ),
        (PeekRemoteDeniedReason.other, PeekDesktopDenial.other),
      ]) {
        await client.connectDesktop('desk.local', 9741, code: '4719');
        await settle();
        transport.last.reply(PeekRemoteDenied(reason, 'no'));
        await settle();
        expect(client.linkState.status, PeekDesktopLinkStatus.denied);
        expect(client.linkState.denial, denial);
      }
      await client.connectDesktop('desk.local', 9741, code: '4719');
      expect(client.linkState.denial, isNull);
    });
  });

  group('discovery', () {
    const issued = 'c1f6a2e9d4b8074f3e5a19c2b7d0e6f4';
    const studio = PeekRemoteDiscovered(
      name: 'Studio Mac',
      endpoint: PeekRemoteEndpoint('10.0.0.2'),
      protocolVersion: 1,
      serverId: 'mac-1',
    );
    const other = PeekRemoteDiscovered(
      name: 'Air',
      endpoint: PeekRemoteEndpoint('10.0.0.3'),
      serverId: 'mac-2',
    );

    Future<PeekRemote> pairedWithStudio() async {
      final client = remote(endpoint: null, token: null);
      await client.connectDesktop(
        '10.0.0.2',
        9741,
        code: '4719',
        name: 'Studio Mac',
      );
      await settle();
      transport.last.reply(
        const PeekRemoteWelcome(serverId: 'mac-1', deviceToken: issued),
      );
      await settle();
      return client;
    }

    test('lists what the network has, marking the paired desktop', () async {
      final client = await pairedWithStudio();
      final seen = <List<PeekDesktopFound>>[];
      final subscription = client.watchDesktops().listen(seen.add);
      await settle();
      expect(discovery.listeners, 1);

      discovery.show([other, studio]);
      await settle();
      expect(seen.single, [
        const PeekDesktopFound(
          name: 'Air',
          host: '10.0.0.3',
          port: 9741,
          serverId: 'mac-2',
        ),
        const PeekDesktopFound(
          name: 'Studio Mac',
          host: '10.0.0.2',
          port: 9741,
          serverId: 'mac-1',
          isPaired: true,
        ),
      ]);

      await subscription.cancel();
      expect(discovery.listeners, 0);
    });

    test('sends its token to the desktop that issued it', () async {
      final client = await pairedWithStudio();
      await client.stop();
      await client.connectDesktop('10.0.0.7', 9741, serverId: 'mac-1');
      await settle();
      expect((transport.last.frames.single as PeekRemoteHello).token, issued);
    });

    test('never sends a token to another desktop', () async {
      final client = await pairedWithStudio();
      await client.connectDesktop('10.0.0.3', 9741, serverId: 'mac-2');
      await settle();
      final hello = transport.last.frames.single as PeekRemoteHello;
      expect(hello.token, isNull);
      expect(hello.code, isNull);

      transport.last.reply(
        const PeekRemoteDenied(PeekRemoteDeniedReason.token, 'who?'),
      );
      await settle();
      expect(client.state, PeekRemoteState.denied);
      expect(await memory.token('mac-1'), issued);
    });

    test('finds the token of a desktop paired before the last one', () async {
      await memory.remember(
        const PeekRemoteDesktop(
          serverId: 'mac-0',
          endpoint: PeekRemoteEndpoint('old.local'),
          name: 'Old Mac',
        ),
        token: 'old-token',
      );
      await pairedWithStudio();

      final next = remote(endpoint: null, token: null);
      await next.connectDesktop('10.0.0.8', 9741, serverId: 'mac-0');
      await settle();
      expect(
        (transport.last.frames.single as PeekRemoteHello).token,
        'old-token',
      );
      expect(next.serverId, 'mac-0');
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

/// A store that is out of order: memory is best effort.
final class _BrokenMemory implements PeekRemoteMemory {
  @override
  Future<PeekRemoteDesktop?> lastDesktop() async =>
      throw StateError('no preferences here');

  @override
  Future<String?> token(String serverId) async =>
      throw StateError('no preferences here');

  @override
  Future<void> remember(PeekRemoteDesktop desktop, {String? token}) async =>
      throw StateError('no preferences here');

  @override
  Future<void> forget(String serverId) async =>
      throw StateError('no preferences here');

  @override
  Future<void> forgetAll() async => throw StateError('no preferences here');
}
