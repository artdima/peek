import 'package:meta/meta.dart';

import '../internal/collection_equality.dart';
import 'peek_body.dart';
import 'peek_headers.dart';

/// The request half of a network call: what was sent.
@immutable
final class PeekRequest {
  /// Creates a request. [method] is uppercased; [extra] is copied.
  PeekRequest({
    required String method,
    required this.uri,
    this.headers = PeekHeaders.empty,
    this.body = const PeekBody.empty(),
    Map<String, Object?> extra = const {},
  }) : method = method.toUpperCase(),
       extra = Map.unmodifiable(extra);

  /// The HTTP method, uppercase.
  final String method;

  /// The full URL, query included.
  final Uri uri;

  /// The request headers.
  final PeekHeaders headers;

  /// The request body.
  final PeekBody body;

  /// Free-form metadata from the adapter, such as a client label.
  final Map<String, Object?> extra;

  /// The host part of [uri].
  String get host => uri.host;

  /// The path part of [uri].
  String get path => uri.path;

  /// Query parameters of [uri], every value of a repeated name kept.
  Map<String, List<String>> get queryParameters => uri.queryParametersAll;

  /// Body size from the `Content-Length` header, else from the body itself.
  int? get contentLength => headers.contentLength ?? body.size;

  /// A copy with the given fields replaced.
  PeekRequest copyWith({
    String? method,
    Uri? uri,
    PeekHeaders? headers,
    PeekBody? body,
    Map<String, Object?>? extra,
  }) => PeekRequest(
    method: method ?? this.method,
    uri: uri ?? this.uri,
    headers: headers ?? this.headers,
    body: body ?? this.body,
    extra: extra ?? this.extra,
  );

  @override
  bool operator ==(Object other) =>
      other is PeekRequest &&
      other.method == method &&
      other.uri == uri &&
      other.headers == headers &&
      other.body == body &&
      mapEquals(other.extra, extra);

  @override
  int get hashCode => Object.hash(
    method,
    uri,
    headers,
    body,
    Object.hashAllUnordered([
      for (final entry in extra.entries) Object.hash(entry.key, entry.value),
    ]),
  );

  /// Method, host and path only: no query, headers or body.
  @override
  String toString() => 'PeekRequest($method $host$path)';
}
