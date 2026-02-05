import 'package:meta/meta.dart';

import '../internal/collection_equality.dart';

/// Which headers, query parameters and body keys Peek masks before storing
/// a call, so secrets never sit in memory or reach the screen.
///
/// Names match case-insensitively and exactly. Add your own to the defaults:
///
/// ```dart
/// PeekRedactionPolicy(
///   headerNames: {...PeekRedactionPolicy.defaultHeaderNames, 'x-session'},
/// )
/// ```
@immutable
final class PeekRedactionPolicy {
  /// Creates a policy; every set defaults to Peek's built-in list.
  const PeekRedactionPolicy({
    this.headerNames = defaultHeaderNames,
    this.queryKeys = defaultQueryKeys,
    this.bodyKeys = defaultBodyKeys,
    this.replacement = defaultReplacement,
  });

  /// Masks nothing.
  static const PeekRedactionPolicy none = PeekRedactionPolicy(
    headerNames: {},
    queryKeys: {},
    bodyKeys: {},
  );

  /// Headers masked by default.
  static const Set<String> defaultHeaderNames = {
    'authorization',
    'proxy-authorization',
    'cookie',
    'set-cookie',
    'x-api-key',
    'x-auth-token',
  };

  /// Query parameters masked by default.
  static const Set<String> defaultQueryKeys = {
    'token',
    'access_token',
    'refresh_token',
    'api_key',
    'apikey',
    'key',
    'secret',
    'password',
    'signature',
  };

  /// JSON and form keys masked by default.
  static const Set<String> defaultBodyKeys = {
    'password',
    'token',
    'access_token',
    'refresh_token',
    'id_token',
    'secret',
    'client_secret',
    'api_key',
    'apikey',
    'authorization',
  };

  /// What masked values are replaced with. ASCII, so it survives a URL.
  static const String defaultReplacement = '*****';

  /// Header names to mask. `cookie` and `set-cookie` keep their cookie
  /// names and attributes; only the values go.
  final Set<String> headerNames;

  /// Query parameter names to mask, in URLs and URL-encoded bodies.
  final Set<String> queryKeys;

  /// Keys to mask in JSON bodies, at any depth, and in form fields.
  final Set<String> bodyKeys;

  /// The text a masked value becomes.
  final String replacement;

  /// Whether the policy masks nothing at all.
  bool get isEmpty =>
      headerNames.isEmpty && queryKeys.isEmpty && bodyKeys.isEmpty;

  /// Whether the header called [name] is masked.
  bool matchesHeader(String name) => _contains(headerNames, name);

  /// Whether the query parameter called [name] is masked.
  bool matchesQuery(String name) => _contains(queryKeys, name);

  /// Whether the body key called [name] is masked.
  bool matchesBodyKey(String name) => _contains(bodyKeys, name);

  /// A copy with the given fields replaced.
  PeekRedactionPolicy copyWith({
    Set<String>? headerNames,
    Set<String>? queryKeys,
    Set<String>? bodyKeys,
    String? replacement,
  }) => PeekRedactionPolicy(
    headerNames: headerNames ?? this.headerNames,
    queryKeys: queryKeys ?? this.queryKeys,
    bodyKeys: bodyKeys ?? this.bodyKeys,
    replacement: replacement ?? this.replacement,
  );

  @override
  bool operator ==(Object other) =>
      other is PeekRedactionPolicy &&
      other.replacement == replacement &&
      setEquals(other.headerNames, headerNames) &&
      setEquals(other.queryKeys, queryKeys) &&
      setEquals(other.bodyKeys, bodyKeys);

  @override
  int get hashCode => Object.hash(
    replacement,
    Object.hashAllUnordered(headerNames),
    Object.hashAllUnordered(queryKeys),
    Object.hashAllUnordered(bodyKeys),
  );

  @override
  String toString() =>
      'PeekRedactionPolicy(${headerNames.length} headers, '
      '${queryKeys.length} query keys, ${bodyKeys.length} body keys)';

  static bool _contains(Set<String> names, String name) {
    final lower = name.toLowerCase();
    return names.any((candidate) => candidate.toLowerCase() == lower);
  }
}
