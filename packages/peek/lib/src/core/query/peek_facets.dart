import 'package:meta/meta.dart';

import '../model/peek_entry.dart';
import '../model/peek_status_class.dart';

/// The values a filter can pick from, counted over a set of entries.
///
/// Every map lists its keys by count, highest first, ties by key.
@immutable
final class PeekFacets {
  const PeekFacets._({
    required this.total,
    required this.errors,
    required this.pinned,
    required this.methods,
    required this.hosts,
    required this.sources,
    required this.contentTypes,
    required this.statusCodes,
    required this.statusClasses,
    required this.states,
  });

  /// Counts what [entries] contain.
  factory PeekFacets.of(Iterable<PeekEntry> entries) {
    var total = 0;
    var errors = 0;
    var pinned = 0;
    final methods = <String, int>{};
    final hosts = <String, int>{};
    final sources = <String, int>{};
    final contentTypes = <String, int>{};
    final statusCodes = <int, int>{};
    final statusClasses = <PeekStatusClass, int>{};
    final states = <PeekEntryState, int>{};

    for (final entry in entries) {
      total++;
      if (entry.isError) errors++;
      if (entry.isPinned) pinned++;
      methods.update(entry.request.method, _increment, ifAbsent: _one);
      hosts.update(entry.request.host, _increment, ifAbsent: _one);
      sources.update(entry.source, _increment, ifAbsent: _one);
      states.update(entry.state, _increment, ifAbsent: _one);
      final type = entry.response?.mediaType?.mimeType;
      if (type != null) contentTypes.update(type, _increment, ifAbsent: _one);
      final code = entry.statusCode;
      if (code != null) statusCodes.update(code, _increment, ifAbsent: _one);
      final statusClass = entry.statusClass;
      if (statusClass != null) {
        statusClasses.update(statusClass, _increment, ifAbsent: _one);
      }
    }

    return PeekFacets._(
      total: total,
      errors: errors,
      pinned: pinned,
      methods: _ranked(methods, (a, b) => a.compareTo(b)),
      hosts: _ranked(hosts, (a, b) => a.compareTo(b)),
      sources: _ranked(sources, (a, b) => a.compareTo(b)),
      contentTypes: _ranked(contentTypes, (a, b) => a.compareTo(b)),
      statusCodes: _ranked(statusCodes, (a, b) => a.compareTo(b)),
      statusClasses: _ranked(statusClasses, (a, b) => a.index - b.index),
      states: _ranked(states, (a, b) => a.index - b.index),
    );
  }

  /// No entries at all.
  static const PeekFacets empty = PeekFacets._(
    total: 0,
    errors: 0,
    pinned: 0,
    methods: {},
    hosts: {},
    sources: {},
    contentTypes: {},
    statusCodes: {},
    statusClasses: {},
    states: {},
  );

  /// How many entries were counted.
  final int total;

  /// How many are errors.
  final int errors;

  /// How many are pinned.
  final int pinned;

  /// Methods and how often each occurs.
  final Map<String, int> methods;

  /// Hosts and how often each occurs.
  final Map<String, int> hosts;

  /// Adapter names and how often each occurs.
  final Map<String, int> sources;

  /// Response media types, without parameters, and how often each occurs.
  final Map<String, int> contentTypes;

  /// Status codes and how often each occurs.
  final Map<int, int> statusCodes;

  /// Status classes and how often each occurs.
  final Map<PeekStatusClass, int> statusClasses;

  /// Lifecycle states and how often each occurs.
  final Map<PeekEntryState, int> states;

  @override
  String toString() =>
      'PeekFacets($total entries, ${hosts.length} hosts, '
      '${methods.length} methods)';

  static int _increment(int count) => count + 1;

  static int _one() => 1;

  static Map<K, int> _ranked<K>(Map<K, int> counts, Comparator<K> byKey) {
    final entries =
        counts.entries.toList()..sort((a, b) {
          final byCount = b.value.compareTo(a.value);
          return byCount != 0 ? byCount : byKey(a.key, b.key);
        });
    return Map.unmodifiable({
      for (final entry in entries) entry.key: entry.value,
    });
  }
}
