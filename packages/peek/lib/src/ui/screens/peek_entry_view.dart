import 'package:flutter/material.dart' show Icons, SelectableText;
import 'package:flutter/widgets.dart';

import '../../core/model/peek_entry.dart';
import '../peek_scope.dart';
import '../peek_strings.dart';
import '../theme/peek_theme.dart';
import '../widgets/widgets.dart';

/// One call in full, without a screen around it.
///
/// The same widget fills the detail pane of the wide layout and the body
/// of the pushed screen, so a call reads the same either way.
final class PeekEntryView extends StatelessWidget {
  /// Creates the view of [entry].
  const PeekEntryView(this.entry, {super.key});

  /// The call to show.
  final PeekEntry entry;

  @override
  Widget build(BuildContext context) {
    final controller = PeekScope.of(context);
    final strings = PeekScope.stringsOf(context);
    final theme = PeekTheme.of(context);
    final request = entry.request;
    final url = request.uri.toString();

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: theme.gutter),
      children: [
        Padding(
          padding: EdgeInsets.only(top: theme.gutter),
          child: Row(
            children: [
              PeekMethodBadge(request.method),
              const SizedBox(width: 8),
              Flexible(child: PeekStatusLabel(entry)),
              const Spacer(),
              PeekIconButton(
                icon: entry.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                tooltip: entry.isPinned ? strings.unpin : strings.pin,
                size: 18,
                onPressed: () => controller.togglePin(entry.id),
              ),
            ],
          ),
        ),
        SelectableText(url, style: theme.headline),
        Align(
          alignment: Alignment.centerLeft,
          child: PeekCopyButton(text: url),
        ),
        PeekSectionHeader(strings.overview),
        PeekKeyValueRow(name: strings.status, value: _outcome(strings)),
        PeekKeyValueRow(
          name: strings.duration,
          value:
              entry.duration == null
                  ? strings.none
                  : strings.elapsed(entry.duration!),
        ),
        PeekKeyValueRow(
          name: strings.request,
          value: _size(strings, entry.requestSize),
        ),
        PeekKeyValueRow(
          name: strings.response,
          value: _size(strings, entry.responseSize),
        ),
        PeekKeyValueRow(
          name: strings.started,
          value: strings.clockTime(entry.startedAt),
        ),
        PeekKeyValueRow(name: strings.source, value: entry.source),
        SizedBox(height: theme.gutter),
      ],
    );
  }

  /// The status code, or what replaced it.
  String _outcome(PeekStrings strings) {
    final code = entry.statusCode;
    if (code != null) return '$code';
    final failure = entry.failure;
    if (failure == null) return strings.pending;
    return strings.failureKind(failure.kind);
  }

  String _size(PeekStrings strings, int? bytes) =>
      bytes == null ? strings.none : strings.bytes(bytes);
}
