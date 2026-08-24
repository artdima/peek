import 'dart:async';

import 'package:flutter/material.dart' show Icons, MaterialPageRoute;
import 'package:flutter/widgets.dart';

import '../../core/model/peek_body.dart';
import '../../core/model/peek_id.dart';
import '../peek_scope.dart';
import '../theme/peek_theme.dart';
import '../widgets/widgets.dart';
import 'peek_entry_view.dart';

/// One call as a screen of its own, for layouts too narrow for a pane.
///
/// It holds the call's id rather than the call, so a request that finishes
/// while it is open fills itself in, and one that is cleared says so.
final class PeekEntryScreen extends StatelessWidget {
  /// Creates the screen for the call with [id].
  const PeekEntryScreen(this.id, {super.key});

  /// Which call to show.
  final PeekId id;

  @override
  Widget build(BuildContext context) {
    final controller = PeekScope.of(context);
    final strings = PeekScope.stringsOf(context);
    final theme = PeekTheme.of(context);
    final entry = controller.peek.store.find(id);

    return PeekScaffold(
      title: entry == null ? strings.request : entry.request.path,
      titleStyle: PeekTitleStyle.inline,
      background: theme.groupedBackground,
      leading: PeekIconButton(
        icon: Icons.arrow_back_ios_new,
        tooltip: strings.back,
        size: 17,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      actions: [
        if (entry != null)
          PeekIconButton(
            icon: Icons.more_horiz,
            tooltip: strings.more,
            onPressed: () => unawaited(showPeekEntryActions(context, entry)),
          ),
      ],
      child:
          entry == null
              ? PeekEmptyState(
                title: strings.removedEntry,
                message: strings.removedEntryHint,
                icon: Icons.delete_outline,
              )
              : PeekEntryView(entry),
    );
  }
}

/// Pushes what [builder] draws over [context], as a screen titled [title].
///
/// One part of a call at a time — a body, a table of headers — read on a
/// screen of its own rather than by moving the screen behind to another
/// tab, which loses the reader's place.
///
/// The scope is handed over explicitly: a route builds beside the screen
/// that pushed it, not under it.
Future<void> showPeekDetail(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
}) {
  final controller = PeekScope.read(context);
  final strings = PeekScope.stringsOf(context);
  final share = PeekScope.shareOf(context);
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder:
          (context) => PeekScope(
            controller: controller,
            strings: strings,
            share: share,
            child: _PeekDetailScreen(title: title, builder: builder),
          ),
    ),
  );
}

/// Pushes [body] over [context], titled [title].
Future<void> showPeekBody(
  BuildContext context, {
  required PeekBody body,
  required String title,
}) => showPeekDetail(
  context,
  title: title,
  builder: (context) => PeekBodyView(body),
);

class _PeekDetailScreen extends StatelessWidget {
  const _PeekDetailScreen({required this.title, required this.builder});

  final String title;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final strings = PeekScope.stringsOf(context);
    final theme = PeekTheme.of(context);

    return PeekScaffold(
      title: title,
      titleStyle: PeekTitleStyle.inline,
      background: theme.groupedBackground,
      leading: PeekIconButton(
        icon: Icons.arrow_back_ios_new,
        tooltip: strings.back,
        size: 17,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      child: Builder(builder: builder),
    );
  }
}

/// Pushes [PeekEntryScreen] for [id] over [context].
///
/// The scope is handed over explicitly: a route builds beside the screen
/// that pushed it, not under it.
Future<void> showPeekEntry(BuildContext context, PeekId id) {
  final controller = PeekScope.read(context);
  final strings = PeekScope.stringsOf(context);
  final share = PeekScope.shareOf(context);
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder:
          (context) => PeekScope(
            controller: controller,
            strings: strings,
            share: share,
            child: PeekEntryScreen(id),
          ),
    ),
  );
}
