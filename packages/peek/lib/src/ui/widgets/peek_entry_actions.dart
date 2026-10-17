import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/widgets.dart';

import '../../core/export/peek_exporters.dart';
import '../../core/model/peek_entry.dart';
import '../../core/model/peek_response.dart';
import '../../core/model/peek_status_class.dart';
import '../../core/peek.dart';
import '../../core/session/peek_session.dart';
import '../../core/session/peek_session_header.dart';
import '../icons/peek_icon.dart';
import '../icons/peek_icon_data.dart';
import '../icons/peek_icons.dart';
import '../peek_scope.dart';
import '../peek_share.dart';
import '../theme/peek_theme.dart';
import 'peek_copy_button.dart';
import 'peek_desktop_sheet.dart';
import 'peek_icon_button.dart';
import 'peek_method_badge.dart';
import 'peek_separator.dart';
import 'peek_sheet.dart';
import 'peek_tappable.dart';
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
enum PeekEntryFormat {
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
/// Every format the call can be written out in is a row, and what can be
/// done with it sits at the row's end: copied, always, and handed to the
/// platform where something can carry it off — the app's
/// [PeekShareDelegate], or the browser on the web. An option that cannot
/// work is worse than no option, so without either there is no share
/// column.
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

  final action = await showPeekSheet<PeekEntryAction>(
    context,
    builder:
        (context) => _EntrySheet(
          entry: entry,
          canShare: share != null,
          canPin: includePin,
        ),
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
        peekEntryContent(entry, PeekEntryFormat.url, origin: origin),
      );
    case PeekEntryAction.shareCurl:
      await share?.share(
        peekEntryContent(entry, PeekEntryFormat.curl, origin: origin),
      );
    case PeekEntryAction.shareText:
      await share?.share(
        peekEntryContent(entry, PeekEntryFormat.text, origin: origin),
      );
    case PeekEntryAction.shareMarkdown:
      await share?.share(
        peekEntryContent(entry, PeekEntryFormat.markdown, origin: origin),
      );
    case PeekEntryAction.shareHar:
      await share?.share(
        peekEntryContent(entry, PeekEntryFormat.har, origin: origin),
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

/// The sheet of one call: what it is, how it went, and a table of the
/// formats it can leave in.
class _EntrySheet extends StatelessWidget {
  const _EntrySheet({
    required this.entry,
    required this.canShare,
    required this.canPin,
  });

  final PeekEntry entry;
  final bool canShare;
  final bool canPin;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final strings = PeekScope.stringsOf(context);
    final caption = theme.caption.copyWith(
      color: theme.secondaryLabel,
      letterSpacing: 0.5,
    );
    final redirects = entry.response?.redirects ?? const [];
    void choose(PeekEntryAction action) => Navigator.of(context).pop(action);

    final formats = [
      _Format(
        icon: PeekIcons.link,
        label: strings.formatUrl,
        copy: PeekEntryAction.copyUrl,
        copyLabel: strings.copyUrl,
        share: PeekEntryAction.shareUrl,
        shareLabel: strings.shareUrl,
      ),
      _Format(
        icon: PeekIcons.curl,
        label: strings.formatCurl,
        copy: PeekEntryAction.copyCurl,
        copyLabel: strings.copyCurl,
        share: PeekEntryAction.shareCurl,
        shareLabel: strings.shareCurl,
      ),
      _Format(
        icon: PeekIcons.text,
        label: strings.formatText,
        copy: PeekEntryAction.copyText,
        copyLabel: strings.copyText,
        share: PeekEntryAction.shareText,
        shareLabel: strings.shareText,
      ),
      _Format(
        icon: PeekIcons.markdown,
        label: strings.formatMarkdown,
        copy: PeekEntryAction.copyMarkdown,
        copyLabel: strings.copyMarkdown,
        share: PeekEntryAction.shareMarkdown,
        shareLabel: strings.shareMarkdown,
      ),
      _Format(
        icon: PeekIcons.braces,
        label: strings.formatHar,
        copy: PeekEntryAction.copyHar,
        copyLabel: strings.copyHar,
        share: PeekEntryAction.shareHar,
        shareLabel: strings.shareHar,
      ),
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: theme.gutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          _Header(
            entry: entry,
            onPin: canPin ? () => choose(PeekEntryAction.pin) : null,
            onClose: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 6),
          _Summary(entry),
          if (redirects.isNotEmpty) ...[
            const SizedBox(height: 10),
            _RedirectChain(entry, redirects),
          ],
          Padding(
            padding: EdgeInsets.only(top: theme.gutter, bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text(strings.exportAs.toUpperCase(), style: caption),
                  ),
                ),
                _ColumnCaption(strings.copy, style: caption),
                if (canShare) _ColumnCaption(strings.share, style: caption),
                const SizedBox(width: _FormatRow.endInset),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(theme.radius),
            child: ColoredBox(
              color: theme.card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (index, format) in formats.indexed) ...[
                    if (index > 0)
                      const PeekSeparator(indent: _FormatRow.labelInset),
                    _FormatRow(
                      format: format,
                      onCopy: () => choose(format.copy),
                      onShare: canShare ? () => choose(format.share) : null,
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(height: theme.gutter),
        ],
      ),
    );
  }
}

/// One way a call can leave, and what it is called in each column.
class _Format {
  const _Format({
    required this.icon,
    required this.label,
    required this.copy,
    required this.copyLabel,
    required this.share,
    required this.shareLabel,
  });

