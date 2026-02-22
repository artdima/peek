import 'package:meta/meta.dart';

import '../model/peek_entry.dart';

/// What entries are ordered by.
enum PeekSortField {
  /// When the request went out.
  startedAt,

  /// How long the call took; pending calls have no value.
  duration,

  /// The response body size; calls without a response have no value.
  responseSize,

  /// The request body size.
  requestSize,

  /// The status code; calls without a response have no value.
  statusCode,
}

/// An order for entries.
///
/// Sorting is stable, so entries that compare equal keep the order they
/// came in. Entries without a value for [field] — a pending call sorted by
/// duration, say — always come last, whichever way the sort runs.
@immutable
final class PeekSort {
  /// Creates an order; the default shows the newest entry first.
  const PeekSort({
    this.field = PeekSortField.startedAt,
    this.descending = true,
  });

  /// Newest first.
  static const PeekSort newestFirst = PeekSort();

  /// Oldest first.
  static const PeekSort oldestFirst = PeekSort(descending: false);

  /// Longest call first.
  static const PeekSort slowestFirst = PeekSort(field: PeekSortField.duration);

  /// Largest response first.
  static const PeekSort largestFirst = PeekSort(
    field: PeekSortField.responseSize,
  );

  /// What to order by.
  final PeekSortField field;

  /// Whether the largest value comes first.
  final bool descending;

  /// Orders [a] against [b]: negative when [a] comes first.
  int compare(PeekEntry a, PeekEntry b) {
    final left = _key(a);
    final right = _key(b);
    if (left == null) return right == null ? 0 : 1;
    if (right == null) return -1;
    return descending ? right.compareTo(left) : left.compareTo(right);
  }

  /// A new list of [entries] in this order.
  List<PeekEntry> apply(Iterable<PeekEntry> entries) {
    final indexed =
        entries.indexed.toList()..sort((a, b) {
          final byField = compare(a.$2, b.$2);
          return byField != 0 ? byField : a.$1 - b.$1;
        });
    return [for (final (_, entry) in indexed) entry];
  }

  /// A copy with the given fields replaced.
  PeekSort copyWith({PeekSortField? field, bool? descending}) => PeekSort(
    field: field ?? this.field,
    descending: descending ?? this.descending,
  );

  @override
  bool operator ==(Object other) =>
      other is PeekSort &&
      other.field == field &&
      other.descending == descending;

  @override
  int get hashCode => Object.hash(field, descending);

  @override
  String toString() => 'PeekSort(${field.name} ${descending ? 'desc' : 'asc'})';

  int? _key(PeekEntry entry) => switch (field) {
    PeekSortField.startedAt => entry.startedAt.microsecondsSinceEpoch,
    PeekSortField.duration => entry.duration?.inMicroseconds,
    PeekSortField.responseSize => entry.responseSize,
    PeekSortField.requestSize => entry.requestSize,
    PeekSortField.statusCode => entry.statusCode,
  };
}
