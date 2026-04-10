import 'package:flutter/material.dart';

import '../../core/model/peek_entry.dart';
import '../../core/query/peek_filter.dart';
import '../../core/query/peek_sort.dart';
import '../peek_scope.dart';
import '../peek_strings.dart';
import '../theme/peek_theme.dart';

/// The orders the menu offers; the controller can sort by any other
/// field on request.
const List<PeekSort> _sorts = [
  PeekSort.newestFirst,
  PeekSort.oldestFirst,
  PeekSort.slowestFirst,
  PeekSort.largestFirst,
];

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

    return Padding(
      padding: EdgeInsets.fromLTRB(theme.gutter, 0, theme.gutter - 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final mode in _Mode.values)
                  ChoiceChip(
                    label: Text(
                      mode.label(strings),
                      style: const TextStyle(fontSize: 12),
                    ),
                    selected: mode.holds(filter),
                    onSelected: (_) => controller.filter = mode.applyTo(filter),
                  ),
              ],
            ),
          ),
          PopupMenuButton<PeekSort>(
            tooltip: strings.sort,
            icon: const Icon(Icons.swap_vert, size: 20),
            onSelected: (sort) => controller.sort = sort,
            itemBuilder:
                (context) => [
                  for (final sort in _sorts)
                    CheckedPopupMenuItem(
                      value: sort,
                      checked: sort == controller.sort,
                      child: Text(
                        strings.sortOption(
                          sort.field,
                          descending: sort.descending,
                        ),
                      ),
                    ),
                ],
          ),
        ],
      ),
    );
  }
}
