import 'dart:async';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../../core/model/peek_entry.dart';
import '../../core/query/peek_facets.dart';
import '../../core/query/peek_filter.dart';
import '../../core/query/peek_sort.dart';
import '../icons/peek_icon_data.dart';
import '../icons/peek_icons.dart';
import '../peek_controller.dart';
import '../peek_scope.dart';
import '../peek_strings.dart';
import '../theme/peek_theme.dart';
import 'peek_icon_button.dart';
import 'peek_segmented.dart';
import 'peek_sheet.dart';

/// The orders the menu offers; the controller can sort by any other
/// field on request.
const List<PeekSort> _sorts = [
  PeekSort.newestFirst,
  PeekSort.oldestFirst,
  PeekSort.slowestFirst,
  PeekSort.largestFirst,
];

/// The mark an order wears in the menu: what it sorts by, or which way
/// it runs where the field has no mark of its own.
PeekIconData _glyphFor(PeekSort sort) => switch (sort.field) {
  PeekSortField.startedAt => PeekIcons.timing,
  PeekSortField.duration => PeekIcons.gauge,
  _ => sort.descending ? PeekIcons.sortDescending : PeekIcons.sortAscending,
};

/// The one-tap views of the list.
///
/// Between them these four own three criteria — errors, pinned and state —
/// and leave every other one, including the search, as it was.
enum _Mode {
  all,
  errors,
  pending,
  pinned;

  String label(PeekStrings strings) => switch (this) {
    _Mode.all => strings.all,
    _Mode.errors => strings.errorsOnly,
    _Mode.pending => strings.pendingOnly,
    _Mode.pinned => strings.pinnedOnly,
  };

  Set<PeekEntryState> get states =>
      this == _Mode.pending ? const {PeekEntryState.pending} : const {};

  int count(PeekFacets facets) => switch (this) {
    _Mode.all => facets.total,
    _Mode.errors => facets.errors,
    _Mode.pending => facets.states[PeekEntryState.pending] ?? 0,
    _Mode.pinned => facets.pinned,
  };

  bool holds(PeekFilter filter) =>
      filter.onlyErrors == (this == _Mode.errors) &&
      filter.onlyPinned == (this == _Mode.pinned) &&
      filter.states.length == states.length &&
      filter.states.containsAll(states);

  PeekFilter applyTo(PeekFilter filter) => filter.copyWith(
    onlyErrors: this == _Mode.errors,
    onlyPinned: this == _Mode.pinned,
    states: states,
  );
}

/// The quick views of the list and the order it is in.
///
/// A filter the modes cannot name — errors and pinned at once, say —
/// leaves all four unselected rather than claiming one of them.
final class PeekQuickBar extends StatelessWidget {
  /// Creates the row.
  const PeekQuickBar({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = PeekScope.of(context);
    final strings = PeekScope.stringsOf(context);
    final theme = PeekTheme.of(context);
    final filter = controller.filter;
    final chosen = _Mode.values.where((mode) => mode.holds(filter)).firstOrNull;

    return Padding(
      padding: EdgeInsets.fromLTRB(theme.gutter, 0, theme.gutter - 8, 0),
      child: Row(
        children: [
          Expanded(
            child: PeekSegmented<_Mode>(
              selected: chosen,
              onChanged:
                  (mode) => controller.filter = mode.applyTo(controller.filter),
              segments: [
                for (final mode in _Mode.values)
                  PeekSegment(
                    value: mode,
                    label: mode.label(strings),
                    count: mode.count(controller.facets),
                  ),
              ],
            ),
          ),
          PeekIconButton(
            icon: Icons.swap_vert,
            tooltip: strings.sort,
            onPressed: () => unawaited(_pickSort(context, controller, strings)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickSort(
    BuildContext context,
    PeekController controller,
    PeekStrings strings,
  ) async {
    final picked = await showPeekActions<PeekSort>(
      context,
      title: strings.sort,
      actions: [
        for (final sort in _sorts)
          PeekAction(
            value: sort,
            label: strings.sortOption(sort.field, descending: sort.descending),
            icon: _glyphFor(sort),
            selected: sort == controller.sort,
          ),
      ],
    );
    if (picked != null) controller.sort = picked;
  }
}
