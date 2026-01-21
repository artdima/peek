import 'package:meta/meta.dart';

import '../internal/collection_equality.dart';
import 'peek_body.dart';
import 'peek_headers.dart';
import 'peek_status_class.dart';

/// The response half of a network call: what came back.
@immutable
final class PeekResponse {
  /// Creates a response; [redirects] are copied.
  PeekResponse({
    required this.statusCode,
    this.statusMessage,
    this.headers = PeekHeaders.empty,
    this.body = const PeekBody.empty(),
    List<PeekRedirect> redirects = const [],
  }) : redirects = List.unmodifiable(redirects);

  /// The HTTP status code.
  final int statusCode;

  /// The reason phrase sent with the status, when any.
  final String? statusMessage;

  /// The response headers.
  final PeekHeaders headers;

  /// The response body.
  final PeekBody body;

  /// Redirects followed before this response, in order.
  final List<PeekRedirect> redirects;

  /// The class of [statusCode].
  PeekStatusClass get statusClass => PeekStatusClass.of(statusCode);

  /// Body size from the `Content-Length` header, else from the body itself.
  int? get contentLength => headers.contentLength ?? body.size;

  /// A copy with the given fields replaced.
  PeekResponse copyWith({
    int? statusCode,
    String? statusMessage,
    PeekHeaders? headers,
    PeekBody? body,
    List<PeekRedirect>? redirects,
  }) => PeekResponse(
    statusCode: statusCode ?? this.statusCode,
    statusMessage: statusMessage ?? this.statusMessage,
    headers: headers ?? this.headers,
    body: body ?? this.body,
    redirects: redirects ?? this.redirects,
  );

  @override
  bool operator ==(Object other) =>
      other is PeekResponse &&
      other.statusCode == statusCode &&
      other.statusMessage == statusMessage &&
      other.headers == headers &&
      other.body == body &&
      listEquals(other.redirects, redirects);

  @override
  int get hashCode => Object.hash(
    statusCode,
    statusMessage,
    headers,
    body,
    Object.hashAll(redirects),
  );

  @override
  String toString() =>
      statusMessage == null
          ? 'PeekResponse($statusCode)'
          : 'PeekResponse($statusCode $statusMessage)';
}

/// One hop of a redirect chain.
@immutable
final class PeekRedirect {
  /// Creates a redirect record.
  const PeekRedirect({
    required this.statusCode,
    required this.method,
    required this.location,
  });

  /// The status code that caused the redirect.
  final int statusCode;

  /// The method used for the redirected request.
  final String method;

  /// Where the redirect pointed.
  final Uri location;

  @override
  bool operator ==(Object other) =>
      other is PeekRedirect &&
      other.statusCode == statusCode &&
      other.method == method &&
      other.location == location;

  @override
  int get hashCode => Object.hash(statusCode, method, location);

  @override
  String toString() => 'PeekRedirect($statusCode $method ${location.host})';
}
