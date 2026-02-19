import 'package:meta/meta.dart';

import '../internal/collection_equality.dart';
import '../model/peek_body.dart';
import '../model/peek_entry.dart';
import '../model/peek_headers.dart';

/// Where a [PeekSearchQuery] looks.
enum PeekSearchScope {
  /// The full request URL.
  url,

  /// Request and response header names and values.
  headers,

  /// The request body, when it is text or a form.
  requestBody,

  /// The response body, when it is text or a form.
  responseBody,

  /// The failure kind, message and details.
  error,
}

/// A case-insensitive text search over entries.
///
/// Bodies are searched only up to [maxBodyLength] characters so typing in
/// a search box stays responsive with hundreds of large bodies in memory.
@immutable
final class PeekSearchQuery {
  /// Creates a query; by default it looks everywhere.
  const PeekSearchQuery(
    this.text, {
    this.scopes = const {
      PeekSearchScope.url,
      PeekSearchScope.headers,
      PeekSearchScope.requestBody,
      PeekSearchScope.responseBody,
      PeekSearchScope.error,
    },
    this.maxBodyLength = 64 * 1024,
  });

  /// Matches everything.
  static const PeekSearchQuery none = PeekSearchQuery('');

  /// What to look for; surrounding whitespace is ignored.
  final String text;

  /// Where to look.
  final Set<PeekSearchScope> scopes;

  /// How many characters of a body are searched.
  final int maxBodyLength;

  /// Whether there is nothing to look for, so everything matches.
  bool get isEmpty => text.trim().isEmpty || scopes.isEmpty;

  /// Whether [entry] contains the text in any of the scopes.
  bool matches(PeekEntry entry) => compile()(entry);

  /// Builds the matcher once; use it to test many entries.
  bool Function(PeekEntry entry) compile() {
    if (isEmpty) return (_) => true;
    final pattern = RegExp(RegExp.escape(text.trim()), caseSensitive: false);
    bool has(String? haystack) =>
        haystack != null && pattern.hasMatch(_capped(haystack));

    return (entry) {
      if (scopes.contains(PeekSearchScope.url) &&
          has(entry.request.uri.toString())) {
        return true;
      }
      if (scopes.contains(PeekSearchScope.headers) &&
          (_inHeaders(has, entry.request.headers) ||
              _inHeaders(has, entry.response?.headers))) {
        return true;
      }
      if (scopes.contains(PeekSearchScope.requestBody) &&
          _inBody(has, entry.request.body)) {
        return true;
      }
      if (scopes.contains(PeekSearchScope.responseBody) &&
          _inBody(has, entry.response?.body)) {
        return true;
      }
      if (scopes.contains(PeekSearchScope.error)) {
        final failure = entry.failure;
        if (failure != null &&
            (has(failure.kind.name) ||
                has(failure.message) ||
                has(failure.details?.toString()))) {
          return true;
        }
      }
      return false;
    };
  }

  /// The entries of [entries] that match, in order.
  Iterable<PeekEntry> apply(Iterable<PeekEntry> entries) {
    if (isEmpty) return entries;
    final matcher = compile();
    return entries.where(matcher);
  }

  /// A copy with the given fields replaced.
  PeekSearchQuery copyWith({
    String? text,
    Set<PeekSearchScope>? scopes,
    int? maxBodyLength,
  }) => PeekSearchQuery(
    text ?? this.text,
    scopes: scopes ?? this.scopes,
    maxBodyLength: maxBodyLength ?? this.maxBodyLength,
  );

  @override
  bool operator ==(Object other) =>
      other is PeekSearchQuery &&
      other.text == text &&
      other.maxBodyLength == maxBodyLength &&
      setEquals(other.scopes, scopes);

  @override
  int get hashCode =>
      Object.hash(text, maxBodyLength, Object.hashAllUnordered(scopes));

  @override
  String toString() => 'PeekSearchQuery("$text", ${scopes.length} scopes)';

  String _capped(String value) =>
      value.length > maxBodyLength ? value.substring(0, maxBodyLength) : value;

  static bool _inHeaders(bool Function(String?) has, PeekHeaders? headers) {
    if (headers == null) return false;
    for (final entry in headers.entries) {
      if (has(entry.key) || has(entry.value)) return true;
    }
    return false;
  }

  static bool _inBody(bool Function(String?) has, PeekBody? body) =>
      switch (body) {
        PeekTextBody() => has(body.text),
        PeekFormBody() =>
          body.fields.any((field) => has(field.name) || has(field.value)) ||
              body.files.any((file) => has(file.name) || has(file.filename)),
        _ => false,
      };
}
