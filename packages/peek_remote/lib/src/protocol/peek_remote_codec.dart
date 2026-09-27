import 'dart:convert';

import 'package:peek/core.dart';

import 'peek_remote_frame.dart';

/// Writes frames as the JSON text of one WebSocket message, and reads them.
///
/// Reading is lenient the way `.peek` files are: unknown keys are ignored,
/// an unknown enum value reads as its fallback, `null` counts as absent, and
/// a frame of an unknown type reads as [PeekRemoteUnknownFrame] rather than
/// failing. Text that is not a frame at all throws a [FormatException].
final class PeekRemoteCodec {
  /// Creates a codec.
  const PeekRemoteCodec();

  static const PeekCodec _codec = PeekCodec();

  /// [frame] as the text of one message.
  String encode(PeekRemoteFrame frame) => jsonEncode(encodeFrame(frame));

  /// The frame [text] holds.
  PeekRemoteFrame decode(String text) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException catch (error) {
      throw FormatException('a frame must be JSON: ${error.message}');
    }
    return decodeFrame(json);
  }

  /// [frame] as a JSON-ready map.
  Map<String, Object?> encodeFrame(PeekRemoteFrame frame) => switch (frame) {
    PeekRemoteHello() => {
      'type': 'hello',
      'protocolVersion': frame.protocolVersion,
      'token': ?frame.token,
      'code': ?frame.code,
      'sessionId': frame.sessionId,
      'session': _encodeSession(frame.session),
    },
    PeekRemoteWelcome() => {
      'type': 'welcome',
      'protocolVersion': frame.protocolVersion,
      if (frame.serverName != null ||
          frame.serverVersion != null ||
          frame.serverId != null)
        'server': {
          'name': ?frame.serverName,
          'version': ?frame.serverVersion,
          'id': ?frame.serverId,
        },
      'deviceToken': ?frame.deviceToken,
    },
    PeekRemoteDenied() => {
      'type': 'denied',
      'reason': frame.reason.name,
      'message': frame.message,
    },
    PeekRemoteEntry(:final entry?) => {
      'type': 'entry',
      'op': frame.op.name,
      'entry': _codec.encodeEntry(entry),
    },
    PeekRemoteEntry() => {
      'type': 'entry',
      'op': frame.op.name,
      'id': frame.entryId.value,
    },
    PeekRemoteCleared() => {'type': 'cleared'},
    PeekRemoteSynced() => {'type': 'synced', 'count': frame.count},
    PeekRemoteDropped() => {'type': 'dropped', 'count': frame.count},
    PeekRemoteBodyRequest() => {
      'type': 'bodyRequest',
      'requestId': frame.requestId,
      'id': frame.id.value,
      'side': frame.side.name,
    },
    PeekRemoteBodyResponse(:final body?) => {
      'type': 'bodyResponse',
      'requestId': frame.requestId,
      'body': _codec.encodeBody(body),
    },
    PeekRemoteBodyResponse() => {
      'type': 'bodyResponse',
      'requestId': frame.requestId,
      'error': (frame.error ?? PeekRemoteBodyError.failed).name,
      'message': ?frame.message,
    },
    PeekRemotePing() => {'type': 'ping'},
    PeekRemotePong() => {'type': 'pong'},
    PeekRemoteUnknownFrame() => {'type': frame.type},
  };

  /// Reads a frame written by [encodeFrame].
  PeekRemoteFrame decodeFrame(Object? json) {
    if (json is! Map<String, Object?>) {
      throw const FormatException('a frame must be a JSON object');
    }
    final type = _string(json, 'type');
    return switch (type) {
      'hello' => PeekRemoteHello(
        protocolVersion: _int(json, 'protocolVersion'),
        token: _optionalString(json, 'token'),
        code: _optionalString(json, 'code'),
        sessionId: _string(json, 'sessionId'),
        session: _decodeSession(json['session']),
      ),
      'welcome' => PeekRemoteWelcome(
        protocolVersion: _int(json, 'protocolVersion'),
        serverName: _optionalString(_optionalObject(json, 'server'), 'name'),
        serverVersion: _optionalString(
          _optionalObject(json, 'server'),
          'version',
        ),
        serverId: _optionalString(_optionalObject(json, 'server'), 'id'),
        deviceToken: _optionalString(json, 'deviceToken'),
      ),
      'denied' => PeekRemoteDenied(
        PeekRemoteDeniedReason.values.asNameMap()[json['reason']] ??
            PeekRemoteDeniedReason.other,
        _optionalString(json, 'message') ?? '',
      ),
      'entry' => switch (_string(json, 'op')) {
        'add' => PeekRemoteEntry.add(_codec.decodeEntry(json['entry'])),
        'update' => PeekRemoteEntry.update(_codec.decodeEntry(json['entry'])),
        'remove' => PeekRemoteEntry.remove(PeekId(_string(json, 'id'))),
        final op => throw FormatException('"$op" is not an entry operation'),
      },
      'cleared' => const PeekRemoteCleared(),
      'synced' => PeekRemoteSynced(_int(json, 'count')),
      'dropped' => PeekRemoteDropped(_int(json, 'count')),
      'bodyRequest' => PeekRemoteBodyRequest(
        requestId: _string(json, 'requestId'),
        id: PeekId(_string(json, 'id')),
        side: switch (_string(json, 'side')) {
          'request' => PeekBodySide.request,
          'response' => PeekBodySide.response,
          final side => throw FormatException('"$side" is not a body side'),
        },
      ),
      'bodyResponse' =>
        json['body'] == null
            ? PeekRemoteBodyResponse.error(
                _string(json, 'requestId'),
                PeekRemoteBodyError.values.asNameMap()[json['error']] ??
                    PeekRemoteBodyError.failed,
                _optionalString(json, 'message'),
              )
            : PeekRemoteBodyResponse.body(
                _string(json, 'requestId'),
                _codec.decodeBody(json['body']),
              ),
      'ping' => const PeekRemotePing(),
      'pong' => const PeekRemotePong(),
      _ => PeekRemoteUnknownFrame(type),
    };
  }

  static Map<String, Object?> _encodeSession(PeekSessionHeader session) => {
    'peekVersion': session.peekVersion,
    'name': ?session.name,
    'platform': session.platform,
    'osVersion': ?session.osVersion,
    'startedAt': session.startedAt.toUtc().toIso8601String(),
  };

  static PeekSessionHeader _decodeSession(Object? json) {
    if (json is! Map<String, Object?>) {
      throw const FormatException('"session" must be an object');
    }
    final startedAt = DateTime.tryParse(_string(json, 'startedAt'));
    if (startedAt == null) {
      throw const FormatException('"startedAt" is not an ISO 8601 time');
    }
    return PeekSessionHeader(
      peekVersion: _string(json, 'peekVersion'),
      name: _optionalString(json, 'name'),
      platform: _string(json, 'platform'),
      osVersion: _optionalString(json, 'osVersion'),
      startedAt: startedAt.toUtc(),
    );
  }

  static String _string(Map<String, Object?> json, String key) =>
      switch (json[key]) {
        final String value => value,
        _ => throw FormatException('"$key" must be a string'),
      };

  static String? _optionalString(Map<String, Object?>? json, String key) =>
      switch (json?[key]) {
        null => null,
        final String value => value,
        _ => throw FormatException('"$key" must be a string'),
      };

  static int _int(Map<String, Object?> json, String key) => switch (json[key]) {
    final int value => value,
    _ => throw FormatException('"$key" must be an integer'),
  };

  static Map<String, Object?>? _optionalObject(
    Map<String, Object?> json,
    String key,
  ) => switch (json[key]) {
    null => null,
    final Map<String, Object?> value => value,
    _ => throw FormatException('"$key" must be an object'),
  };
}
