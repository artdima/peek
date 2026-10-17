import 'package:flutter/widgets.dart';

import '../../core/export/peek_exporters.dart';
import '../../core/model/peek_entry.dart';
import '../../core/peek.dart';
import '../../core/session/peek_session.dart';
import '../../core/session/peek_session_header.dart';
import '../icons/peek_icons.dart';
import '../peek_scope.dart';
import '../peek_share.dart';
import '../theme/peek_theme.dart';
import 'peek_copy_button.dart';
import 'peek_desktop_sheet.dart';
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

  /// Hand the URL to the platform as text.
  shareUrl,

  /// Hand a curl command that replays the call to the platform as text.
  shareCurl,

  /// Hand a plain-text summary to the platform as text.
  shareText,

  /// Hand a Markdown summary to the platform as text.
  shareMarkdown,

  /// Hand an HTTP Archive of this one call to the platform as a file.
  shareHar,
}

/// The ways one call can be handed to the platform.
enum PeekShareFormat {
  /// The URL alone, as text.
  url,

  /// A curl command that replays the call, as text.
  curl,

  /// A plain-text summary, as text.
  text,

  /// A Markdown summary, as text.
  markdown,

  /// An HTTP Archive holding the call, as a file.
  har,
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
      if (share != null) ...[
        PeekAction(
          value: PeekEntryAction.shareUrl,
          label: strings.shareUrl,
          icon: PeekIcons.link,
          section: strings.share,
        ),
        PeekAction(
          value: PeekEntryAction.shareCurl,
          label: strings.shareCurl,
          icon: PeekIcons.curl,
          section: strings.share,
        ),
        PeekAction(
          value: PeekEntryAction.shareText,
          label: strings.shareText,
          icon: PeekIcons.text,
          section: strings.share,
        ),
        PeekAction(
          value: PeekEntryAction.shareMarkdown,
          label: strings.shareMarkdown,
          icon: PeekIcons.markdown,
          section: strings.share,
        ),
        PeekAction(
          value: PeekEntryAction.shareHar,
          label: strings.shareHar,
          icon: PeekIcons.braces,
          section: strings.share,
        ),
      ],
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
    case PeekEntryAction.shareUrl:
      await share?.share(
        peekEntryContent(entry, PeekShareFormat.url, origin: origin),
      );
    case PeekEntryAction.shareCurl:
      await share?.share(
        peekEntryContent(entry, PeekShareFormat.curl, origin: origin),
      );
    case PeekEntryAction.shareText:
      await share?.share(
        peekEntryContent(entry, PeekShareFormat.text, origin: origin),
      );
    case PeekEntryAction.shareMarkdown:
      await share?.share(
        peekEntryContent(entry, PeekShareFormat.markdown, origin: origin),
      );
    case PeekEntryAction.shareHar:
      await share?.share(
        peekEntryContent(entry, PeekShareFormat.har, origin: origin),
      );
  }
}

enum _ListAction { copyHar, shareHar, saveSession, desktop }

