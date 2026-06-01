import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart' show MaterialPageRoute;
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
        icon: CupertinoIcons.back,
        tooltip: strings.back,
        size: 17,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      actions: [
        if (entry != null)
          PeekIconButton(
            icon: CupertinoIcons.ellipsis,
            tooltip: strings.more,
            onPressed: () => unawaited(showPeekEntryActions(context, entry)),
          ),
      ],
      child:
          entry == null
              ? PeekEmptyState(
                title: strings.removedEntry,
                message: strings.removedEntryHint,
                icon: CupertinoIcons.trash,
              )
              : PeekEntryView(entry),
    );
  }
}

/// Pushes [body] over [context], titled [title].
Future<void> showPeekBody(
  BuildContext context, {
  required PeekBody body,
  required String title,
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
            child: _PeekBodyScreen(body: body, title: title),
          ),
    ),
  );
}

class _PeekBodyScreen extends StatelessWidget {
  const _PeekBodyScreen({required this.body, required this.title});

  final PeekBody body;
  final String title;

  @override
  Widget build(BuildContext context) {
    final strings = PeekScope.stringsOf(context);
    final theme = PeekTheme.of(context);

    return PeekScaffold(
      title: title,
      titleStyle: PeekTitleStyle.inline,
      background: theme.groupedBackground,
      leading: PeekIconButton(
        icon: CupertinoIcons.back,
        tooltip: strings.back,
        size: 17,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      child: PeekBodyView(body),
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
