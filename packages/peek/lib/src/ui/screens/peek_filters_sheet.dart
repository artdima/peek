import 'dart:async';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../../core/model/peek_entry.dart';
import '../../core/model/peek_status_class.dart';
import '../../core/query/peek_facets.dart';
import '../../core/query/peek_filter.dart';
import '../icons/peek_icon.dart';
import '../icons/peek_icon_data.dart';
import '../icons/peek_icons.dart';
import '../peek_controller.dart';
import '../peek_scope.dart';
import '../peek_strings.dart';
import '../theme/peek_theme.dart';
import '../widgets/widgets.dart';

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

/// Every criterion the recorded calls offer, one row each.
///
/// A row says what it is narrowed to and opens a sheet of its own to
/// change it. Choices apply as they are made, so the list behind the sheet
/// follows along; the button at the foot says what is left and closes,
/// and closing any other way loses nothing.
final class PeekFiltersSheet extends StatelessWidget {
  /// Creates the panel.
  const PeekFiltersSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = PeekScope.of(context);
    final strings = PeekScope.stringsOf(context);
    final theme = PeekTheme.of(context);
    final filter = controller.filter;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(theme.gutter, 6, theme.gutter, 0),
          child: Row(
            children: [
              Expanded(child: Text(strings.filters, style: theme.headline)),
              PeekTextButton(
                label: strings.resetFilters,
                onPressed: filter.isEmpty ? null : controller.resetFilter,
              ),
            ],
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: theme.rowSpacing),
                PeekListSection(
                  children: [
                    for (final criterion in _criteria(controller, strings))
                      _CriterionRow(criterion),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            theme.gutter,
            0,
            theme.gutter,
            theme.rowSpacing,
          ),
          child: PeekFilledButton(
            // Nothing to narrow, nothing to report: it is just a way out.
            label:
                filter.isEmpty
                    ? strings.close
                    : strings.showRequests(controller.entries.length),
            expand: true,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      ],
    );
  }
}

/// Opens [PeekFiltersSheet] over [context] as a modal sheet.
Future<void> showPeekFilters(BuildContext context) => showPeekSheet<void>(
  context,
  builder: (context) => const PeekFiltersSheet(),
);

/// One criterion as the sheet shows it: what it is called, what it is
/// narrowed to, and how to change or drop it.
@immutable
class _Criterion {
  const _Criterion({
    required this.glyph,
    required this.title,
    required this.chosen,
    required this.onClear,
    required this.open,
  });

  final PeekIconData glyph;
  final String title;
  final List<String> chosen;
  final VoidCallback onClear;
  final Future<void> Function(BuildContext context) open;
}

