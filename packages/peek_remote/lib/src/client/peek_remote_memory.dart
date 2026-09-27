import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'peek_remote_endpoint.dart';

/// A desktop the app has paired with: enough to find it again and to say
/// whose token it holds.
@immutable
final class PeekRemoteDesktop {
  /// Creates the record.
  const PeekRemoteDesktop({
    required this.serverId,
    required this.endpoint,
    this.name,
  });

  /// The desktop's `server.id`, the same across its launches.
  final String serverId;

  /// Where it was last reached.
  final PeekRemoteEndpoint endpoint;

  /// What a person called it — the Mac's name from the network, or nothing
  /// when the address was typed.
  final String? name;

  /// The same desktop at another address.
  PeekRemoteDesktop at(PeekRemoteEndpoint endpoint) =>
      PeekRemoteDesktop(serverId: serverId, endpoint: endpoint, name: name);

  Map<String, Object?> _toJson() => {
    'serverId': serverId,
    'host': endpoint.host,
    'port': endpoint.port,
    if (name case final name?) 'name': name,
  };

  static PeekRemoteDesktop? _fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    if (json case {
      'serverId': final String serverId,
      'host': final String host,
      'port': final int port,
    }) {
      final name = json['name'];
      return PeekRemoteDesktop(
        serverId: serverId,
        endpoint: PeekRemoteEndpoint(host, port: port),
        name: name is String ? name : null,
      );
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is PeekRemoteDesktop &&
      other.serverId == serverId &&
      other.endpoint == endpoint &&
      other.name == name;

  @override
  int get hashCode => Object.hash(serverId, endpoint, name);

  @override
  String toString() => 'PeekRemoteDesktop(${name ?? endpoint}, $serverId)';
}

/// What the client keeps between runs of the app: the desktop it paired
/// with last, and a device token for every desktop it has paired with.
///
/// [PeekRemoteMemory.sharedPreferences] is the default; tests use
/// [PeekRemoteMemory.inMemory].
abstract interface class PeekRemoteMemory {
  /// Kept in `shared_preferences`, under keys starting with `peek_remote.`.
  factory PeekRemoteMemory.sharedPreferences() = _SharedPreferencesMemory;

  /// Kept only while the object lives.
  factory PeekRemoteMemory.inMemory() = _InMemoryMemory;

  /// The desktop paired with last, if any.
  Future<PeekRemoteDesktop?> lastDesktop();

  /// The token the desktop [serverId] issued, if it has.
  Future<String?> token(String serverId);

  /// [desktop] becomes the last one; with [token], the one it issued.
  Future<void> remember(PeekRemoteDesktop desktop, {String? token});

  /// Drops the desktop's token, and the desktop itself if it was the last.
  Future<void> forget(String serverId);

  /// Drops everything.
  Future<void> forgetAll();
}

final class _InMemoryMemory implements PeekRemoteMemory {
  PeekRemoteDesktop? _last;
  final Map<String, String> _tokens = {};

  @override
  Future<PeekRemoteDesktop?> lastDesktop() async => _last;

  @override
  Future<String?> token(String serverId) async => _tokens[serverId];

  @override
  Future<void> remember(PeekRemoteDesktop desktop, {String? token}) async {
    _last = desktop;
    if (token != null) _tokens[desktop.serverId] = token;
  }

  @override
  Future<void> forget(String serverId) async {
    _tokens.remove(serverId);
    if (_last?.serverId == serverId) _last = null;
  }

  @override
  Future<void> forgetAll() async {
    _last = null;
    _tokens.clear();
  }
}

final class _SharedPreferencesMemory implements PeekRemoteMemory {
  static const String _desktopKey = 'peek_remote.desktop';
  static const String _tokensKey = 'peek_remote.tokens';

  // Made on first use, so an app without the plugin in place fails inside
  // a call the client catches, not while it is being set up.
  late final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  @override
  Future<PeekRemoteDesktop?> lastDesktop() async {
    final text = await _preferences.getString(_desktopKey);
    if (text == null) return null;
    try {
      return PeekRemoteDesktop._fromJson(jsonDecode(text));
    } on FormatException {
      return null;
    }
  }

  @override
  Future<String?> token(String serverId) async =>
      (await _tokens())[serverId] as String?;

  @override
  Future<void> remember(PeekRemoteDesktop desktop, {String? token}) async {
    await _preferences.setString(_desktopKey, jsonEncode(desktop._toJson()));
    if (token == null) return;
    final tokens = await _tokens();
    tokens[desktop.serverId] = token;
    await _preferences.setString(_tokensKey, jsonEncode(tokens));
  }

  @override
  Future<void> forget(String serverId) async {
    final tokens = await _tokens();
    if (tokens.remove(serverId) != null) {
      await _preferences.setString(_tokensKey, jsonEncode(tokens));
    }
    if ((await lastDesktop())?.serverId == serverId) {
      await _preferences.remove(_desktopKey);
    }
  }

  @override
  Future<void> forgetAll() async {
    await _preferences.remove(_desktopKey);
    await _preferences.remove(_tokensKey);
  }

  Future<Map<String, Object?>> _tokens() async {
    final text = await _preferences.getString(_tokensKey);
    if (text == null) return {};
    try {
      return switch (jsonDecode(text)) {
        final Map<String, Object?> map => map,
        _ => {},
      };
    } on FormatException {
      return {};
    }
  }
}
