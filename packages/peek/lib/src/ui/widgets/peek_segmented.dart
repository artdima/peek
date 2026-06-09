import 'package:flutter/widgets.dart';

import 'peek_pill.dart';

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
        PeekPill(
          label: segment.label,
          count: segment.count,
          selected: segment.value == selected,
          group: true,
          onTap: () => onChanged(segment.value),
        ),
    ],
  );
}
