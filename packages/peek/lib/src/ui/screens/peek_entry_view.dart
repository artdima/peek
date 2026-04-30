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

    return ColoredBox(
      color: theme.groupedBackground,
      child: ListView(
        padding: EdgeInsets.only(top: theme.rowSpacing),
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: theme.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      request.method.toUpperCase(),
                      style: theme.body.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 10),
                    Flexible(child: PeekStatusLabel(entry)),
                    const Spacer(),
                    PeekIconButton(
                      icon:
                          entry.isPinned
                              ? Icons.push_pin
                              : Icons.push_pin_outlined,
                      tooltip: entry.isPinned ? strings.unpin : strings.pin,
                      size: 18,
                      onPressed: () => controller.togglePin(entry.id),
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: SelectableText(url, style: theme.body)),
                    PeekCopyButton(text: url),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: theme.rowSpacing),
          _Transfer(entry: entry, strings: strings),
          PeekListSection(
            title: strings.overview,
            children: [
              PeekListRow(title: strings.status, value: strings.outcome(entry)),
              PeekListRow(title: strings.duration, value: _duration(strings)),
              PeekListRow(
                title: strings.started,
                value: strings.timestamp(entry.startedAt),
              ),
              PeekListRow(title: strings.source, value: entry.source),
            ],
          ),
        ],
      ),
    );
  }

  String _duration(PeekStrings strings) {
    final elapsed = entry.duration;
    return elapsed == null ? strings.none : strings.elapsed(elapsed);
  }
}

/// What went out and what came back, side by side.
class _Transfer extends StatelessWidget {
  const _Transfer({required this.entry, required this.strings});

  final PeekEntry entry;
  final PeekStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(theme.gutter, 0, theme.gutter, theme.gutter),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _Amount(
                icon: Icons.arrow_upward,
                label: strings.sent,
                bytes: entry.requestSize,
                strings: strings,
              ),
            ),
            SizedBox(
              width: theme.hairline,
              child: ColoredBox(
                color: theme.separator,
                child: const SizedBox(height: double.infinity),
              ),
            ),
            Expanded(
              child: _Amount(
                icon: Icons.arrow_downward,
                label: strings.received,
                bytes: entry.responseSize,
                strings: strings,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount({
    required this.icon,
    required this.label,
    required this.bytes,
    required this.strings,
  });

  final IconData icon;
  final String label;
  final int? bytes;
  final PeekStrings strings;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final size = bytes;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: theme.secondaryLabel),
            const SizedBox(width: 5),
            Text(
              label,
              style: theme.footnote.copyWith(color: theme.secondaryLabel),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          size == null ? strings.none : strings.bytes(size),
          style: theme.headline,
        ),
      ],
    );
  }
}
