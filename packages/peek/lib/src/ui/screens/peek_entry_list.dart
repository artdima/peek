import 'dart:async';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../../core/model/peek_entry.dart';
import '../../core/model/peek_id.dart';
import '../../core/query/peek_search_query.dart';
import '../peek_scope.dart';
import '../theme/peek_theme.dart';
import '../widgets/widgets.dart';

/// The calls as slivers, for a screen that owns the scrolling.
///
/// New calls arrive at the top. While the list is scrolled away from the
/// top it stays put and pins a bar saying how many arrived, so reading an
/// entry is not interrupted by the list moving under the finger.
final class PeekEntrySliver extends StatefulWidget {
  /// Creates the slivers.
  const PeekEntrySliver({
    required this.scrollController,
    this.onTap,
    this.selectedId,
    super.key,
  });

  /// The position the list is scrolled to.
  final ScrollController scrollController;

  /// Called when a row is tapped.
  final void Function(PeekEntry entry)? onTap;

  /// Which row is open in the detail pane, if any.
  final PeekId? selectedId;

  @override
  State<PeekEntrySliver> createState() => _PeekEntrySliverState();
}

class _PeekEntrySliverState extends State<PeekEntrySliver> {
  int _pendingAbove = 0;
  PeekId? _topId;

  @override
  Widget build(BuildContext context) {
    final controller = PeekScope.of(context);
    final strings = PeekScope.stringsOf(context);
    final entries = controller.entries;
    final search = controller.filter.query;
    final highlight =
        search.scopes.contains(PeekSearchScope.url) ? search.text : '';

    _trackArrivals(entries);

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

    return SliverMainAxisGroup(
      slivers: [
        if (_pendingAbove > 0)
          SliverPersistentHeader(
            pinned: true,
            delegate: _ArrivalsHeader(
              count: _pendingAbove,
              onPressed: _jumpToTop,
            ),
          ),
        SliverList.separated(
          itemCount: entries.length,
          separatorBuilder: (context, index) => const PeekSeparator(),
          itemBuilder: (context, index) {
            final entry = entries[index];
            return PeekEntryTile(
              entry,
              key: ValueKey(entry.id),
              selected: entry.id == widget.selectedId,
              highlight: highlight,
              onTap: widget.onTap == null ? null : () => widget.onTap!(entry),
            );
          },
        ),
      ],
    );
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
  Widget build(BuildContext context) => CustomScrollView(
    controller: _scroll,
    slivers: [
      PeekEntrySliver(
        scrollController: _scroll,
        onTap: widget.onTap,
        selectedId: widget.selectedId,
      ),
    ],
  );
}

/// The bar that says how many calls arrived above where you are reading.
class _ArrivalsHeader extends SliverPersistentHeaderDelegate {
  const _ArrivalsHeader({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  double get minExtent => 56;

  @override
  double get maxExtent => 56;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final theme = PeekTheme.of(context);
    return ColoredBox(
      color: theme.background,
      child: Center(
        child: _NewRequestsButton(count: count, onPressed: onPressed),
      ),
    );
  }

  @override
  bool shouldRebuild(_ArrivalsHeader oldDelegate) =>
      oldDelegate.count != count || oldDelegate.onPressed != onPressed;
}

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
