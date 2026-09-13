import 'package:meta/meta.dart';

import '../internal/collection_equality.dart';

/// One cookie from a `Cookie` request header or a `Set-Cookie` response
/// header.
@immutable
final class PeekCookie {
  /// Creates a cookie; [attributes] are keyed by lowercase name and flags
  /// such as `HttpOnly` map to `null`.
  const PeekCookie(this.name, this.value, {this.attributes = const {}});

  /// The cookie name.
  final String name;

  /// The raw cookie value, quotes and encoding untouched.
  final String value;

  /// `Set-Cookie` attributes keyed by lowercase name; a flag maps to `null`.
  final Map<String, String?> attributes;

  /// Parses a `Cookie` request header such as `a=1; b=2`.
  ///
  /// A part without `=` becomes a cookie with an empty value; parts without a
  /// name are skipped.
  static List<PeekCookie> parseCookieHeader(String header) =>
      List.unmodifiable([
        for (final part in header.split(';'))
          if (_split(part) case final pair?)
            PeekCookie(pair.name, pair.value ?? ''),
      ]);

  /// Parses one `Set-Cookie` response header, or returns `null` when the
  /// header carries no `name=value` pair.
  static PeekCookie? parseSetCookie(String header) {
    final parts = header.split(';');
    if (_split(parts.first) case (:final name, :final String value)) {
      final attributes = <String, String?>{};
      for (final part in parts.skip(1)) {
        if (_split(part) case final attribute?) {
          attributes[attribute.name.toLowerCase()] = attribute.value;
        }
      }
      return PeekCookie(name, value, attributes: Map.unmodifiable(attributes));
    }
    return null;
  }

  /// The `Path` attribute.
  String? get path => attributes['path'];

  /// The `Domain` attribute.
  String? get domain => attributes['domain'];

  /// The raw `Expires` attribute.
  String? get expires => attributes['expires'];

  /// The `Expires` attribute as a UTC time.
  ///
  /// `null` when the attribute is absent or written in a form other than the
  /// RFC 1123 one servers send: `Wed, 21 Oct 2015 07:28:00 GMT`.
  DateTime? get expiresAt {
    final raw = expires;
    if (raw == null) return null;
    final match = _expiresFormat.firstMatch(raw.trim());
    if (match == null) return null;
    final month = _months.indexOf(match[2]!.toLowerCase()) + 1;
    if (month == 0) return null;
    return DateTime.utc(
      int.parse(match[3]!),
      month,
      int.parse(match[1]!),
      int.parse(match[4]!),
      int.parse(match[5]!),
      int.parse(match[6]!),
    );
  }

  /// The `Max-Age` attribute in seconds, when present and numeric.
  int? get maxAge => int.tryParse(attributes['max-age'] ?? '');

  /// The `SameSite` attribute.
  String? get sameSite => attributes['samesite'];

  static final RegExp _expiresFormat = RegExp(
    r'^[A-Za-z]{3},\s+(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+'
    r'(\d{1,2}):(\d{2}):(\d{2})\s+GMT$',
  );

  static const List<String> _months = [
    'jan',
    'feb',
    'mar',
    'apr',
    'may',
    'jun',
    'jul',
    'aug',
    'sep',
    'oct',
    'nov',
    'dec',
  ];

  /// Whether the `Secure` flag is set.
  bool get isSecure => attributes.containsKey('secure');

  /// Whether the `HttpOnly` flag is set.
  bool get isHttpOnly => attributes.containsKey('httponly');

  @override
  bool operator ==(Object other) =>
      other is PeekCookie &&
      other.name == name &&
      other.value == value &&
      mapEquals(other.attributes, attributes);

  @override
  int get hashCode => Object.hash(
    name,
    value,
    Object.hashAllUnordered([
      for (final entry in attributes.entries)
        Object.hash(entry.key, entry.value),
    ]),
  );

  @override
  String toString() => 'PeekCookie($name)';

  static ({String name, String? value})? _split(String part) {
    final trimmed = part.trim();
    if (trimmed.isEmpty) return null;
    final separator = trimmed.indexOf('=');
    if (separator < 0) return (name: trimmed, value: null);
    final name = trimmed.substring(0, separator).trim();
    if (name.isEmpty) return null;
    return (name: name, value: trimmed.substring(separator + 1).trim());
  }
}
