import 'package:meta/meta.dart';

import '../internal/collection_equality.dart';
import 'peek_cookie.dart';

/// An immutable, case-insensitive multimap of HTTP headers.
///
/// Lookups ignore case. [names] and [entries] keep the casing and the order
/// in which each name was first added.
@immutable
final class PeekHeaders {
  const PeekHeaders._(this._headers);

  /// Builds headers from single-valued pairs.
  factory PeekHeaders.fromMap(Map<String, String> map) =>
      PeekHeaders.fromEntries(map.entries);

  /// Builds headers from multi-valued pairs, such as `Headers.map` in Dio.
  factory PeekHeaders.fromMultiMap(Map<String, Iterable<String>> map) =>
      PeekHeaders.fromEntries([
        for (final entry in map.entries)
          for (final value in entry.value) MapEntry(entry.key, value),
      ]);

  /// Builds headers from pairs; a name that repeats collects all of its
  /// values in order. Names and values are trimmed, blank names are skipped.
  factory PeekHeaders.fromEntries(Iterable<MapEntry<String, String>> pairs) {
    final collected = <String, ({String name, List<String> values})>{};
    for (final pair in pairs) {
      final name = pair.key.trim();
      if (name.isEmpty) continue;
      collected
          .putIfAbsent(name.toLowerCase(), () => (name: name, values: []))
          .values
          .add(pair.value.trim());
    }
    return PeekHeaders._(
      Map.unmodifiable({
        for (final entry in collected.entries)
          entry.key: _Header(
            entry.value.name,
            List<String>.unmodifiable(entry.value.values),
          ),
      }),
    );
  }

  /// No headers at all.
  static const PeekHeaders empty = PeekHeaders._({});

  final Map<String, _Header> _headers;

  /// Number of distinct header names.
  int get length => _headers.length;

  /// Whether there are no headers.
  bool get isEmpty => _headers.isEmpty;

  /// Whether there is at least one header.
  bool get isNotEmpty => _headers.isNotEmpty;

  /// Header names in first-seen order and casing.
  List<String> get names =>
      List.unmodifiable(_headers.values.map((header) => header.name));

  /// One pair per value, grouped by name in [names] order.
  List<MapEntry<String, String>> get entries => List.unmodifiable([
    for (final header in _headers.values)
      for (final value in header.values) MapEntry(header.name, value),
  ]);

  /// The values of [name] joined with `, `, or `null` when absent.
  String? operator [](String name) =>
      _headers[name.toLowerCase()]?.values.join(', ');

  /// All values of [name] in order; empty when absent.
  List<String> valuesOf(String name) =>
      _headers[name.toLowerCase()]?.values ?? const [];

  /// Whether a header named [name] is present.
  bool contains(String name) => _headers.containsKey(name.toLowerCase());

  /// The raw `Content-Type` value.
  String? get contentType => this['content-type'];

  /// The `Content-Length` value when present and numeric.
  int? get contentLength =>
      int.tryParse(valuesOf('content-length').firstOrNull ?? '');

  /// Cookies sent in `Cookie` request headers.
  List<PeekCookie> get cookies => List.unmodifiable([
    for (final header in valuesOf('cookie'))
      ...PeekCookie.parseCookieHeader(header),
  ]);

  /// Cookies set by `Set-Cookie` response headers, one header per cookie.
  List<PeekCookie> get setCookies => List.unmodifiable(
    valuesOf('set-cookie').map(PeekCookie.parseSetCookie).nonNulls,
  );

  /// A copy as a plain map keyed by display name.
  Map<String, List<String>> toMap() => Map.unmodifiable({
    for (final header in _headers.values) header.name: header.values,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PeekHeaders || other._headers.length != _headers.length) {
      return false;
    }
    for (final entry in _headers.entries) {
      final counterpart = other._headers[entry.key];
      if (counterpart == null ||
          !listEquals(counterpart.values, entry.value.values)) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAllUnordered([
    for (final entry in _headers.entries)
      Object.hash(entry.key, Object.hashAll(entry.value.values)),
  ]);

  /// Lists header names only, so values never end up in logs by accident.
  @override
  String toString() => 'PeekHeaders(${names.join(', ')})';
}

final class _Header {
  const _Header(this.name, this.values);

  final String name;
  final List<String> values;
}
