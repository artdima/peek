import 'package:meta/meta.dart';

import '../internal/collection_equality.dart';
import '../model/peek_entry.dart';
import '../model/peek_status_class.dart';
import 'peek_search_query.dart';

/// A closed or half-open range of durations.
@immutable
final class PeekDurationRange {
  /// Creates a range; a `null` bound is unbounded on that side.
  const PeekDurationRange({this.min, this.max});

  /// Matches everything.
  static const PeekDurationRange any = PeekDurationRange();

  /// The shortest duration that matches, if bounded.
  final Duration? min;

  /// The longest duration that matches, if bounded.
  final Duration? max;

  /// Whether both sides are open.
  bool get isUnbounded => min == null && max == null;

  /// Whether [duration] lies within the range, bounds included.
  bool contains(Duration duration) {
    final low = min;
    final high = max;
    return (low == null || duration >= low) &&
        (high == null || duration <= high);
  }

  @override
  bool operator ==(Object other) =>
      other is PeekDurationRange && other.min == min && other.max == max;

  @override
  int get hashCode => Object.hash(min, max);

  @override
  String toString() => 'PeekDurationRange($min..$max)';
}

/// A closed or half-open range of moments.
@immutable
final class PeekDateRange {
  /// Creates a range; a `null` bound is unbounded on that side.
  const PeekDateRange({this.from, this.to});

  /// Matches everything.
  static const PeekDateRange any = PeekDateRange();

  /// The earliest moment that matches, if bounded.
  final DateTime? from;

  /// The latest moment that matches, if bounded.
  final DateTime? to;

  /// Whether both sides are open.
  bool get isUnbounded => from == null && to == null;

  /// Whether [moment] lies within the range, bounds included.
  bool contains(DateTime moment) {
    final start = from;
    final end = to;
    return (start == null || !moment.isBefore(start)) &&
        (end == null || !moment.isAfter(end));
  }

  @override
  bool operator ==(Object other) =>
      other is PeekDateRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => 'PeekDateRange($from..$to)';
}

/// Which entries to show. Every criterion that is set must hold; an empty
/// set, an unbounded range or an empty [query] means "any".
///
/// Names match case-insensitively: methods are compared uppercase, hosts
/// lowercase. [contentTypes] hold bare media types such as
/// `application/json` and match the response.
@immutable
final class PeekFilter {
  /// Creates a filter; the default matches everything.
  const PeekFilter({
    this.methods = const {},
    this.statusClasses = const {},
    this.statusCodes = const {},
    this.hosts = const {},
    this.states = const {},
    this.sources = const {},
    this.contentTypes = const {},
    this.onlyErrors = false,
    this.onlyPinned = false,
    this.duration = PeekDurationRange.any,
    this.dates = PeekDateRange.any,
    this.query = PeekSearchQuery.none,
  });

  /// Matches everything.
  static const PeekFilter none = PeekFilter();

  /// HTTP methods to keep.
  final Set<String> methods;

  /// Status classes to keep.
  final Set<PeekStatusClass> statusClasses;

  /// Exact status codes to keep.
  final Set<int> statusCodes;

  /// Hosts to keep.
  final Set<String> hosts;

  /// Lifecycle states to keep.
  final Set<PeekEntryState> states;

  /// Adapter names to keep.
  final Set<String> sources;

  /// Response media types to keep, without parameters.
  final Set<String> contentTypes;

  /// Keep only failed calls and 4xx/5xx answers.
  final bool onlyErrors;

  /// Keep only pinned entries.
  final bool onlyPinned;

  /// Keep only completed calls whose duration lies in the range.
  final PeekDurationRange duration;

  /// Keep only calls started within the range.
  final PeekDateRange dates;

  /// Keep only entries containing the searched text.
  final PeekSearchQuery query;

  /// Whether nothing is set, so everything matches.
  bool get isEmpty => activeCount == 0;

  /// How many criteria are set — what a filter button's badge shows.
  int get activeCount =>
      [
        methods.isNotEmpty,
        statusClasses.isNotEmpty,
        statusCodes.isNotEmpty,
        hosts.isNotEmpty,
        states.isNotEmpty,
        sources.isNotEmpty,
        contentTypes.isNotEmpty,
        onlyErrors,
        onlyPinned,
        !duration.isUnbounded,
        !dates.isUnbounded,
        !query.isEmpty,
      ].where((active) => active).length;

