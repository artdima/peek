import 'package:flutter/widgets.dart';

import '../../core/export/peek_exporters.dart';
import '../../core/model/peek_entry.dart';
import '../peek_scope.dart';
import '../peek_share.dart';
import 'peek_copy_button.dart';
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
/// Sharing appears only when the app gave Peek a [PeekShareDelegate]: an
/// option that cannot work is worse than no option.
Future<void> showPeekEntryActions(
  BuildContext context,
  PeekEntry entry, {
  bool includePin = true,
}) async {
  final controller = PeekScope.read(context);
  final strings = PeekScope.stringsOf(context);
  final share = PeekScope.shareOf(context);
  final request = entry.request;

  final action = await showPeekActions<PeekEntryAction>(
    context,
    title: '${request.method} ${request.path}',
    actions: [
      if (includePin)
        PeekAction(
          value: PeekEntryAction.pin,
          label: entry.isPinned ? strings.unpin : strings.pin,
        ),
      PeekAction(value: PeekEntryAction.copyUrl, label: strings.copyUrl),
      PeekAction(value: PeekEntryAction.copyCurl, label: strings.copyCurl),
      PeekAction(value: PeekEntryAction.copyText, label: strings.copyText),
      PeekAction(
        value: PeekEntryAction.copyMarkdown,
        label: strings.copyMarkdown,
      ),
      PeekAction(value: PeekEntryAction.copyHar, label: strings.exportHar),
      if (share != null)
        PeekAction(value: PeekEntryAction.shareHar, label: strings.shareHar),
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
      await share?.share(peekHarContent([entry], entry.request.host));
  }
}

/// Offers what can be done with the list as it stands, and does it.
Future<void> showPeekListActions(BuildContext context) async {
  final controller = PeekScope.read(context);
  final strings = PeekScope.stringsOf(context);
  final share = PeekScope.shareOf(context);
  final entries = controller.entries;

  final action = await showPeekActions<PeekEntryAction>(
    context,
    title: strings.requestCount(entries.length, controller.totalCount),
    actions: [
      PeekAction(value: PeekEntryAction.copyHar, label: strings.exportHar),
      if (share != null)
        PeekAction(value: PeekEntryAction.shareHar, label: strings.shareHar),
    ],
  );
  if (action == null || !context.mounted) return;

  // What the list shows is what gets exported: the filter is part of the
  // question being asked.
  switch (action) {
    case PeekEntryAction.shareHar:
      await share?.share(peekHarContent(entries, 'peek'));
    case _:
      await peekCopy(context, PeekExporters.har.export(entries, pretty: true));
  }
}

/// An HTTP Archive of [entries], named after [subject].
PeekShareContent peekHarContent(List<PeekEntry> entries, String subject) =>
    PeekShareContent(
      filename: '$subject.har',
      mimeType: 'application/json',
      subject: subject,
      text: PeekExporters.har.export(entries, pretty: true),
    );