List<_Criterion> _criteria(PeekController controller, PeekStrings strings) {
  final filter = controller.filter;

  return [
    _Criterion(
      glyph: PeekIcons.status,
      title: strings.status,
      chosen: [
        ...filter.statusClasses.map(strings.statusClassName),
        ...filter.statusCodes.map((code) => '$code'),
      ],
      onClear:
          () =>
              controller.filter = filter.copyWith(
                statusClasses: const {},
                statusCodes: const {},
              ),
      open:
          (context) => showPeekSheet<void>(
            context,
            builder: (context) => const _StatusSheet(),
          ),
    ),
    _Criterion(
      glyph: PeekIcons.method,
      title: strings.method,
      chosen: filter.methods.toList(),
      onClear: () => controller.filter = filter.copyWith(methods: const {}),
      open:
          (context) => _pickValues<String>(
            context,
            title: strings.method,
            values: (facets) => facets.methods,
            label: (method) => method,
            read: (filter) => filter.methods,
            write: (filter, values) => filter.copyWith(methods: values),
          ),
    ),
    _Criterion(
      glyph: PeekIcons.host,
      title: strings.host,
      chosen: filter.hosts.toList(),
      onClear: () => controller.filter = filter.copyWith(hosts: const {}),
      open:
          (context) => _pickValues<String>(
            context,
            title: strings.host,
            values: (facets) => facets.hosts,
            label: (host) => host,
            read: (filter) => filter.hosts,
            write: (filter, values) => filter.copyWith(hosts: values),
          ),
    ),
    _Criterion(
      glyph: PeekIcons.contentType,
      title: strings.contentType,
      chosen: filter.contentTypes.toList(),
      onClear:
          () => controller.filter = filter.copyWith(contentTypes: const {}),
      open:
          (context) => _pickValues<String>(
            context,
            title: strings.contentType,
            values: (facets) => facets.contentTypes,
            label: (type) => type,
            read: (filter) => filter.contentTypes,
            write: (filter, values) => filter.copyWith(contentTypes: values),
          ),
    ),
    _Criterion(
      glyph: PeekIcons.state,
      title: strings.state,
      chosen: filter.states.map(strings.entryState).toList(),
      onClear: () => controller.filter = filter.copyWith(states: const {}),
      open:
          (context) => _pickValues<PeekEntryState>(
            context,
            title: strings.state,
            values: (facets) => facets.states,
            label: strings.entryState,
            read: (filter) => filter.states,
            write: (filter, values) => filter.copyWith(states: values),
          ),
    ),
    _Criterion(
      glyph: PeekIcons.source,
      title: strings.source,
      chosen: filter.sources.toList(),
      onClear: () => controller.filter = filter.copyWith(sources: const {}),
      open:
          (context) => _pickValues<String>(
            context,
            title: strings.source,
            values: (facets) => facets.sources,
            label: (source) => source,
            read: (filter) => filter.sources,
            write: (filter, values) => filter.copyWith(sources: values),
          ),
    ),
    _Criterion(
      glyph: PeekIcons.duration,
      title: strings.duration,
      chosen:
          filter.duration.isUnbounded
              ? const []
              : [strings.durationFilter(filter.duration)],
      onClear:
          () =>
              controller.filter = filter.copyWith(
                duration: PeekDurationRange.any,
              ),
      open: _pickDuration,
    ),
    _Criterion(
      glyph: PeekIcons.timing,
      title: strings.started,
      chosen:
          filter.dates.isUnbounded
              ? const []
              : [strings.dateFilter(filter.dates)],
      onClear:
          () => controller.filter = filter.copyWith(dates: PeekDateRange.any),
      open: _pickStarted,
    ),
  ];
}

class _CriterionRow extends StatelessWidget {
  const _CriterionRow(this.criterion);

  final _Criterion criterion;

  @override
  Widget build(BuildContext context) {
    final strings = PeekScope.stringsOf(context);
    final theme = PeekTheme.of(context);
    final chosen = criterion.chosen;

    return PeekListRow(
      leading: PeekIcon(criterion.glyph, size: 22, color: theme.secondaryLabel),
      title: criterion.title,
      value: chosen.isEmpty ? strings.any : null,
      trailing:
          chosen.isEmpty
              ? null
              : _ChosenChip(
                label:
                    chosen.length == 1
                        ? chosen.single
                        : strings.moreValues(chosen.first, chosen.length - 1),
                onRemove: criterion.onClear,
              ),
      chevron: true,
      onTap: () => unawaited(criterion.open(context)),
    );
  }
}

/// What a criterion is narrowed to, and a cross that drops it.
class _ChosenChip extends StatelessWidget {
  const _ChosenChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final strings = PeekScope.stringsOf(context);
    final theme = PeekTheme.of(context);