  /// Whether [entry] satisfies every criterion that is set.
  bool matches(PeekEntry entry) =>
      _matchesCriteria(entry) && query.matches(entry);

  bool _matchesCriteria(PeekEntry entry) {
    if (onlyErrors && !entry.isError) return false;
    if (onlyPinned && !entry.isPinned) return false;
    if (methods.isNotEmpty &&
        !_containsIgnoringCase(methods, entry.request.method)) {
      return false;
    }
    if (hosts.isNotEmpty && !_containsIgnoringCase(hosts, entry.request.host)) {
      return false;
    }
    if (states.isNotEmpty && !states.contains(entry.state)) return false;
    if (sources.isNotEmpty && !sources.contains(entry.source)) return false;
    if (statusClasses.isNotEmpty) {
      final statusClass = entry.statusClass;
      if (statusClass == null || !statusClasses.contains(statusClass)) {
        return false;
      }
    }
    if (statusCodes.isNotEmpty) {
      final code = entry.statusCode;
      if (code == null || !statusCodes.contains(code)) return false;
    }
    if (contentTypes.isNotEmpty) {
      final type = entry.response?.mediaType?.mimeType;
      if (type == null || !_containsIgnoringCase(contentTypes, type)) {
        return false;
      }
    }
    if (!duration.isUnbounded) {
      final elapsed = entry.duration;
      if (elapsed == null || !duration.contains(elapsed)) return false;
    }
    if (!dates.isUnbounded && !dates.contains(entry.startedAt)) return false;
    return true;
  }

  /// The entries of [entries] that match, in order.
  Iterable<PeekEntry> apply(Iterable<PeekEntry> entries) {
    if (isEmpty) return entries;
    final search = query.compile();
    return entries.where((entry) => _matchesCriteria(entry) && search(entry));
  }

  /// A copy with the given fields replaced. Pass an empty set,
  /// [PeekDurationRange.any], [PeekDateRange.any] or [PeekSearchQuery.none]
  /// to clear a criterion.
  PeekFilter copyWith({
    Set<String>? methods,
    Set<PeekStatusClass>? statusClasses,
    Set<int>? statusCodes,
    Set<String>? hosts,
    Set<PeekEntryState>? states,
    Set<String>? sources,
    Set<String>? contentTypes,
    bool? onlyErrors,
    bool? onlyPinned,
    PeekDurationRange? duration,
    PeekDateRange? dates,
    PeekSearchQuery? query,
  }) => PeekFilter(
    methods: methods ?? this.methods,
    statusClasses: statusClasses ?? this.statusClasses,
    statusCodes: statusCodes ?? this.statusCodes,
    hosts: hosts ?? this.hosts,
    states: states ?? this.states,
    sources: sources ?? this.sources,
    contentTypes: contentTypes ?? this.contentTypes,
    onlyErrors: onlyErrors ?? this.onlyErrors,
    onlyPinned: onlyPinned ?? this.onlyPinned,
    duration: duration ?? this.duration,
    dates: dates ?? this.dates,
    query: query ?? this.query,
  );

  @override
  bool operator ==(Object other) =>
      other is PeekFilter &&
      setEquals(other.methods, methods) &&
      setEquals(other.statusClasses, statusClasses) &&
      setEquals(other.statusCodes, statusCodes) &&
      setEquals(other.hosts, hosts) &&
      setEquals(other.states, states) &&
      setEquals(other.sources, sources) &&
      setEquals(other.contentTypes, contentTypes) &&
      other.onlyErrors == onlyErrors &&
      other.onlyPinned == onlyPinned &&
      other.duration == duration &&
      other.dates == dates &&
      other.query == query;

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(methods),
    Object.hashAllUnordered(statusClasses),
    Object.hashAllUnordered(statusCodes),
    Object.hashAllUnordered(hosts),
    Object.hashAllUnordered(states),
    Object.hashAllUnordered(sources),
    Object.hashAllUnordered(contentTypes),
    onlyErrors,
    onlyPinned,
    duration,
    dates,
    query,
  );

  @override
  String toString() => 'PeekFilter($activeCount active)';

  static bool _containsIgnoringCase(Set<String> values, String value) {
    final lower = value.toLowerCase();
    return values.any((candidate) => candidate.toLowerCase() == lower);
  }
}
