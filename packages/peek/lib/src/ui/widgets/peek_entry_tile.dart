import 'dart:async';

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../../core/model/peek_entry.dart';
import '../peek_scope.dart';
import '../theme/peek_theme.dart';
import 'peek_entry_actions.dart';
import 'peek_highlighted_text.dart';
import 'peek_status_dot.dart';
import 'peek_status_label.dart';
import 'peek_tappable.dart';

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
    this.selected = false,
    this.menu = true,
    this.highlight = '',
    super.key,
  });

  /// The call to show.
  final PeekEntry entry;

  /// Called when the row is tapped.
  final VoidCallback? onTap;

  /// Whether this row is the one open in the detail pane.
  final bool selected;

  /// Whether a long press offers what can be done with the call.
  final bool menu;

  /// Text the search matched, marked wherever it appears in the URL.
  final String highlight;

  /// How far the outcome dot sits from the left edge: nearer than the
  /// gutter, the way a call's colour leads the row in Pulse.
  static const double dotGutter = 6;

  /// Where a row's text starts, and so where a separator between rows
  /// should: past the dot and the space after it.
  static const double textInset = dotGutter + 8 + 7;

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
              menu
                  ? () => unawaited(showPeekEntryActions(context, entry))
                  : null,
          selected: selected,
          child: ExcludeSemantics(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                PeekEntryTile.dotGutter,
                9,
                theme.gutter,
                9,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5, right: 7),
                    child: PeekStatusDot(theme.colorForEntry(entry)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: PeekStatusLabel(
                                entry,
                                dot: false,
                                trailing: metrics.isEmpty ? null : metrics,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // No flex: the moment keeps its width and the
                            // outcome takes the rest, so the row reaches the
                            // far edge instead of stopping halfway.
                            Text(
                              strings.timestamp(entry.startedAt),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.caption.copyWith(
                                color: theme.secondaryLabel,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              request.method.toUpperCase(),
                              style: theme.body.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
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
                          style: theme.footnote.copyWith(
                            color: theme.secondaryLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
