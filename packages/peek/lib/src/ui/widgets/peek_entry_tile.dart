import 'package:flutter/material.dart';

import '../../core/export/peek_exporters.dart';
import '../../core/model/peek_entry.dart';
import '../peek_scope.dart';
import '../peek_strings.dart';
import '../theme/peek_theme.dart';
import 'peek_method_badge.dart';
import 'peek_status_chip.dart';

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
/// The path carries the meaning, so it is the largest thing here; the host
/// sits under it, and the outcome, timing and size line up on the right.
final class PeekEntryTile extends StatelessWidget {
  /// Creates a tile for [entry].
  const PeekEntryTile(
    this.entry, {
    this.onTap,
    this.onAction,
    this.selected = false,
    this.showShare = false,
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

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final strings = PeekScope.stringsOf(context);
    final accent = theme.colorForEntry(entry);
    final request = entry.request;
    final muted = theme.monoTextStyle.color?.withValues(alpha: 0.55);
    final metrics = strings.metrics(entry.duration, entry.responseSize);

    return MergeSemantics(
      child: Semantics(
        label: strings.entrySemantics(entry),
        button: onTap != null,
        selected: selected ? true : null,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            onLongPress:
                onAction == null ? null : () => _showMenu(context, strings),
            child: ExcludeSemantics(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color:
                      selected
                          ? accent.withValues(alpha: 0.12)
                          : entry.isError
                          ? accent.withValues(alpha: 0.06)
                          : null,
                  border: Border(
                    left: BorderSide(
                      color:
                          selected || entry.isError
                              ? accent
                              : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: theme.gutter,
                    vertical: theme.rowSpacing,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                PeekMethodBadge(request.method),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    request.path.isEmpty ? '/' : request.path,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.monoTextStyle.copyWith(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (entry.isPinned) ...[
                                  const SizedBox(width: 6),
                                  Icon(Icons.push_pin, size: 12, color: muted),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              request.host,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.monoTextStyle.copyWith(
                                fontSize: 11,
                                color: muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            PeekStatusChip(entry),
                            if (metrics.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                metrics,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.monoTextStyle.copyWith(
                                  fontSize: 11,
                                  color: muted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showMenu(BuildContext context, PeekStrings strings) async {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final box = context.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(box.size.center(Offset.zero));
    final action = await showMenu<PeekTileAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        origin.dx,
        origin.dy,
        overlay.size.width - origin.dx,
        overlay.size.height - origin.dy,
      ),
      items: [
        PopupMenuItem(
          value: PeekTileAction.pin,
          child: Text(entry.isPinned ? strings.unpin : strings.pin),
        ),
        PopupMenuItem(
          value: PeekTileAction.copyUrl,
          child: Text(strings.copyUrl),
        ),
        PopupMenuItem(
          value: PeekTileAction.copyCurl,
          child: Text(strings.copyCurl),
        ),
        if (showShare)
          PopupMenuItem(
            value: PeekTileAction.share,
            child: Text(strings.share),
          ),
      ],
    );
    if (action != null) onAction?.call(action);
  }

  /// The curl command for [entry], for whoever handles [PeekTileAction].
  String curl() => PeekExporters.curl.export(entry);

  /// The URL of [entry], for whoever handles [PeekTileAction].
  String url() => PeekExporters.url(entry);
}
