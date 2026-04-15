import 'package:flutter/material.dart';

import '../../core/model/peek_entry.dart';
import '../../core/model/peek_status_class.dart';
import '../../core/query/peek_filter.dart';
import '../peek_controller.dart';
import '../peek_scope.dart';
import '../peek_strings.dart';
import '../theme/peek_theme.dart';

/// How long a call took, as the sheet offers it.
const List<PeekDurationRange> _durations = [
  PeekDurationRange.any,
  PeekDurationRange(max: Duration(milliseconds: 100)),
  PeekDurationRange(
    min: Duration(milliseconds: 100),
    max: Duration(seconds: 1),
  ),
  PeekDurationRange(min: Duration(seconds: 1)),
];

/// How far back the sheet offers to look.
const List<Duration> _windows = [
  Duration(minutes: 5),
  Duration(minutes: 15),
  Duration(hours: 1),
];

/// Every criterion the recorded calls offer, counted.
///
/// Choices apply as they are made, so the list behind the sheet follows
/// along; there is nothing to confirm and nothing to lose by closing it.
final class PeekFiltersSheet extends StatelessWidget {
  /// Creates the panel.
  const PeekFiltersSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = PeekScope.of(context);
    final strings = PeekScope.stringsOf(context);
    final theme = PeekTheme.of(context);
    final filter = controller.filter;
    final facets = controller.facets;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: theme.gutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(strings.filters, style: theme.headline)),
                TextButton(
                  onPressed: filter.isEmpty ? null : controller.resetFilter,
                  child: Text(strings.resetFilters),
                ),
              ],
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Section(
                      children: [
                        _FacetChip(
                          label: strings.errorsOnly,
                          count: facets.errors,
                          selected: filter.onlyErrors,
                          onSelected:
                              (value) =>
                                  controller.filter = filter.copyWith(
                                    onlyErrors: value,
                                  ),
                        ),
                        _FacetChip(
                          label: strings.pinnedOnly,
                          count: facets.pinned,
                          selected: filter.onlyPinned,
                          onSelected:
                              (value) =>
                                  controller.filter = filter.copyWith(
                                    onlyPinned: value,
                                  ),
                        ),
                      ],
                    ),
                    _Section(
                      title: strings.status,
                      children: [
                        ..._chips<PeekStatusClass>(
                          facet: facets.statusClasses,
                          selected: filter.statusClasses,
                          label: strings.statusClassName,
                          apply:
                              (values) =>
                                  controller.filter = filter.copyWith(
                                    statusClasses: values,
                                  ),
                        ),
                        ..._chips<int>(
                          facet: facets.statusCodes,
                          selected: filter.statusCodes,
                          label: (code) => '$code',
                          apply:
                              (values) =>
                                  controller.filter = filter.copyWith(
                                    statusCodes: values,
                                  ),
                        ),
                      ],
                    ),
                    _Section(
                      title: strings.method,
                      children: _chips<String>(
                        facet: facets.methods,
                        selected: filter.methods,
                        label: (method) => method,
                        apply:
                            (values) =>
                                controller.filter = filter.copyWith(
                                  methods: values,
                                ),
                      ),
                    ),
                    _Section(
                      title: strings.host,
                      children: _chips<String>(
                        facet: facets.hosts,
                        selected: filter.hosts,
                        label: (host) => host,
                        apply:
                            (values) =>
                                controller.filter = filter.copyWith(
                                  hosts: values,
                                ),
                      ),
                    ),
                    _Section(
                      title: strings.contentType,
                      children: _chips<String>(
                        facet: facets.contentTypes,
                        selected: filter.contentTypes,
                        label: (type) => type,
                        apply:
                            (values) =>
                                controller.filter = filter.copyWith(
                                  contentTypes: values,
                                ),
                      ),
                    ),
                    _Section(
                      title: strings.state,
                      children: _chips<PeekEntryState>(
                        facet: facets.states,
                        selected: filter.states,
                        label: strings.entryState,
                        apply:
                            (values) =>
                                controller.filter = filter.copyWith(
                                  states: values,
                                ),
                      ),
                    ),
                    _Section(
                      title: strings.source,
                      children: _chips<String>(
                        facet: facets.sources,
                        selected: filter.sources,
                        label: (source) => source,
                        apply:
                            (values) =>
                                controller.filter = filter.copyWith(
                                  sources: values,
                                ),
                      ),
                    ),
                    _Section(
                      title: strings.duration,
                      children: [
                        for (final range in _durations)
                          _FacetChip(
                            label: strings.durationFilter(range),
                            selected: filter.duration == range,
                            onSelected:
                                (_) =>
                                    controller.filter = filter.copyWith(
                                      duration: range,
                                    ),
                          ),
                      ],
                    ),
                    _Section(
                      title: strings.started,
                      children: _dateChips(controller, strings),
                    ),
                    SizedBox(height: theme.gutter),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _chips<T>({
    required Map<T, int> facet,
    required Set<T> selected,
    required String Function(T value) label,
    required void Function(Set<T> values) apply,
  }) => [
    for (final entry in facet.entries)
      _FacetChip(
        label: label(entry.key),
        count: entry.value,
        selected: selected.contains(entry.key),
        onSelected: (value) {
          final next = {...selected};
          value ? next.add(entry.key) : next.remove(entry.key);
          apply(next);
        },
      ),
  ];

  List<Widget> _dateChips(PeekController controller, PeekStrings strings) {
    final filter = controller.filter;
    // Whole minutes, so a window picked a moment ago still reads as the
    // same choice; an older one shows up as the cut-off it became.
    final now = controller.peek.options.clock.now();
    final base = now.subtract(
      Duration(
        seconds: now.second,
        milliseconds: now.millisecond,
        microseconds: now.microsecond,
      ),
    );
    final offered = [
      PeekDateRange.any,
      for (final window in _windows) PeekDateRange(from: base.subtract(window)),
    ];

    return [
      for (final (index, range) in offered.indexed)
        _FacetChip(
          label: index == 0 ? strings.any : strings.recent(_windows[index - 1]),
          selected: filter.dates == range,
          onSelected: (_) => controller.filter = filter.copyWith(dates: range),
        ),
      if (!filter.dates.isUnbounded && !offered.contains(filter.dates))
        _FacetChip(
          label: strings.dateFilter(filter.dates),
          selected: true,
          onSelected:
              (_) =>
                  controller.filter = filter.copyWith(dates: PeekDateRange.any),
        ),
    ];
  }
}

/// Opens [PeekFiltersSheet] over [context] as a modal sheet.
///
/// The scope is handed over explicitly: a modal route builds beside the
/// screen, not under it.
Future<void> showPeekFilters(BuildContext context) {
  final controller = PeekScope.read(context);
  final strings = PeekScope.stringsOf(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder:
        (context) => PeekScope(
          controller: controller,
          strings: strings,
          child: const PeekFiltersSheet(),
        ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.children, this.title});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final theme = PeekTheme.of(context);
    final title = this.title;

    return Padding(
      padding: EdgeInsets.only(top: theme.rowSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Text(
              title,
              style: theme.caption.copyWith(color: theme.secondaryLabel),
            ),
          Wrap(spacing: 6, children: children),
        ],
      ),
    );
  }
}

class _FacetChip extends StatelessWidget {
  const _FacetChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.count,
  });

  final String label;
  final int? count;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final count = this.count;

    return FilterChip(
      selected: selected,
      onSelected: onSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 5),
            Text(
              '$count',
              style: theme.caption.copyWith(color: theme.secondaryLabel),
            ),
          ],
        ],
      ),
    );
  }
}
