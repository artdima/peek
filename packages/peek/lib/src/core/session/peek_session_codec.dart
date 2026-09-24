import 'dart:convert';

import '../codec/peek_codec.dart';
import '../model/peek_entry.dart';
import 'peek_session_header.dart';

/// Turns the header and the calls of a session into lines of a `.peek` file
/// and back.
///
/// A `.peek` file is UTF-8 JSON Lines: the header on the first line, then
/// one call per line in the shape [PeekCodec] gives it. JSON escapes line
/// breaks inside strings, so no line ever spans two. The same lines travel
/// as frames to a desktop viewer.
final class PeekSessionCodec {
  /// Creates a codec.
  const PeekSessionCodec();

  /// The oldest format version this Peek reads.
  static const int oldestReadableFormatVersion = 1;

  static const PeekCodec _codec = PeekCodec();

  /// The header line.
  String encodeHeader(PeekSessionHeader header) => jsonEncode({
    'format': 'peek',
    'formatVersion': header.formatVersion,
    'peekVersion': header.peekVersion,
    if (header.name case final name?) 'name': name,
    'platform': header.platform,
    if (header.osVersion case final osVersion?) 'osVersion': osVersion,
    'startedAt': header.startedAt.toUtc().toIso8601String(),
  });

  /// Reads a header line. Throws a [FormatException] when [line] is not a
  /// session header, or when its format is older than
  /// [oldestReadableFormatVersion]; unknown keys are ignored.
  PeekSessionHeader decodeHeader(String line) {
    final Object? json = jsonDecode(line);
    if (json is! Map<String, Object?> || json['format'] != 'peek') {
      throw const FormatException('not a Peek session header');
    }
    final formatVersion = _required<int>(json, 'formatVersion');
    if (formatVersion < oldestReadableFormatVersion) {
      throw FormatException(
        'session format $formatVersion is older than this Peek reads',
      );
    }
    final startedAt = DateTime.tryParse(_required<String>(json, 'startedAt'));
    if (startedAt == null) {
      throw const FormatException('"startedAt" is not an ISO 8601 time');
    }
    return PeekSessionHeader(
      formatVersion: formatVersion,
      peekVersion: _required<String>(json, 'peekVersion'),
      name: _optional<String>(json, 'name'),
      platform: _required<String>(json, 'platform'),
      osVersion: _optional<String>(json, 'osVersion'),
      startedAt: startedAt.toUtc(),
    );
  }

  /// The line for [entry].
  String encodeEntry(PeekEntry entry) => jsonEncode(_codec.encodeEntry(entry));

  /// Reads a line written by [encodeEntry]; throws a [FormatException] when
  /// [line] is not a call.
  PeekEntry decodeEntry(String line) => _codec.decodeEntry(jsonDecode(line));
}

T _required<T extends Object>(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is T) return value;
  throw FormatException('"$key" is missing from the session header');
}

T? _optional<T extends Object>(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is T) return value;
  throw FormatException('"$key" in the session header has the wrong type');
}
