import 'dart:async';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../../core/model/peek_entry.dart';
import '../../core/model/peek_id.dart';
import '../../core/query/peek_search_query.dart';
import '../peek_scope.dart';
import '../theme/peek_theme.dart';
import '../widgets/widgets.dart';

/// The calls as a sliver, for a screen that owns the scrolling.
///
/// What arrived while the list was scrolled away is [PeekArrivalsBar]'s to
/// say: it is drawn over the list, not in it.
final class PeekEntrySliver extends StatelessWidget {
  /// Creates the sliver.
  const PeekEntrySliver({this.onTap, this.selectedId, super.key});

  /// Called when a row is tapped.
  final void Function(PeekEntry entry)? onTap;

  /// Which row is open in the detail pane, if any.
  final PeekId? selectedId;

  @override
  Widget build(BuildContext context) {
    final controller = PeekScope.of(context);
    final strings = PeekScope.stringsOf(context);
    final entries = controller.entries;
    final search = controller.filter.query;
    final highlight =
        search.scopes.contains(PeekSearchScope.url) ? search.text : '';

    if (entries.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child:
            controller.isFiltered
                ? PeekEmptyState(
                  title: strings.noMatches,
                  message: strings.noMatchesHint,
                  icon: Icons.search_off_outlined,
                  action: PeekTextButton(
                    label: strings.resetFilters,
                    onPressed: controller.resetFilter,
                  ),
                )
                : PeekEmptyState(
                  title: strings.noRequests,
                  message: strings.noRequestsHint,
                ),
      );
    }

    return SliverList.separated(
      itemCount: entries.length,
      separatorBuilder:
          (context, index) => PeekSeparator(
            indent: PeekEntryTile.textInset,
            endIndent: PeekTheme.of(context).gutter,
          ),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return PeekEntryTile(
          entry,
          key: ValueKey(entry.id),
          selected: entry.id == selectedId,
          highlight: highlight,
          onTap: onTap == null ? null : () => onTap!(entry),
        );
      },
    );
  }
}

/// Says how many calls arrived above the list while it was scrolled away,
/// and takes the reader back to them.
///
/// Drawn over the list rather than in it: a bar pinned inside the scroll
/// view ends up under whatever the screen pins above it.
final class PeekArrivalsBar extends StatefulWidget {
  /// Creates the bar over the list at [scrollController].
  const PeekArrivalsBar({required this.scrollController, super.key});

  /// The position the list is scrolled to.
  final ScrollController scrollController;

  @override
  State<PeekArrivalsBar> createState() => _PeekArrivalsBarState();
}

class _PeekArrivalsBarState extends State<PeekArrivalsBar> {
  int _pendingAbove = 0;
  PeekId? _topId;

  @override
  Widget build(BuildContext context) {
    _trackArrivals(PeekScope.of(context).entries);
    if (_pendingAbove == 0) return const SizedBox.shrink();
    return _NewRequestsButton(count: _pendingAbove, onPressed: _jumpToTop);
  }

  /// Counts what arrived above the viewport while it was scrolled away.
  void _trackArrivals(List<PeekEntry> entries) {
    final topId = entries.isEmpty ? null : entries.first.id;
    if (topId == _topId) return;

    final scroll = widget.scrollController;
    final atTop = !scroll.hasClients || scroll.offset <= 8;
    if (atTop) {
      _pendingAbove = 0;
    } else {
      final previousTop = _topId;
      final index =
          previousTop == null
              ? -1
              : entries.indexWhere((entry) => entry.id == previousTop);
      _pendingAbove += index < 0 ? 1 : index;
    }
    _topId = topId;
  }

  void _jumpToTop() {
    setState(() => _pendingAbove = 0);
    final scroll = widget.scrollController;
    if (scroll.hasClients) {
      unawaited(
        scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        ),
      );
    }
  }
}

/// The scrolling list of calls, for a caller that wants a plain box.
final class PeekEntryList extends StatefulWidget {
  /// Creates the list.
  const PeekEntryList({this.onTap, this.selectedId, super.key});

  /// Called when a row is tapped.
  final void Function(PeekEntry entry)? onTap;

  /// Which row is open in the detail pane, if any.
  final PeekId? selectedId;

  @override
  State<PeekEntryList> createState() => _PeekEntryListState();
}

class _PeekEntryListState extends State<PeekEntryList> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      CustomScrollView(
        controller: _scroll,
        slivers: [
          PeekEntrySliver(onTap: widget.onTap, selectedId: widget.selectedId),
        ],
      ),
      Positioned(
        top: PeekTheme.of(context).rowSpacing,
        left: 0,
        right: 0,
        child: Center(child: PeekArrivalsBar(scrollController: _scroll)),
      ),
    ],
  );
}

/// The bar that says how many calls arrived above where you are reading.
class _NewRequestsButton extends StatelessWidget {
  const _NewRequestsButton({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final strings = PeekScope.stringsOf(context);
    final theme = PeekTheme.of(context);
    const onAccent = Color(0xFFFFFFFF);

    return PeekTappable(
      onTap: onPressed,
      fade: true,
      focusRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: theme.minTapTarget,
        child: Align(
          widthFactor: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: theme.accent,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: theme.label.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.arrow_upward, size: 14, color: onAccent),
                const SizedBox(width: 6),
                Text(
                  strings.newRequests(count),
                  style: theme.footnote.copyWith(color: onAccent),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
