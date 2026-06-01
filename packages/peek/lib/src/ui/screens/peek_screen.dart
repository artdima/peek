import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/widgets.dart';

import '../../core/peek.dart';
import '../../core/query/peek_search_query.dart';
import '../peek_controller.dart';
import '../peek_scope.dart';
import '../peek_share.dart';
import '../peek_strings.dart';
import '../theme/peek_theme.dart';
import '../widgets/widgets.dart';
import 'peek_entry_list.dart';
import 'peek_entry_screen.dart';
import 'peek_entry_view.dart';
import 'peek_filters_sheet.dart';

/// The screen listing the calls Peek has recorded.
///
/// Give it a [peek] instance, or let it use [Peek.instance]:
///
/// ```dart
/// Navigator.of(context).push(
///   MaterialPageRoute<void>(builder: (_) => const PeekScreen()),
/// );
/// ```
final class PeekScreen extends StatefulWidget {
  /// Creates the screen over [peek], showing [strings].
  const PeekScreen({
    this.peek,
    this.strings = const PeekStrings(),
    this.controller,
    this.share,
    super.key,
  });

  /// Which instance to show; [Peek.instance] when omitted.
  final Peek? peek;

  /// The words to show.
  final PeekStrings strings;

  /// A controller to use instead of one created here.
  final PeekController? controller;

  /// What hands an export to the platform; without one, Peek offers
  /// copying and nothing else.
  final PeekShareDelegate? share;

  /// The width from which the list and the call sit side by side.
  static const double wideLayout = 720;

  @override
  State<PeekScreen> createState() => _PeekScreenState();
}

class _PeekScreenState extends State<PeekScreen> {
  PeekController? _owned;

  PeekController get _controller => widget.controller ?? _ensureOwned();

  PeekController _ensureOwned() =>
      _owned ??= PeekController(widget.peek ?? Peek.instance);

  @override
  void dispose() {
    _owned?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PeekScope(
    controller: _controller,
    strings: widget.strings,
    share: widget.share,
    child: const _PeekScaffold(),
  );
}

/// How much of a wide layout the list keeps for itself.
const double _listPaneWidth = 360;

class _PeekScaffold extends StatefulWidget {
  const _PeekScaffold();

  @override
  State<_PeekScaffold> createState() => _PeekScaffoldState();
}

class _PeekScaffoldState extends State<_PeekScaffold> {
  final ScrollController _scroll = ScrollController();

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
    final wide = MediaQuery.sizeOf(context).width >= PeekScreen.wideLayout;
    final actions = _actions(context, controller, strings);

    if (!wide) {
      return PeekSliverScaffold(
        title: strings.requests,
        actions: actions,
        controller: _scroll,
        slivers: [
          SliverToBoxAdapter(child: _chrome(controller, strings)),
          PeekEntrySliver(
            scrollController: _scroll,
            onTap: (entry) {
              controller.select(entry.id);
              unawaited(showPeekEntry(context, entry.id));
            },
          ),
        ],
      );
    }

    return PeekScaffold(
      title: strings.requests,
      actions: actions,
      child: Row(
        children: [
          SizedBox(
            width: _listPaneWidth,
            child: Column(
              children: [
                _chrome(controller, strings),
                Expanded(
                  child: PeekEntryList(
                    selectedId: controller.selectedId,
                    onTap: (entry) => controller.select(entry.id),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: theme.hairline,
            child: ColoredBox(
              color: theme.separator,
              child: const SizedBox(height: double.infinity),
            ),
          ),
          Expanded(child: _detail(controller, strings)),
        ],
      ),
    );
  }

  List<Widget> _actions(
    BuildContext context,
    PeekController controller,
    PeekStrings strings,
  ) {
    // The search has a field of its own, so it is not part of the badge.
    final filters =
        controller.filter.copyWith(query: PeekSearchQuery.none).activeCount;

    return [
      PeekIconButton(
        icon: CupertinoIcons.slider_horizontal_3,
        tooltip: strings.filters,
        badgeCount: filters,
        onPressed: () => unawaited(showPeekFilters(context)),
      ),
      PeekIconButton(
        icon:
            controller.isPaused
                ? CupertinoIcons.play_fill
                : CupertinoIcons.pause_fill,
        tooltip: controller.isPaused ? strings.resume : strings.pause,
        onPressed: controller.togglePause,
      ),
      PeekIconButton(
        icon: CupertinoIcons.trash,
        tooltip: strings.clear,
        onPressed:
            controller.totalCount == 0
                ? null
                : () => unawaited(_confirmClear(context, controller)),
      ),
      PeekIconButton(
        icon: CupertinoIcons.ellipsis,
        tooltip: strings.more,
        onPressed:
            controller.entries.isEmpty
                ? null
                : () => unawaited(showPeekListActions(context)),
      ),
    ];
  }

  /// Everything above the list: what is paused, searched and filtered.
  /// Everything above the list: what is paused, searched, filtered, and
  /// how much of the store is left showing.
  Widget _chrome(PeekController controller, PeekStrings strings) {
    final theme = PeekTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (controller.isPaused) _PausedBanner(strings: strings),
        const PeekSearchBar(),
        const PeekQuickBar(),
        const PeekActiveFilters(),
        Padding(
          padding: EdgeInsets.fromLTRB(theme.gutter, 0, theme.gutter, 6),
          child: Text(
            strings.requestCount(
              controller.entries.length,
              controller.totalCount,
            ),
            style: theme.caption.copyWith(color: theme.secondaryLabel),
          ),
        ),
      ],
    );
  }

  Widget _detail(PeekController controller, PeekStrings strings) {
    final entry = controller.selected;
    if (entry == null) {
      return PeekEmptyState(
        title: strings.noSelection,
        message: strings.noSelectionHint,
        icon: CupertinoIcons.hand_point_right,
      );
    }
    return PeekEntryView(entry, key: ValueKey(entry.id));
  }

  Future<void> _confirmClear(
    BuildContext context,
    PeekController controller,
  ) async {
    final strings = PeekScope.stringsOf(context);
    final confirmed = await showPeekAlert(
      context,
      title: strings.clearTitle,
      message: strings.clearMessage,
      confirmLabel: strings.confirm,
    );
    if (confirmed) controller.clear();
  }
}

class _PausedBanner extends StatelessWidget {
  const _PausedBanner({required this.strings});

  final PeekStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    return Container(
      width: double.infinity,
      color: theme.pending.withValues(alpha: 0.16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(CupertinoIcons.pause_circle, size: 14, color: theme.pending),
          const SizedBox(width: 8),
          Text(
            strings.pausedBanner,
            style: theme.caption.copyWith(color: theme.pending),
          ),
        ],
      ),
    );
  }
}