    return PeekTappable(
      onTap: onRemove,
      fade: true,
      child: Semantics(
        button: true,
        label: strings.removeFilter(label),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: theme.minTapTarget),
          child: Center(
            widthFactor: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(theme.radius / 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConstrainedBox(
                    // A share of the width rather than a number, so a
                    // long value gives way on a narrow screen.
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.sizeOf(context).width * 0.4,
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.footnote.copyWith(
                        color: theme.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.close, size: 14, color: theme.accent),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Offers what [values] picks out of the facets, counted, and toggles
/// them in the live filter.
///
/// The facets are read as the sheet builds, not as it opens: a call
/// arriving while it is open brings its host along with it.
Future<void> _pickValues<T>(
  BuildContext context, {
  required String title,
  required Map<T, int> Function(PeekFacets facets) values,
  required String Function(T value) label,
  required Set<T> Function(PeekFilter filter) read,
  required PeekFilter Function(PeekFilter filter, Set<T> values) write,
}) => showPeekSheet<void>(
  context,
  builder:
      (context) => _FacetPicker<T>(
        title: title,
        values: values,
        label: label,
        read: read,
        write: write,
      ),
);

class _FacetPicker<T> extends StatelessWidget {
  const _FacetPicker({
    required this.title,
    required this.values,
    required this.label,
    required this.read,
    required this.write,
  });

  final String title;
  final Map<T, int> Function(PeekFacets facets) values;
  final String Function(T value) label;
  final Set<T> Function(PeekFilter filter) read;
  final PeekFilter Function(PeekFilter filter, Set<T> values) write;

  @override
  Widget build(BuildContext context) => _PickerSheet(
    title: title,
    children: [
      _FacetGroup<T>(
        values: values(PeekScope.of(context).facets),
        label: label,
        read: read,
        write: write,
      ),
    ],
  );
}

/// The status classes and the codes themselves, in one sheet.
class _StatusSheet extends StatelessWidget {
  const _StatusSheet();

  @override
  Widget build(BuildContext context) {
    final strings = PeekScope.stringsOf(context);
    final facets = PeekScope.of(context).facets;

    return _PickerSheet(
      title: strings.status,
      children: [
        _FacetGroup<PeekStatusClass>(
          title: strings.statusClass,
          values: facets.statusClasses,
          label: strings.statusClassName,
          read: (filter) => filter.statusClasses,
          write: (filter, values) => filter.copyWith(statusClasses: values),
        ),
        _FacetGroup<int>(
          title: strings.statusCode,
          values: facets.statusCodes,
          label: (code) => '$code',
          read: (filter) => filter.statusCodes,
          write: (filter, values) => filter.copyWith(statusCodes: values),
        ),
      ],
    );
  }
}

/// The frame every value picker wears: a name and what it offers.
class _PickerSheet extends StatelessWidget {
  const _PickerSheet({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            theme.gutter,
            6,
            theme.gutter,
            theme.gutter,
          ),
          child: Text(title, style: theme.headline),
        ),
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

/// One facet as rows that toggle: Any, then every value it holds.
class _FacetGroup<T> extends StatelessWidget {
  const _FacetGroup({
    required this.values,
    required this.label,
    required this.read,
    required this.write,
    this.title,
  });

  final String? title;
  final Map<T, int> values;
  final String Function(T value) label;
  final Set<T> Function(PeekFilter filter) read;
  final PeekFilter Function(PeekFilter filter, Set<T> values) write;

  @override
  Widget build(BuildContext context) {
    final controller = PeekScope.of(context);
    final strings = PeekScope.stringsOf(context);
    final selected = read(controller.filter);

    void toggle(T value) {
      final next = {...selected};
      next.contains(value) ? next.remove(value) : next.add(value);
      controller.filter = write(controller.filter, next);
    }

    return PeekListSection(
      title: title,
      children: [
        _PickerRow(
          label: strings.any,
          selected: selected.isEmpty,
          onTap: () => controller.filter = write(controller.filter, const {}),
        ),
        for (final value in values.entries)
          _PickerRow(
            label: label(value.key),
            count: value.value,
            selected: selected.contains(value.key),
            onTap: () => toggle(value.key),
          ),
      ],
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final count = this.count;

    return PeekListRow(
      title: label,
      value: count == null ? null : '$count',
      trailing:
          selected ? Icon(Icons.check, size: 18, color: theme.accent) : null,
      onTap: onTap,
    );
  }
}

/// Picks one duration range; the list follows at once.
Future<void> _pickDuration(BuildContext context) async {
  final controller = PeekScope.read(context);
  final strings = PeekScope.stringsOf(context);
  final picked = await showPeekActions<PeekDurationRange>(
    context,
    title: strings.duration,
    actions: [
      for (final range in _durations)
        PeekAction(
          value: range,
          label: strings.durationFilter(range),
          selected: controller.filter.duration == range,
        ),
    ],
  );
  if (picked == null) return;
  controller.filter = controller.filter.copyWith(duration: picked);
}

/// Picks one window to look back over.
Future<void> _pickStarted(BuildContext context) async {
  final controller = PeekScope.read(context);
  final strings = PeekScope.stringsOf(context);
  final filter = controller.filter;
  // Whole minutes, so a window picked a moment ago still reads as the same
  // choice; an older one shows up as the cut-off it became.
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

  final picked = await showPeekActions<PeekDateRange>(
    context,
    title: strings.started,
    actions: [
      for (final (index, range) in offered.indexed)
        PeekAction(
          value: range,
          label: index == 0 ? strings.any : strings.recent(_windows[index - 1]),
          selected: filter.dates == range,
        ),
      if (!filter.dates.isUnbounded && !offered.contains(filter.dates))
        PeekAction(
          value: filter.dates,
          label: strings.dateFilter(filter.dates),
          selected: true,
        ),
    ],
  );
  if (picked == null) return;
  controller.filter = controller.filter.copyWith(dates: picked);
}
