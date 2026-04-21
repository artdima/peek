import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/model/peek_entry.dart';
import '../../core/model/peek_id.dart';
import '../../core/query/peek_search_query.dart';
import '../peek_scope.dart';
import '../theme/peek_theme.dart';
import '../widgets/widgets.dart';

/// The scrolling list of calls, with its two empty states.
///
/// New calls arrive at the top. While the list is scrolled away from the
/// top it stays put and offers a button saying how many arrived, so reading
/// an entry is not interrupted by the list moving under the finger.
final class PeekEntryList extends StatefulWidget {
  /// Creates the list.
  const PeekEntryList({
    this.onTap,
    this.onAction,
    this.selectedId,
    this.showShare = false,
    super.key,
  });

  /// Called when a row is tapped.
  final void Function(PeekEntry entry)? onTap;

  /// Called when a row's menu picks an action.
  final void Function(PeekEntry entry, PeekTileAction action)? onAction;

  /// Which row is open in the detail pane, if any.
  final PeekId? selectedId;

  /// Whether row menus offer sharing.
  final bool showShare;

  @override
  State<PeekEntryList> createState() => _PeekEntryListState();
}

class _PeekEntryListState extends State<PeekEntryList> {
  final ScrollController _scroll = ScrollController();
  int _pendingAbove = 0;
  PeekId? _topId;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = PeekScope.of(context);
    final strings = PeekScope.stringsOf(context);
    final theme = PeekTheme.of(context);
    final entries = controller.entries;
    final search = controller.filter.query;
    final highlight =
        search.scopes.contains(PeekSearchScope.url) ? search.text : '';

    _trackArrivals(entries);

    if (entries.isEmpty) {
      return controller.isFiltered
          ? PeekEmptyState(
            title: strings.noMatches,
            message: strings.noMatchesHint,
            icon: Icons.search_off_outlined,
            action: TextButton(
              onPressed: controller.resetFilter,
              child: Text(strings.resetFilters),
            ),
          )
          : PeekEmptyState(
            title: strings.noRequests,
            message: strings.noRequestsHint,
          );
    }

    return Stack(
      children: [
        ListView.separated(
          controller: _scroll,
          itemCount: entries.length,
          separatorBuilder: (context, index) => const PeekSeparator(),
          itemBuilder: (context, index) {
            final entry = entries[index];
            return PeekEntryTile(
              entry,
              key: ValueKey(entry.id),
              selected: entry.id == widget.selectedId,
              showShare: widget.showShare,
              highlight: highlight,
              onTap: widget.onTap == null ? null : () => widget.onTap!(entry),
              onAction:
                  widget.onAction == null
                      ? null
                      : (action) => widget.onAction!(entry, action),
            );
          },
        ),
        if (_pendingAbove > 0)
          Positioned(
            top: theme.rowSpacing,
            left: 0,
            right: 0,
            child: Center(
              child: _NewRequestsButton(
                count: _pendingAbove,
                onPressed: _jumpToTop,
              ),
            ),
          ),
      ],
    );
  }

  /// Counts what arrived above the viewport while it was scrolled away.
  void _trackArrivals(List<PeekEntry> entries) {
    final topId = entries.isEmpty ? null : entries.first.id;
    if (topId == _topId) return;

    final atTop = !_scroll.hasClients || _scroll.offset <= 8;
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
    if (_scroll.hasClients) {
      unawaited(
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        ),
      );
    }
  }
}

class _NewRequestsButton extends StatelessWidget {
  const _NewRequestsButton({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final strings = PeekScope.stringsOf(context);
    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(20),
      color: PeekTheme.of(context).accent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.arrow_upward,
                size: 14,
                color: Color(0xFFFFFFFF),
              ),
              const SizedBox(width: 6),
              Text(
                strings.newRequests(count),
                style: PeekTheme.of(
                  context,
                ).footnote.copyWith(color: const Color(0xFFFFFFFF)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
