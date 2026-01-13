import 'dart:math';

import 'package:meta/meta.dart';

/// Identifies one network call across the events an adapter reports for it.
///
/// Adapters obtain ids from [PeekId.generate] and reuse the same id for the
/// request, response and failure events of a single call.
@immutable
final class PeekId {
  /// Wraps an existing identifier, for example one read back from an export.
  const PeekId(this.value) : assert(value != '', 'PeekId is empty');

  /// Creates an id that is unique within this isolate and, thanks to the
  /// random session prefix, practically unique across app launches.
  factory PeekId.generate() =>
      PeekId('$_session-${(_next++).toRadixString(36)}');

  static const String _alphabet = '0123456789abcdefghijklmnopqrstuvwxyz';
  static final String _session = _randomBase36(6);
  static int _next = 0;

  /// The identifier itself.
  final String value;

  @override
  bool operator ==(Object other) => other is PeekId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;

  static String _randomBase36(int length) {
    final random = Random();
    return List.generate(length, (_) => _alphabet[random.nextInt(36)]).join();
  }
}
