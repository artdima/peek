import 'package:meta/meta.dart';

import '../model/peek_entry.dart';
import 'peek_facets.dart';
import 'peek_filter.dart';
import 'peek_sort.dart';

/// What the list shows: which entries, in which order.
///
/// This is the one call the UI makes against a store's entries.
///
/// ```dart
/// const query = PeekQuery(
///   filter: PeekFilter(onlyErrors: true),
///   sort: PeekSort.slowestFirst,
/// );
/// final visible = query.run(peek.store.entries);
/// ```
@immutable
final class PeekQuery {
  /// Creates a query; the default keeps everything, newest first.
  const PeekQuery({
    this.filter = PeekFilter.none,
    this.sort = PeekSort.newestFirst,
  });

  /// Everything, newest first.
  static const PeekQuery none = PeekQuery();

  /// Which entries to keep.
  final PeekFilter filter;

  /// What order to show them in.
  final PeekSort sort;

  /// Whether nothing is filtered out, whatever the order.
  bool get isEmpty => filter.isEmpty;

  /// The entries of [entries] that match [filter], in [sort] order.
  List<PeekEntry> run(Iterable<PeekEntry> entries) =>
      sort.apply(filter.apply(entries));

  /// What [entries] offer a filter to pick from, before filtering.
  PeekFacets facets(Iterable<PeekEntry> entries) => PeekFacets.of(entries);

  /// A copy with the given fields replaced.
  PeekQuery copyWith({PeekFilter? filter, PeekSort? sort}) =>
      PeekQuery(filter: filter ?? this.filter, sort: sort ?? this.sort);

  /// A copy with [text] searched for, keeping the scopes already set.
  PeekQuery search(String text) => copyWith(
    filter: filter.copyWith(query: filter.query.copyWith(text: text)),
  );

  /// A copy sorted by [field], flipping the direction when it is already
  /// the field being sorted by.
  PeekQuery sortBy(PeekSortField field) => copyWith(
    sort:
        sort.field == field
            ? sort.copyWith(descending: !sort.descending)
            : PeekSort(field: field),
  );

  @override
  bool operator ==(Object other) =>
      other is PeekQuery && other.filter == filter && other.sort == sort;

  @override
  int get hashCode => Object.hash(filter, sort);

  @override
  String toString() => 'PeekQuery($filter, $sort)';
}
