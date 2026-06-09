import 'package:flutter/widgets.dart';

import '../../core/model/peek_entry.dart';
import '../../core/model/peek_status_class.dart';
import '../../core/query/peek_filter.dart';
import '../peek_controller.dart';
import '../peek_scope.dart';
import '../peek_strings.dart';
import '../theme/peek_theme.dart';
import 'peek_pill.dart';

/// What the list is filtered by right now, one removable chip per value.
///
/// The search has its own field, so it is not repeated here. Nothing is
/// shown while nothing is filtered.
final class PeekActiveFilters extends StatelessWidget {
  /// Creates the row.
  const PeekActiveFilters({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = PeekScope.of(context);
    final strings = PeekScope.stringsOf(context);
    final theme = PeekTheme.of(context);
    final chips = _chips(controller, strings);
    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.fromLTRB(theme.gutter, 0, theme.gutter, 6),
      child: Wrap(spacing: 6, runSpacing: 4, children: chips),
    );
  }

  List<Widget> _chips(PeekController controller, PeekStrings strings) {
    final filter = controller.filter;

    void apply(PeekFilter next) => controller.filter = next;

    List<Widget> removable<T>({
      required Set<T> values,
      required String Function(T value) label,
      required PeekFilter Function(Set<T> rest) without,
    }) => [
      for (final value in values)
        _RemovableChip(
          label: label(value),
          onDeleted: () => apply(without({...values}..remove(value))),
        ),
    ];

    return [
      if (filter.onlyErrors)
        _RemovableChip(
          label: strings.errorsOnly,
          onDeleted: () => apply(filter.copyWith(onlyErrors: false)),
        ),
      if (filter.onlyPinned)
        _RemovableChip(
          label: strings.pinnedOnly,
          onDeleted: () => apply(filter.copyWith(onlyPinned: false)),
        ),
      ...removable<PeekStatusClass>(
        values: filter.statusClasses,
        label: strings.statusClassName,
        without: (rest) => filter.copyWith(statusClasses: rest),
      ),
      ...removable<int>(
        values: filter.statusCodes,
        label: (code) => '$code',
        without: (rest) => filter.copyWith(statusCodes: rest),
      ),
      ...removable<String>(
        values: filter.methods,
        label: (method) => method,
        without: (rest) => filter.copyWith(methods: rest),
      ),
      ...removable<String>(
        values: filter.hosts,
        label: (host) => host,
        without: (rest) => filter.copyWith(hosts: rest),
      ),
      ...removable<String>(
        values: filter.contentTypes,
        label: (type) => type,
        without: (rest) => filter.copyWith(contentTypes: rest),
      ),
      ...removable<PeekEntryState>(
        values: filter.states,
        label: strings.entryState,
        without: (rest) => filter.copyWith(states: rest),
      ),
      ...removable<String>(
        values: filter.sources,
        label: (source) => source,
        without: (rest) => filter.copyWith(sources: rest),
      ),
      if (!filter.duration.isUnbounded)
        _RemovableChip(
          label: strings.durationFilter(filter.duration),
          onDeleted:
              () => apply(filter.copyWith(duration: PeekDurationRange.any)),
        ),
      if (!filter.dates.isUnbounded)
        _RemovableChip(
          label: strings.dateFilter(filter.dates),
          onDeleted: () => apply(filter.copyWith(dates: PeekDateRange.any)),
        ),
    ];
  }
}

class _RemovableChip extends StatelessWidget {
  const _RemovableChip({required this.label, required this.onDeleted});

  final String label;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    // A host or a media type can be long; the row must not grow with it.
    constraints: const BoxConstraints(maxWidth: 200),
    child: PeekPill(
      label: label,
      onRemove: onDeleted,
      removeLabel: PeekScope.stringsOf(context).removeFilter(label),
    ),
  );
}
