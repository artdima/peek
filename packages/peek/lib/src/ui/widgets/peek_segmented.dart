import 'package:flutter/widgets.dart';

import '../theme/peek_theme.dart';
import 'peek_tappable.dart';

/// One choice of a [PeekSegmented].
@immutable
final class PeekSegment<T> {
  /// Creates a segment showing [label], optionally with a [count].
  const PeekSegment({required this.value, required this.label, this.count});

  /// What choosing this segment means.
  final T value;

  /// What it reads.
  final String label;

  /// How many entries it stands for, shown beside the label.
  final int? count;
}

/// A row of pills, one of which may be chosen.
///
/// Nothing is chosen when [selected] matches no segment — better than
/// pointing at a segment that is not what the list shows.
final class PeekSegmented<T> extends StatelessWidget {
  /// Creates the row.
  const PeekSegmented({
    required this.segments,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  /// The choices, in order.
  final List<PeekSegment<T>> segments;

  /// Which one is chosen, if any.
  final T? selected;

  /// Called with the segment that was tapped.
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 6,
    children: [
      for (final segment in segments)
        _Pill(
          segment: segment,
          chosen: segment.value == selected,
          onTap: () => onChanged(segment.value),
        ),
    ],
  );
}

class _Pill<T> extends StatelessWidget {
  const _Pill({
    required this.segment,
    required this.chosen,
    required this.onTap,
  });

  final PeekSegment<T> segment;
  final bool chosen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    final count = segment.count;
    const onAccent = Color(0xFFFFFFFF);

    return PeekTappable(
      onTap: onTap,
      fade: true,
      // The pill is 32 tall; the box around it carries the tap target.
      child: SizedBox(
        height: theme.minRowHeight,
        child: Center(
          child: Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: chosen ? theme.accent : theme.fill,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  segment.label,
                  style: theme.footnote.copyWith(
                    color: chosen ? onAccent : theme.label,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 5),
                  Text(
                    '$count',
                    style: theme.footnote.copyWith(
                      color:
                          chosen
                              ? onAccent.withValues(alpha: 0.8)
                              : theme.secondaryLabel,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
