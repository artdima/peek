import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../../core/export/peek_exporters.dart';
import '../../core/model/peek_entry.dart';
import '../peek_scope.dart';
import '../peek_strings.dart';
import '../theme/peek_theme.dart';
import 'peek_highlighted_text.dart';
import 'peek_sheet.dart';
import 'peek_status_label.dart';
import 'peek_tappable.dart';

/// What a long press on a tile offers.
enum PeekTileAction {
  /// Pin or unpin the entry.
  pin,

  /// Put the URL on the clipboard.
  copyUrl,

  /// Put a curl command on the clipboard.
  copyCurl,

  /// Hand the entry to the share sheet.
  share,
}

/// One network call as a row of the list.
///
/// Three lines, in the order a reader needs them: how it ended, what was
/// asked, and of whom. The outcome leads, coloured and dotted, because
/// that is what the eye scans a log for.
final class PeekEntryTile extends StatelessWidget {
  /// Creates a tile for [entry].
  const PeekEntryTile(
    this.entry, {
    this.onTap,
    this.onAction,
    this.selected = false,
    this.showShare = false,
    this.highlight = '',
    super.key,
  });

  /// The call to show.
  final PeekEntry entry;

  /// Called when the row is tapped.
  final VoidCallback? onTap;

  /// Called with the menu item a long press picked.
  final void Function(PeekTileAction action)? onAction;

  /// Whether this row is the one open in the detail pane.
  final bool selected;

  /// Whether the menu offers sharing; hidden without a share delegate.
  final bool showShare;

  /// Text the search matched, marked wherever it appears in the URL.
  final String highlight;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final strings = PeekScope.stringsOf(context);
    final request = entry.request;
    final metrics = strings.metrics(entry.duration, entry.responseSize);

    return MergeSemantics(
      child: Semantics(
        label: strings.entrySemantics(entry),
        button: onTap != null,
        selected: selected ? true : null,
        child: PeekTappable(
          onTap: onTap,
          onLongPress:
              onAction == null ? null : () => _showMenu(context, strings),
          selected: selected,
          child: ExcludeSemantics(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: theme.gutter,
                vertical: 9,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(child: PeekStatusLabel(entry)),
                            if (metrics.isNotEmpty)
                              Flexible(
                                child: Text(
                                  ' · $metrics',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.footnote.copyWith(
                                    color: theme.secondaryLabel,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          strings.timestamp(entry.startedAt),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.caption.copyWith(
                            color: theme.tertiaryLabel,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        request.method.toUpperCase(),
                        style: theme.body.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: PeekHighlightedText(
                          request.path.isEmpty ? '/' : request.path,
                          highlight: highlight,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.body,
                        ),
                      ),
                      if (entry.isPinned) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.push_pin,
                          size: 12,
                          color: theme.tertiaryLabel,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  PeekHighlightedText(
                    request.host,
                    highlight: highlight,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.footnote.copyWith(color: theme.secondaryLabel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showMenu(BuildContext context, PeekStrings strings) async {
    final action = await showPeekActions<PeekTileAction>(
      context,
      title: '${entry.request.method} ${entry.request.path}',
      actions: [
        PeekAction(
          value: PeekTileAction.pin,
          label: entry.isPinned ? strings.unpin : strings.pin,
        ),
        PeekAction(value: PeekTileAction.copyUrl, label: strings.copyUrl),
        PeekAction(value: PeekTileAction.copyCurl, label: strings.copyCurl),
        if (showShare)
          PeekAction(value: PeekTileAction.share, label: strings.share),
      ],
    );
    if (action != null) onAction?.call(action);
  }

  /// The curl command for [entry], for whoever handles [PeekTileAction].
  String curl() => PeekExporters.curl.export(entry);

  /// The URL of [entry], for whoever handles [PeekTileAction].
  String url() => PeekExporters.url(entry);
}
