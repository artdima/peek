import 'package:meta/meta.dart';

import '../internal/collection_equality.dart';

/// A parsed `Content-Type` value such as `application/json; charset=utf-8`.
///
/// [type], [subtype] and parameter names are always lowercase.
@immutable
final class PeekMediaType {
  /// Creates a media type, normalising the case of [type], [subtype] and the
  /// keys of [parameters].
  factory PeekMediaType(
    String type,
    String subtype, {
    Map<String, String> parameters = const {},
  }) => PeekMediaType._(
    type.trim().toLowerCase(),
    subtype.trim().toLowerCase(),
    Map.unmodifiable({
      for (final entry in parameters.entries)
        entry.key.trim().toLowerCase(): entry.value,
    }),
  );

  const PeekMediaType._(this.type, this.subtype, this.parameters);

  /// `application/json`.
  static const PeekMediaType json = PeekMediaType._('application', 'json', {});

  /// `text/plain`.
  static const PeekMediaType plainText = PeekMediaType._('text', 'plain', {});

  /// `text/html`.
  static const PeekMediaType html = PeekMediaType._('text', 'html', {});

  /// `application/octet-stream`.
  static const PeekMediaType octetStream = PeekMediaType._(
    'application',
    'octet-stream',
    {},
  );

  /// `application/x-www-form-urlencoded`.
  static const PeekMediaType formUrlEncoded = PeekMediaType._(
    'application',
    'x-www-form-urlencoded',
    {},
  );

  /// `multipart/form-data`.
  static const PeekMediaType multipartFormData = PeekMediaType._(
    'multipart',
    'form-data',
    {},
  );

  static final RegExp _mimeType = RegExp(
    r"^([\w!#$%&'*+\-.^`|~]+)/([\w!#$%&'*+\-.^`|~]+)$",
  );

  /// Parses a `Content-Type` value, or returns `null` when it does not start
  /// with a `type/subtype` pair.
  static PeekMediaType? tryParse(String? value) {
    if (value == null) return null;
    final parts = value.split(';');
    final match = _mimeType.firstMatch(parts.first.trim());
    if (match == null) return null;

    final parameters = <String, String>{};
    for (final part in parts.skip(1)) {
      final separator = part.indexOf('=');
      if (separator < 0) continue;
      final name = part.substring(0, separator).trim();
      if (name.isEmpty) continue;
      parameters[name] = _unquote(part.substring(separator + 1).trim());
    }
    return PeekMediaType(match[1]!, match[2]!, parameters: parameters);
  }

  /// The top-level type, such as `application`.
  final String type;

  /// The subtype, such as `json`.
  final String subtype;

  /// Parameters keyed by lowercase name; values keep their case.
  final Map<String, String> parameters;

  /// `type/subtype` without parameters.
  String get mimeType => '$type/$subtype';

  /// The `charset` parameter, lowercase.
  String? get charset => parameters['charset']?.toLowerCase();

  /// `application/json`, `text/json` and any `+json` suffix.
  bool get isJson =>
      mimeType == 'application/json' ||
      subtype == 'json' ||
      subtype.endsWith('+json');

  /// `application/xml`, `text/xml` and any `+xml` suffix.
  bool get isXml => subtype == 'xml' || subtype.endsWith('+xml');

  /// `text/html` and `application/xhtml+xml`.
  bool get isHtml =>
      mimeType == 'text/html' || mimeType == 'application/xhtml+xml';

  /// Any `image/*` type.
  bool get isImage => type == 'image';

  /// `application/x-www-form-urlencoded`.
  bool get isFormUrlEncoded => mimeType == 'application/x-www-form-urlencoded';

  /// Any `multipart/*` type.
  bool get isMultipart => type == 'multipart';

  /// Whether a body of this type is readable as text.
  bool get isText =>
      type == 'text' ||
      isJson ||
      isXml ||
      isFormUrlEncoded ||
      _textualApplicationSubtypes.contains(subtype);

  static const Set<String> _textualApplicationSubtypes = {
    'javascript',
    'ecmascript',
    'graphql',
    'x-ndjson',
    'yaml',
    'x-yaml',
    'toml',
    'sql',
  };

  @override
  bool operator ==(Object other) =>
      other is PeekMediaType &&
      other.type == type &&
      other.subtype == subtype &&
      mapEquals(other.parameters, parameters);

  @override
  int get hashCode => Object.hash(
    type,
    subtype,
    Object.hashAllUnordered([
      for (final entry in parameters.entries)
        Object.hash(entry.key, entry.value),
    ]),
  );

  @override
  String toString() => [
    mimeType,
    for (final entry in parameters.entries) '${entry.key}=${entry.value}',
  ].join('; ');

  static String _unquote(String value) =>
      value.length >= 2 && value.startsWith('"') && value.endsWith('"')
          ? value.substring(1, value.length - 1)
          : value;
}
