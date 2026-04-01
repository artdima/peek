import 'package:flutter/material.dart';

import '../../core/model/peek_entry.dart';
import '../peek_scope.dart';
import '../theme/peek_theme.dart';

/// How a call ended: a status code, a spinner, or a failure.
final class PeekStatusChip extends StatelessWidget {
  /// Creates a chip describing [entry].
  const PeekStatusChip(this.entry, {super.key});

  /// The call to describe.
  final PeekEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final strings = PeekScope.stringsOf(context);
    final color = theme.colorForEntry(entry);
    final label = switch (entry.state) {
      PeekEntryState.pending => strings.pending,
      PeekEntryState.completed => '${entry.statusCode}',
      PeekEntryState.failed =>
        entry.statusCode?.toString() ??
            strings.failureKind(entry.failure!.kind),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(theme.radius / 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Leading(entry: entry, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.monoTextStyle.copyWith(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Leading extends StatelessWidget {
  const _Leading({required this.entry, required this.color});

  final PeekEntry entry;
  final Color color;

  @override
  Widget build(BuildContext context) => switch (entry.state) {
    PeekEntryState.pending => SizedBox(
      width: 11,
      height: 11,
      child: CircularProgressIndicator(strokeWidth: 2, color: color),
    ),
    PeekEntryState.failed => Icon(Icons.error_outline, size: 11, color: color),
    PeekEntryState.completed => Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    ),
  };
}