  final PeekIconData icon;
  final String label;
  final PeekEntryAction copy;
  final String copyLabel;
  final PeekEntryAction share;
  final String shareLabel;
}

/// The call a sheet is about — its method and path — with the pin and the
/// way out at the end.
class _Header extends StatelessWidget {
  const _Header({
    required this.entry,
    required this.onPin,
    required this.onClose,
  });

  final PeekEntry entry;
  final VoidCallback? onPin;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final strings = PeekScope.stringsOf(context);
    final request = entry.request;
    return Row(
      children: [
        PeekMethodBadge(request.method, large: true),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            request.path.isEmpty ? '/' : request.path,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.headline.copyWith(fontSize: 17),
          ),
        ),
        const SizedBox(width: 8),
        if (onPin case final onPin?) ...[
          _RoundButton(
            glyph: PeekIcons.pin,
            tooltip: entry.isPinned ? strings.unpin : strings.pin,
            selected: entry.isPinned,
            onPressed: onPin,
          ),
          const SizedBox(width: 10),
        ],
        _RoundButton(
          glyph: PeekIcons.close,
          tooltip: strings.close,
          onPressed: onClose,
        ),
      ],
    );
  }
}

/// A glyph on a disc, the way a sheet's own controls look.
class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.glyph,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
  });

  final PeekIconData glyph;
  final String tooltip;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    return MergeSemantics(
      child: Tooltip(
        message: tooltip,
        child: PeekTappable(
          onTap: onPressed,
          fade: true,
          focusRadius: BorderRadius.circular(theme.minTapTarget / 2),
          child: Semantics(
            button: true,
            child: SizedBox(
              width: theme.minTapTarget,
              height: theme.minTapTarget,
              child: Center(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color:
                        selected
                            ? theme.accent.withValues(alpha: 0.16)
                            : theme.card,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: PeekIcon(
                      glyph,
                      color: selected ? theme.accent : theme.label,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Where the call went and how it ended, in one line of figures.
class _Summary extends StatelessWidget {
  const _Summary(this.entry);

  final PeekEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final strings = PeekScope.stringsOf(context);
    final metrics = strings.metrics(entry.duration, entry.responseSize);
    final redirects = entry.response?.redirects.length ?? 0;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '${entry.request.host} · '),
          TextSpan(
            text: strings.outcome(entry),
            style: TextStyle(
              color: theme.colorForEntry(entry),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (metrics.isNotEmpty) TextSpan(text: ' · $metrics'),
          if (redirects > 0)
            TextSpan(text: ' · ${strings.redirectCount(redirects)}'),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.mono.copyWith(color: theme.secondaryLabel),
    );
  }
}

/// The hops a call took to get where it ended, as a bar per hop in the
/// colour of its status, with where each one pointed underneath.
class _RedirectChain extends StatelessWidget {
  const _RedirectChain(this.entry, this.redirects);

  final PeekEntry entry;
  final List<PeekRedirect> redirects;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final strings = PeekScope.stringsOf(context);
    final hops = [
      for (final hop in redirects)
        (
          label: '${hop.statusCode} ${_pathOf(hop.location)}',
          color: theme.colorForStatusClass(PeekStatusClass.of(hop.statusCode)),
        ),
      (label: strings.outcome(entry), color: theme.colorForEntry(entry)),
    ];
    final label = theme.mono.copyWith(
      fontSize: 10,
      color: theme.secondaryLabel,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final (index, hop) in hops.indexed) ...[
              if (index > 0) const SizedBox(width: 3),
              Expanded(
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: hop.color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final (index, hop) in hops.indexed) ...[
              if (index > 0) const SizedBox(width: 3),
              Expanded(
                child: Text(
                  hop.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: label,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  static String _pathOf(Uri location) =>
      location.path.isEmpty ? '/' : location.path;
}

/// Heads a column of the table, over the buttons it names.
class _ColumnCaption extends StatelessWidget {
  const _ColumnCaption(this.label, {required this.style});

  final String label;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: PeekIconButton.width,
    child: Text(
      label.toUpperCase(),
      textAlign: TextAlign.center,
      maxLines: 1,
      style: style,
    ),
  );
}

/// One format of the table: its glyph and name, then a button per column.
class _FormatRow extends StatelessWidget {
  const _FormatRow({
    required this.format,
    required this.onCopy,
    required this.onShare,
  });

  /// Where the name starts, past the glyph: what a hairline between rows
  /// is indented by.
  static const double labelInset = 14 + 20 + 12;

  /// What keeps the last button off the card's edge.
  static const double endInset = 8;

  final _Format format;
  final VoidCallback onCopy;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const SizedBox(width: 14),
          PeekIcon(format.icon, color: theme.accent),
          const SizedBox(width: 12),
          Expanded(child: Text(format.label, style: theme.body)),
          PeekIconButton(
            glyph: PeekIcons.copy,
            tooltip: format.copyLabel,
            size: 20,
            color: theme.label,
            onPressed: onCopy,
          ),
          if (onShare case final onShare?)
            PeekIconButton(
              glyph: PeekIcons.share,
              tooltip: format.shareLabel,
              size: 20,
              color: theme.label,
              onPressed: onShare,
            ),
          const SizedBox(width: endInset),
        ],
      ),
    );
  }
}

/// One call written out as [format], shared from [origin] where the
/// platform wants to know.
///
/// The text formats go as [PeekShareKind.text], named after the host for a
/// receiver that can only take a file; [PeekEntryFormat.har] is
/// [peekHarContent] of this one call.
PeekShareContent peekEntryContent(
  PeekEntry entry,
  PeekEntryFormat format, {
  Rect? origin,
}) {
  final host = entry.request.host;
  return switch (format) {
    PeekEntryFormat.url => _textContent(
      entry,
      text: PeekExporters.url(entry),
      filename: '$host.txt',
      mimeType: 'text/plain',
      origin: origin,
    ),
    PeekEntryFormat.curl => _textContent(
      entry,
      text: PeekExporters.curl.export(entry),
      filename: '$host.sh',
      mimeType: 'text/x-shellscript',
      origin: origin,
    ),
    PeekEntryFormat.text => _textContent(
      entry,
      text: PeekExporters.text.export(entry),
      filename: '$host.txt',
      mimeType: 'text/plain',
      origin: origin,
    ),
    PeekEntryFormat.markdown => _textContent(
      entry,
      text: PeekExporters.markdown.export(entry),
      filename: '$host.md',
      mimeType: 'text/markdown',
      origin: origin,
    ),
    PeekEntryFormat.har => peekHarContent([entry], host, origin: origin),
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
