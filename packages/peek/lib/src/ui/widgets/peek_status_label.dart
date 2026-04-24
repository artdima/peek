import 'package:flutter/widgets.dart';

import '../../core/model/peek_entry.dart';
import '../peek_scope.dart';
import '../theme/peek_theme.dart';
import 'peek_status_dot.dart';

/// How a call ended, as a dot and a few words in the colour of that
/// outcome: `200 OK`, `Timed out`, `Pending`.
final class PeekStatusLabel extends StatelessWidget {
  /// Creates a label describing [entry].
  const PeekStatusLabel(this.entry, {super.key});

  /// The call to describe.
  final PeekEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final strings = PeekScope.stringsOf(context);
    final color = theme.colorForEntry(entry);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PeekStatusDot(color),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            strings.outcome(entry),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.footnote.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