/// Offers what can be done with the list as it stands, and does it.
Future<void> showPeekListActions(BuildContext context) async {
  final controller = PeekScope.read(context);
  final strings = PeekScope.stringsOf(context);
  final share = PeekScope.shareOf(context);
  final entries = controller.entries;
  final origin = peekShareOrigin(context);
  final link = peekDesktopLinkOf(context);

  // The exports need something to export; the desktop is always there to
  // connect to, or to read about.
  final action = await showPeekActions<_ListAction>(
    context,
    title: strings.requestCount(entries.length, controller.totalCount),
    actions: [
      if (entries.isNotEmpty) ...[
        PeekAction(
          value: _ListAction.copyHar,
          label: strings.exportHar,
          icon: PeekIcons.braces,
          section: strings.copy,
        ),
        if (share != null) ...[
          PeekAction(
            value: _ListAction.shareHar,
            label: strings.shareHar,
            icon: PeekIcons.share,
            section: strings.share,
          ),
          PeekAction(
            value: _ListAction.saveSession,
            label: strings.saveSession,
            icon: PeekIcons.download,
            section: strings.share,
          ),
        ],
      ],
      PeekAction(
        value: _ListAction.desktop,
        label: peekDesktopMenuLabel(strings, link),
        icon: PeekIcons.desktop,
        section: strings.desktop,
      ),
    ],
  );
  if (action == null || !context.mounted) return;

  // A HAR holds what the list shows — the filter is part of the question
  // being asked. A session holds everything: it is the record itself.
  switch (action) {
    case _ListAction.copyHar:
      await peekCopy(context, PeekExporters.har.export(entries, pretty: true));
    case _ListAction.shareHar:
      await share?.share(peekHarContent(entries, 'peek', origin: origin));
    case _ListAction.saveSession:
      await share?.share(peekSessionContent(controller.peek, origin: origin));
    case _ListAction.desktop:
      await showPeekDesktop(context);
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

/// One call written out as [format], shared from [origin] where the
/// platform wants to know.
///
/// The text formats go as [PeekShareKind.text], named after the host for a
/// receiver that can only take a file; [PeekShareFormat.har] is
/// [peekHarContent] of this one call.
PeekShareContent peekEntryContent(
  PeekEntry entry,
  PeekShareFormat format, {
  Rect? origin,
}) {
  final host = entry.request.host;
  return switch (format) {
    PeekShareFormat.url => _textContent(
      entry,
      text: PeekExporters.url(entry),
      filename: '$host.txt',
      mimeType: 'text/plain',
      origin: origin,
    ),
    PeekShareFormat.curl => _textContent(
      entry,
      text: PeekExporters.curl.export(entry),
      filename: '$host.sh',
      mimeType: 'text/x-shellscript',
      origin: origin,
    ),
    PeekShareFormat.text => _textContent(
      entry,
      text: PeekExporters.text.export(entry),
      filename: '$host.txt',
      mimeType: 'text/plain',
      origin: origin,
    ),
    PeekShareFormat.markdown => _textContent(
      entry,
      text: PeekExporters.markdown.export(entry),
      filename: '$host.md',
      mimeType: 'text/markdown',
      origin: origin,
    ),
    PeekShareFormat.har => peekHarContent([entry], host, origin: origin),
  };
}

PeekShareContent _textContent(
  PeekEntry entry, {
  required String text,
  required String filename,
  required String mimeType,
  required Rect? origin,
}) {
  final request = entry.request;
  final path = request.path.isEmpty ? '/' : request.path;
  return PeekShareContent(
    kind: PeekShareKind.text,
    filename: filename,
    mimeType: mimeType,
    subject: '${request.method} $path — ${request.host}',
    origin: origin,
    text: text,
  );
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

/// A `.peek` session of everything [peek] holds, whatever a list shows,
/// shared from [origin] where the platform wants to know.
///
/// The file is named after the app — `PeekOptions.name`, or the platform
/// when the app gave none — and the local time it was saved:
/// `peek-acme-shop-20260925-093012.peek`.
PeekShareContent peekSessionContent(Peek peek, {Rect? origin}) {
  final entries = peek.store.entries;
  final now = peek.options.clock.now();
  final header = PeekSessionHeader.current(
    name: peek.options.name,
    startedAt:
        entries.isEmpty
            ? now
            : entries
                .map((entry) => entry.startedAt)
                .reduce((a, b) => a.isBefore(b) ? a : b),
  );
  final filename =
      'peek-${_fileNamePart(header.name ?? header.platform)}-'
      '${_fileTimestamp(now)}.peek';
  return PeekShareContent(
    filename: filename,
    mimeType: 'application/x-ndjson',
    subject: header.name ?? 'peek',
    origin: origin,
    text: const PeekSessionWriter().write(header, entries),
  );
}

String _fileNamePart(String name) {
  final part = name
      .toLowerCase()
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return part.isEmpty ? 'app' : part;
}

String _fileTimestamp(DateTime time) {
  final local = time.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year}${two(local.month)}${two(local.day)}-'
      '${two(local.hour)}${two(local.minute)}${two(local.second)}';
}
