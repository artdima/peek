import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';
import 'package:peek_remote/peek_remote.dart';

import 'support.dart';

void main() {
  const codec = PeekRemoteCodec();

  group('PeekRemoteCodec', () {
    test('writes every frame and reads it back', () {
      for (final MapEntry(key: name, value: frame) in referenceFrames.entries) {
        expect(codec.decode(codec.encode(frame)), frame, reason: name);
      }
    });

    test('writes a frame as one JSON object with its type first', () {
      final json = jsonDecode(codec.encode(hello)) as Map<String, Object?>;
      expect(json.keys.first, 'type');
      expect(json['type'], 'hello');
      expect(json['protocolVersion'], PeekRemoteProtocol.version);
      expect(json['session'], {
        'peekVersion': '2.0.0',
        'name': 'Peek fixtures',
        'platform': 'ios',
        'osVersion': '18.0',
        'startedAt': '2026-09-10T12:00:00.000Z',
      });
      expect(codec.encode(hello), isNot(contains('\n')));
    });

    test('leaves out what an app or a desktop did not say', () {
      final bare = PeekRemoteHello(
        sessionId: 's',
        session: PeekSessionHeader(platform: 'web', startedAt: frameStart),
      );
      final json = jsonDecode(codec.encode(bare)) as Map<String, Object?>;
      expect(json.containsKey('token'), isFalse);
      expect(json['session'], isNot(contains('name')));
      expect(json['session'], isNot(contains('osVersion')));
      expect(json.containsKey('code'), isFalse);
      expect(jsonDecode(codec.encode(const PeekRemoteWelcome())), {
        'type': 'welcome',
        'protocolVersion': PeekRemoteProtocol.version,
      });
      expect(
        jsonDecode(
          codec.encode(
            const PeekRemoteBodyResponse.error(
              '1',
              PeekRemoteBodyError.notHeld,
            ),
          ),
        ),
        {'type': 'bodyResponse', 'requestId': '1', 'error': 'notHeld'},
      );
    });

    test('carries entries and bodies the way a .peek file does', () {
      final json =
          jsonDecode(codec.encode(PeekRemoteEntry.add(started)))
              as Map<String, Object?>;
      expect(json['entry'], const PeekCodec().encodeEntry(started));
      expect(
        (json['entry']! as Map<String, Object?>)['request'],
        containsPair('body', {
          'kind': 'remote',
          'size': 18,
          'type': 'application/json',
        }),
      );
    });

    test('reads a frame of an unknown type as one to ignore', () {
      expect(
        codec.decode('{"type":"hologram","depth":3}'),
        const PeekRemoteUnknownFrame('hologram'),
      );
    });

    test('ignores unknown keys and reads unknown values as fallbacks', () {
      final text = jsonEncode({
        ...jsonDecode(codec.encode(hello)) as Map<String, Object?>,
        'addedLater': {'nested': true},
      });
      expect(codec.decode(text), hello);
      expect(
        codec.decode('{"type":"denied","reason":"maintenance","message":"x"}'),
        const PeekRemoteDenied(PeekRemoteDeniedReason.other, 'x'),
      );
      expect(
        codec.decode('{"type":"bodyResponse","requestId":"1","error":"gone"}'),
        const PeekRemoteBodyResponse.error('1', PeekRemoteBodyError.failed),
      );
      expect(
        codec.decode('{"type":"welcome","protocolVersion":1,"server":null}'),
        const PeekRemoteWelcome(),
      );
    });

    test('refuses what is not a frame', () {
      for (final text in [
        'not json',
        '[1, 2]',
        '{"kind":"hello"}',
        '{"type":7}',
        '{"type":"synced"}',
        '{"type":"entry","op":"move","id":"e1"}',
        '{"type":"entry","op":"add"}',
        '{"type":"bodyRequest","requestId":"1","id":"e1","side":"both"}',
        '{"type":"hello","protocolVersion":1,"sessionId":"s"}',
      ]) {
        expect(() => codec.decode(text), throwsFormatException, reason: text);
      }
    });
  });

  group('PeekRemoteCodec pairing', () {
    test('carries the code alone, and the device token with the id', () {
      final helloJson =
          jsonDecode(codec.encode(helloWithCode)) as Map<String, Object?>;
      expect(helloJson['code'], '4719');
      expect(helloJson.containsKey('token'), isFalse);
      final welcomeJson =
          jsonDecode(codec.encode(welcomePaired)) as Map<String, Object?>;
      expect(welcomeJson['deviceToken'], welcomePaired.deviceToken);
      expect(welcomeJson['server'], {
        'name': 'Peek Pro',
        'version': '1.0.0',
        'id': '9d4c2b7a1e0f4c8d',
      });
      expect(jsonDecode(codec.encode(const PeekRemoteWelcome(serverId: 'x'))), {
        'type': 'welcome',
        'protocolVersion': PeekRemoteProtocol.version,
        'server': {'id': 'x'},
      });
    });

    test('reads the code reason, and an older desktop reads it as other', () {
      expect(
        (codec.decode('{"type":"denied","reason":"code","message":"no"}')
                as PeekRemoteDenied)
            .reason,
        PeekRemoteDeniedReason.code,
      );
      expect(
        (codec.decode('{"type":"denied","reason":"retina","message":"no"}')
                as PeekRemoteDenied)
            .reason,
        PeekRemoteDeniedReason.other,
      );
    });
  });

  group('PeekRemoteProtocol.check', () {
    test('welcomes an app with the right token and version', () {
      expect(PeekRemoteProtocol.check(hello, token: 'k7Qx2mP9'), isNull);
      expect(PeekRemoteProtocol.check(hello, token: null), isNull);
    });

    test('judges a hello with a code by the code alone', () {
      expect(
        PeekRemoteProtocol.check(
          helloWithCode,
          token: 'k7Qx2mP9',
          code: '4719',
        ),
        isNull,
      );
      expect(
        PeekRemoteProtocol.check(
          helloWithCode,
          token: 'k7Qx2mP9',
          code: '4718',
        )?.reason,
        PeekRemoteDeniedReason.code,
      );
      // A desktop showing no code, or one that accepts anyone, still refuses
      // a code it cannot check: the person typed one for a reason.
      expect(
        PeekRemoteProtocol.check(helloWithCode, token: 'k7Qx2mP9')?.reason,
        PeekRemoteDeniedReason.code,
      );
      expect(
        PeekRemoteProtocol.check(helloWithCode, token: null)?.reason,
        PeekRemoteDeniedReason.code,
      );
    });

    test('accepts a device token it issued', () {
      final withDeviceToken = PeekRemoteHello(
        sessionId: 's',
        token: welcomePaired.deviceToken,
        session: frameSession,
      );
      expect(
        PeekRemoteProtocol.check(
          withDeviceToken,
          token: 'k7Qx2mP9',
          deviceTokens: [welcomePaired.deviceToken!],
        ),
        isNull,
      );
      expect(
        PeekRemoteProtocol.check(
          withDeviceToken,
          token: 'k7Qx2mP9',
          deviceTokens: ['another'],
        )?.reason,
        PeekRemoteDeniedReason.token,
      );
    });

    test('checks the version before the code', () {
      final newer = PeekRemoteHello(
        protocolVersion: 9,
        sessionId: 's',
        code: '4719',
        session: frameSession,
      );
      expect(
        PeekRemoteProtocol.check(newer, token: null, code: '4719')?.reason,
        PeekRemoteDeniedReason.protocolVersion,
      );
    });

    test('turns away a wrong or missing token', () {
      final wrong = PeekRemoteProtocol.check(hello, token: 'k7Qx2mP0');
      expect(wrong?.reason, PeekRemoteDeniedReason.token);
      final missing = PeekRemoteProtocol.check(
        PeekRemoteHello(sessionId: 's', session: frameSession),
        token: 'k7Qx2mP9',
      );
      expect(missing?.reason, PeekRemoteDeniedReason.token);
      expect(
        PeekRemoteProtocol.check(hello, token: 'k7Qx2mP9-longer')?.reason,
        PeekRemoteDeniedReason.token,
      );
    });

    test(
      'turns away another protocol version, saying which side to update',
      () {
        final newer = PeekRemoteHello(
          protocolVersion: PeekRemoteProtocol.version + 1,
          sessionId: 's',
          token: 'k7Qx2mP9',
          session: frameSession,
        );
        final denied = PeekRemoteProtocol.check(newer, token: 'k7Qx2mP9');
        expect(denied?.reason, PeekRemoteDeniedReason.protocolVersion);
        expect(denied?.message, contains('Update the desktop'));

        final older = PeekRemoteHello(
          protocolVersion: 0,
          sessionId: 's',
          session: frameSession,
        );
        expect(
          PeekRemoteProtocol.check(older, token: null)?.message,
          contains('Update Peek in the app'),
        );
        expect(
          PeekRemoteProtocol.check(newer, token: 'k7Qx2mP9', newest: 2),
          isNull,
        );
      },
    );

    test('checks the version before the token', () {
      final newer = PeekRemoteHello(
        protocolVersion: 9,
        sessionId: 's',
        token: 'wrong',
        session: frameSession,
      );
      expect(
        PeekRemoteProtocol.check(newer, token: 'k7Qx2mP9')?.reason,
        PeekRemoteDeniedReason.protocolVersion,
      );
    });
  });

  group('frames', () {
    test('compare by value and print without content', () {
      expect(PeekRemoteEntry.add(started), PeekRemoteEntry.add(started));
      expect(
        PeekRemoteEntry.add(started),
        isNot(PeekRemoteEntry.update(started)),
      );
      expect(PeekRemoteEntry.update(completed).entryId, const PeekId('e1'));
      expect(
        const PeekRemoteEntry.remove(PeekId('e1')).entryId,
        const PeekId('e1'),
      );
      expect(hello.toString(), isNot(contains('k7Qx2mP9')));
      expect(
        const PeekRemoteSynced(1).hashCode,
        isNot(const PeekRemoteDropped(1).hashCode),
      );
    });
  });
}
