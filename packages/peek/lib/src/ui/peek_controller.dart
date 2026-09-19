import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/model/peek_entry.dart';
import '../core/model/peek_id.dart';
import '../core/peek.dart';
import '../core/query/peek_facets.dart';
import '../core/query/peek_filter.dart';
import '../core/query/peek_query.dart';
import '../core/query/peek_search_query.dart';
import '../core/query/peek_sort.dart';
import '../core/store/peek_store.dart';

/// The state behind Peek's screens: what the list shows and what is
/// selected.
///
/// Listens to the store and re-runs its [query] when something relevant
/// changes. Typing goes through [searchFor], which waits [searchDebounce]
/// before running — a large store would otherwise be scanned on every
/// keystroke.
final class PeekController extends ChangeNotifier {
  /// Creates a controller over [peek], optionally starting from [query].
  PeekController(this.peek, {PeekQuery query = PeekQuery.none})
    : _query = query,
      _searchText = query.filter.query.text,
      _paused = peek.isPaused {
    _recompute();
    _subscription = peek.store.changes.listen(_onChange);
    _pauses = peek.pauseChanges.listen(_onPause);
  }

  /// How long typing pauses before the list is filtered again.
  static const Duration searchDebounce = Duration(milliseconds: 150);

  /// The instance being shown.
  final Peek peek;

  late final StreamSubscription<PeekStoreChange> _subscription;
  late final StreamSubscription<bool> _pauses;
  Timer? _debounce;
  PeekQuery _query;
  String _searchText;
  List<PeekEntry> _entries = const [];
  PeekFacets _facets = PeekFacets.empty;
  PeekId? _selectedId;
  bool _paused;
  bool _disposed = false;

  /// What the list is filtered and sorted by.
  PeekQuery get query => _query;

  /// Which entries to show, already filtered and sorted.
  List<PeekEntry> get entries => _entries;

  /// What the store as a whole offers a filter to pick from.
  PeekFacets get facets => _facets;

  /// The filter half of [query].
  PeekFilter get filter => _query.filter;

  /// The sort half of [query].
  PeekSort get sort => _query.sort;

  /// The text in the search field, updated before the list catches up.
  String get searchText => _searchText;

  /// Whether typing is still waiting to be applied.
  bool get isSearchPending => _debounce?.isActive ?? false;

  /// How many entries the store holds, before filtering.
  int get totalCount => _facets.total;

  /// Whether the filter hides some of what the store holds.
  bool get isFiltered => !_query.isEmpty;

  /// The id of the selected entry, for the wide layout.
  PeekId? get selectedId => _selectedId;

  /// The selected entry, or `null` when nothing is selected or it is gone.
  PeekEntry? get selected {
    final id = _selectedId;
    return id == null ? null : peek.store.find(id);
  }

  /// Whether recording is paused, by this controller or by the app.
  bool get isPaused => _paused;

  /// Replaces the whole query and re-runs it.
  set query(PeekQuery value) {
    if (value == _query) return;
    _query = value;
    _searchText = value.filter.query.text;
    _debounce?.cancel();
    _recompute();
    notifyListeners();
  }

  /// Replaces the filter, keeping the sort.
  set filter(PeekFilter value) => query = _query.copyWith(filter: value);

  /// Replaces the sort, keeping the filter.
  set sort(PeekSort value) => query = _query.copyWith(sort: value);

  /// Sorts by [field], flipping the direction when it is already in use.
  void sortBy(PeekSortField field) => query = _query.sortBy(field);

  /// Takes [text] from the search field, filtering once typing pauses.
  void searchFor(String text) {
    if (text == _searchText) return;
    _searchText = text;
    notifyListeners();
    _debounce?.cancel();
    _debounce = Timer(searchDebounce, () {
      query = _query.search(text);
    });
  }

  /// Narrows the search to [scopes], applied at once.
  void searchIn(Set<PeekSearchScope> scopes) =>
      query = _query.copyWith(
        filter: filter.copyWith(query: filter.query.copyWith(scopes: scopes)),
      );

  /// Clears every criterion, the search included.
  void resetFilter() => query = PeekQuery(sort: _query.sort);

  /// Selects [id], or clears the selection when it is `null`.
  void select(PeekId? id) {
    if (_selectedId == id) return;
    _selectedId = id;
    notifyListeners();
  }

  /// Pins or unpins [id]; returns whether it is pinned afterwards.
  bool togglePin(PeekId id) => peek.togglePin(id);

  /// Stops recording; what arrives meanwhile is dropped, not queued.
  void pause() => _setPaused(true);

  /// Resumes recording after [pause].
  void resume() => _setPaused(false);

  /// Stops or resumes recording.
  void togglePause() => _setPaused(!_paused);

  /// Empties the store and drops the selection.
  void clear() {
    peek.clear();
    _selectedId = null;
  }

  /// Cancels the subscription and any pending search. Safe to call twice.
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _debounce?.cancel();
    unawaited(_subscription.cancel());
    unawaited(_pauses.cancel());
    super.dispose();
  }

  void _setPaused(bool paused) {
    paused ? peek.pause() : peek.resume();
    _onPause(peek.isPaused);
  }

  void _onPause(bool paused) {
    if (paused == _paused) return;
    _paused = paused;
    notifyListeners();
  }

  void _onChange(PeekStoreChange change) {
    if (change is PeekEntryRemoved && change.entry.id == _selectedId) {
      _selectedId = null;
    }
    if (change is PeekStoreCleared) _selectedId = null;
    _recompute();
    notifyListeners();
  }

  void _recompute() {
    final all = peek.store.entries;
    _entries = _query.run(all);
    _facets = PeekFacets.of(all);
  }
}
