import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/export/peek_exporters.dart';
import '../../core/model/peek_entry.dart';
import '../../core/peek.dart';
import '../../core/query/peek_search_query.dart';
import '../peek_controller.dart';
import '../peek_scope.dart';
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
    super.key,
  });

  /// Which instance to show; [Peek.instance] when omitted.
  final Peek? peek;

  /// The words to show.
  final PeekStrings strings;

  /// A controller to use instead of one created here.
  final PeekController? controller;

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
    child: const _PeekScaffold(),
  );
}

/// How much of a wide layout the list keeps for itself.
const double _listPaneWidth = 360;

class _PeekScaffold extends StatelessWidget {
  const _PeekScaffold();

  @override
  Widget build(BuildContext context) {
    final controller = PeekScope.of(context);
    final strings = PeekScope.stringsOf(context);
    final theme = PeekTheme.of(context);

    return Scaffold(
      backgroundColor: theme.background,
      appBar: AppBar(
        backgroundColor: theme.background,
        surfaceTintColor: Colors.transparent,
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(strings.requests, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                strings.requestCount(
                  controller.entries.length,
                  controller.totalCount,
                ),
                overflow: TextOverflow.ellipsis,
                style: theme.footnote.copyWith(
                  height: 1,
                  color: theme.secondaryLabel,
                ),
              ),
            ),
          ],
        ),
        actions: [
          _FiltersButton(strings: strings),
          IconButton(
            onPressed: controller.togglePause,
            icon: Icon(controller.isPaused ? Icons.play_arrow : Icons.pause),
            tooltip: controller.isPaused ? strings.resume : strings.pause,
          ),
          IconButton(
            onPressed:
                controller.totalCount == 0
                    ? null
                    : () => _confirmClear(context, controller, strings),
            icon: const Icon(Icons.delete_outline),
            tooltip: strings.clear,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= PeekScreen.wideLayout;
          final list = _list(context, controller, strings, wide: wide);
          if (!wide) return list;

          return Row(
            children: [
              SizedBox(width: _listPaneWidth, child: list),
              VerticalDivider(width: 1, thickness: 1, color: theme.separator),
              Expanded(child: _detail(controller, strings)),
            ],
          );
        },
      ),
    );
  }

  Widget _list(
    BuildContext context,
    PeekController controller,
    PeekStrings strings, {
    required bool wide,
  }) => Column(
    children: [
      if (controller.isPaused) _PausedBanner(strings: strings),
      const PeekSearchBar(),
      const PeekQuickBar(),
      const PeekActiveFilters(),
      Expanded(
        child: PeekEntryList(
          selectedId: wide ? controller.selectedId : null,
          onTap: (entry) {
            controller.select(entry.id);
            if (!wide) unawaited(showPeekEntry(context, entry.id));
          },
          onAction:
              (entry, action) =>
                  _handleAction(context, controller, strings, entry, action),
        ),
      ),
    ],
  );

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
    PeekStrings strings,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(strings.clearTitle),
            content: Text(strings.clearMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(strings.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(strings.confirm),
              ),
            ],
          ),
    );
    if (confirmed ?? false) controller.clear();
  }

  Future<void> _handleAction(
    BuildContext context,
    PeekController controller,
    PeekStrings strings,
    PeekEntry entry,
    PeekTileAction action,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    switch (action) {
      case PeekTileAction.pin:
        final pinned = controller.togglePin(entry.id);
        if (!pinned && !entry.isPinned) {
          messenger?.showSnackBar(
            SnackBar(content: Text(strings.pinLimitReached)),
          );
        }
      case PeekTileAction.copyUrl:
        await _copy(messenger, strings, PeekExporters.url(entry));
      case PeekTileAction.copyCurl:
        await _copy(messenger, strings, PeekExporters.curl.export(entry));
      case PeekTileAction.share:
        break;
    }
  }

  Future<void> _copy(
    ScaffoldMessengerState? messenger,
    PeekStrings strings,
    String text,
  ) async {
    await Clipboard.setData(ClipboardData(text: text));
    messenger?.showSnackBar(
      SnackBar(
        content: Text(strings.copied),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _FiltersButton extends StatelessWidget {
  const _FiltersButton({required this.strings});

  final PeekStrings strings;

  @override
  Widget build(BuildContext context) {
    // The search has a field of its own, so it is not part of the badge.
    final count =
        PeekScope.of(
          context,
        ).filter.copyWith(query: PeekSearchQuery.none).activeCount;

    return IconButton(
      onPressed: () => showPeekFilters(context),
      tooltip: strings.filters,
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.filter_list),
      ),
    );
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
          Icon(Icons.pause_circle_outline, size: 14, color: theme.pending),
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
