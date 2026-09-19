import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart' show Icons;
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

  /// Whether a screen is showing anywhere; `PeekOverlay` watches this to
  /// get out of its own way.
  static ValueListenable<bool> get isOpen => _isOpen;

  static final _OpenScreens _isOpen = _OpenScreens();

  @override
  State<PeekScreen> createState() => _PeekScreenState();
}

class _PeekScreenState extends State<PeekScreen> {
  PeekController? _owned;

  PeekController get _controller => widget.controller ?? _ensureOwned();

  PeekController _ensureOwned() =>
      _owned ??= PeekController(widget.peek ?? Peek.instance);

  @override
  void initState() {
    super.initState();
    PeekScreen._isOpen.enter();
  }

  @override
  void dispose() {
    PeekScreen._isOpen.leave();
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

/// How many [PeekScreen]s are on screen, as something to listen to.
///
/// The count is read live, so a listener is right even if it never hears
/// about a change; notification waits for a microtask because a screen
/// registers while the tree above it is building.
class _OpenScreens extends ChangeNotifier implements ValueListenable<bool> {
  int _count = 0;

  @override
  bool get value => _count > 0;

  void enter() {
    _count++;
    scheduleMicrotask(notifyListeners);
  }

  void leave() {
    _count--;
    scheduleMicrotask(notifyListeners);
  }
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
    final leading = _leading(context, strings);

    if (!wide) {
      return PeekSliverScaffold(
        title: strings.console,
        actions: actions,
        leading: leading,
        controller: _scroll,
        slivers: [
          SliverToBoxAdapter(child: _chrome(controller, strings)),
          PeekEntrySliver(
            onTap: (entry) {
              controller.select(entry.id);
              unawaited(showPeekEntry(context, entry.id));
            },
          ),
        ],
        // Clear of the navigation bar, which is pinned above it: the
        // collapsed bar is as tall as the buttons it holds.
        overlay: Positioned(
          top:
              MediaQuery.paddingOf(context).top +
              theme.minTapTarget +
              theme.rowSpacing,
          left: 0,
          right: 0,
          child: Center(child: PeekArrivalsBar(scrollController: _scroll)),
        ),
      );
    }

    return PeekScaffold(
      title: strings.console,
      actions: actions,
      leading: leading,
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

  /// The way out, when Peek was pushed over something.
  Widget? _leading(BuildContext context, PeekStrings strings) {
    final route = ModalRoute.of(context);
    if (route == null || !Navigator.of(context).canPop()) return null;
    final modal = route is PageRoute<Object?> && route.fullscreenDialog;
    return PeekIconButton(
      icon: modal ? Icons.close : Icons.arrow_back_ios_new,
      tooltip: modal ? strings.close : strings.back,
      size: modal ? 22 : 17,
      onPressed: () => Navigator.of(context).maybePop(),
    );
  }

  List<Widget> _actions(
    BuildContext context,
    PeekController controller,
    PeekStrings strings,
  ) {
    final paused = controller.isPaused;
    // The search has a field of its own, so it is not part of the badge.
    final filters =
        controller.filter.copyWith(query: PeekSearchQuery.none).activeCount;

    return [
      PeekIconButton(
        icon: Icons.filter_list,
        tooltip: strings.filters,
        badgeCount: filters,
        onPressed: () => unawaited(showPeekFilters(context)),
      ),
      PeekIconButton(
        icon: Icons.delete_outline,
        tooltip: strings.clear,
        onPressed:
            controller.totalCount == 0
                ? null
                : () => unawaited(_confirmClear(context, controller)),
      ),
      PeekIconButton(
        icon: Icons.pause,
        tooltip: paused ? strings.resume : strings.pause,
        selected: paused,
        onPressed: controller.togglePause,
      ),
      PeekIconButton(
        icon: Icons.more_horiz,
        tooltip: strings.more,
        onPressed:
            controller.entries.isEmpty
                ? null
                : () => unawaited(showPeekListActions(context)),
      ),
    ];
  }

  /// Everything above the list: what is paused, what is searched, and how
  /// much of the store is left showing.
  ///
  /// What is filtered is not repeated here — the filter button carries the
  /// count, and the sheet is where it is changed.
  Widget _chrome(PeekController controller, PeekStrings strings) {
    final theme = PeekTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PeekSearchBar(),
        const PeekQuickBar(),
        // Says so in words, whether the bar's button or the app paused it.
        if (controller.isPaused)
          _PausedBanner(strings: strings, onResume: controller.resume),
        if (controller.isFiltered)
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
        icon: Icons.touch_app_outlined,
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
  const _PausedBanner({required this.strings, required this.onResume});

  final PeekStrings strings;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        theme.gutter,
        theme.rowSpacing,
        theme.gutter,
        theme.rowSpacing,
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(theme.radius),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.accent.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.pause, size: 20, color: theme.accent),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(strings.pausedBanner, style: theme.headline)),
            const SizedBox(width: 12),
            PeekFilledButton(
              label: strings.resume,
              icon: Icons.play_arrow,
              onPressed: onResume,
            ),
          ],
        ),
      ),
    );
  }
}

