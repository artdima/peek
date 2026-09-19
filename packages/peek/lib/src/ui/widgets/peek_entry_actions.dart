import 'package:flutter/widgets.dart';

import '../../core/export/peek_exporters.dart';
import '../../core/model/peek_entry.dart';
import '../icons/peek_icons.dart';
import '../peek_scope.dart';
import '../peek_share.dart';
import '../theme/peek_theme.dart';
import 'peek_copy_button.dart';
import 'peek_method_badge.dart';
import 'peek_sheet.dart';
import 'peek_toast.dart';

/// What a call's menu can do.
enum PeekEntryAction {
  /// Pin the call, or let it go.
  pin,

  /// Copy the URL.
  copyUrl,

  /// Copy a curl command that replays the call.
  copyCurl,

  /// Copy a plain-text summary.
  copyText,

  /// Copy a Markdown summary.
  copyMarkdown,

  /// Copy an HTTP Archive of this one call.
  copyHar,

  /// Hand an HTTP Archive of this one call to the platform.
  shareHar,
}

/// Offers what can be done with [entry], and does it.
///
/// Sharing appears where something can carry it off — the app's
/// [PeekShareDelegate], or the browser on the web: an option that cannot
/// work is worse than no option.
Future<void> showPeekEntryActions(
  BuildContext context,
  PeekEntry entry, {
  bool includePin = true,
}) async {
  final controller = PeekScope.read(context);
  final strings = PeekScope.stringsOf(context);
  final share = PeekScope.shareOf(context);
  // Measured before the sheet opens: by the time it closes, the widget
  // that was tapped may have scrolled or gone.
  final origin = peekShareOrigin(context);

  final action = await showPeekActions<PeekEntryAction>(
    context,
    header: _EntryHeader(entry),
    actions: [
      PeekAction(
        value: PeekEntryAction.copyUrl,
        label: strings.copyUrl,
        icon: PeekIcons.link,
        section: strings.copy,
      ),
      PeekAction(
        value: PeekEntryAction.copyCurl,
        label: strings.copyCurl,
        icon: PeekIcons.curl,
        section: strings.copy,
      ),
      PeekAction(
        value: PeekEntryAction.copyText,
        label: strings.copyText,
        icon: PeekIcons.text,
        section: strings.copy,
      ),
      PeekAction(
        value: PeekEntryAction.copyMarkdown,
        label: strings.copyMarkdown,
        icon: PeekIcons.markdown,
        section: strings.copy,
      ),
      PeekAction(
        value: PeekEntryAction.copyHar,
        label: strings.exportHar,
        icon: PeekIcons.braces,
        section: strings.copy,
      ),
      if (share != null)
        PeekAction(
          value: PeekEntryAction.shareHar,
          label: strings.shareHar,
          icon: PeekIcons.share,
          section: strings.share,
        ),
      if (includePin)
        PeekAction(
          value: PeekEntryAction.pin,
          label: entry.isPinned ? strings.unpin : strings.pin,
          icon: PeekIcons.pin,
        ),
    ],
  );
  if (action == null || !context.mounted) return;

  switch (action) {
    case PeekEntryAction.pin:
      final pinned = controller.togglePin(entry.id);
      if (!pinned && !entry.isPinned) {
        showPeekToast(context, strings.pinLimitReached);
      }
    case PeekEntryAction.copyUrl:
      await peekCopy(context, PeekExporters.url(entry));
    case PeekEntryAction.copyCurl:
      await peekCopy(context, PeekExporters.curl.export(entry));
    case PeekEntryAction.copyText:
      await peekCopy(context, PeekExporters.text.export(entry));
    case PeekEntryAction.copyMarkdown:
      await peekCopy(context, PeekExporters.markdown.export(entry));
    case PeekEntryAction.copyHar:
      await peekCopy(context, PeekExporters.har.export([entry], pretty: true));
    case PeekEntryAction.shareHar:
      await share?.share(
        peekHarContent([entry], entry.request.host, origin: origin),
      );
  }
}

/// Offers what can be done with the list as it stands, and does it.
Future<void> showPeekListActions(BuildContext context) async {
  final controller = PeekScope.read(context);
  final strings = PeekScope.stringsOf(context);
  final share = PeekScope.shareOf(context);
  final entries = controller.entries;
  final origin = peekShareOrigin(context);

  final action = await showPeekActions<PeekEntryAction>(
    context,
    title: strings.requestCount(entries.length, controller.totalCount),
    actions: [
      PeekAction(
        value: PeekEntryAction.copyHar,
        label: strings.exportHar,
        icon: PeekIcons.braces,
        section: strings.copy,
      ),
      if (share != null)
        PeekAction(
          value: PeekEntryAction.shareHar,
          label: strings.shareHar,
          icon: PeekIcons.share,
          section: strings.share,
        ),
    ],
  );
  if (action == null || !context.mounted) return;

  // What the list shows is what gets exported: the filter is part of the
  // question being asked.
  switch (action) {
    case PeekEntryAction.shareHar:
      await share?.share(peekHarContent(entries, 'peek', origin: origin));
    case _:
      await peekCopy(context, PeekExporters.har.export(entries, pretty: true));
  }
}

/// The call a sheet is about: its method as a tile, its path and host.
class _EntryHeader extends StatelessWidget {
  const _EntryHeader(this.entry);

  final PeekEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final request = entry.request;
    return Row(
      children: [
        PeekMethodBadge(request.method, large: true),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                request.path.isEmpty ? '/' : request.path,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.headline,
              ),
              Text(
                request.host,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.footnote.copyWith(color: theme.secondaryLabel),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// An HTTP Archive of [entries], named after [subject], shared from
/// [origin] where the platform wants to know.
PeekShareContent peekHarContent(
  List<PeekEntry> entries,
  String subject, {
  Rect? origin,
}) => PeekShareContent(
  filename: '$subject.har',
  mimeType: 'application/json',
  subject: subject,
  origin: origin,
  text: PeekExporters.har.export(entries, pretty: true),
);
