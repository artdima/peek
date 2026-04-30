import 'package:flutter/widgets.dart';

import '../../core/model/peek_entry.dart';
import '../peek_scope.dart';
import '../theme/peek_theme.dart';
import 'peek_status_dot.dart';

/// How a call ended, as a dot and a few words in the colour of that
/// outcome: `200 OK`, `Timed out`, `Pending`.
final class PeekStatusLabel extends StatelessWidget {
  /// Creates a label describing [entry].
  const PeekStatusLabel(this.entry, {this.trailing, super.key});

  /// The call to describe.
  final PeekEntry entry;

  /// Follows the outcome in the secondary colour, after a separator.
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final strings = PeekScope.stringsOf(context);
    final color = theme.colorForEntry(entry);

    final outcome = theme.footnote.copyWith(
      color: color,
      fontWeight: FontWeight.w600,
    );
    final trailing = this.trailing;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PeekStatusDot(color),
        const SizedBox(width: 7),
        Flexible(
          child:
              trailing == null
                  ? Text(
                    strings.outcome(entry),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: outcome,
                  )
                  : Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: strings.outcome(entry)),
                        TextSpan(
                          text: ' · $trailing',
                          style: theme.footnote.copyWith(
                            color: theme.secondaryLabel,
                          ),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: outcome,
                  ),
        ),
      ],
    );
  }
}
