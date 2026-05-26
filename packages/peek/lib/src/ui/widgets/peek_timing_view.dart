import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/model/peek_entry.dart';
import '../peek_scope.dart';
import '../theme/peek_theme.dart';
import 'peek_list_row.dart';
import 'peek_list_section.dart';

/// Where a call's time went.
///
/// The phases are laid out one after another, each bar starting where the
/// one before it ended, so the picture reads as the call happened. An
/// adapter that reports no phases still gets the total, and says why that
/// is all there is.
final class PeekTimingView extends StatelessWidget {
  /// Creates a view over [entry].
  const PeekTimingView(this.entry, {super.key});

  /// The call to account for.
  final PeekEntry entry;

  @override
  Widget build(BuildContext context) {
    final strings = PeekScope.stringsOf(context);
    final phases = entry.timings?.known ?? const <String, Duration>{};
    final elapsed = entry.duration;
    final finishedAt = entry.completedAt;

    final total = phases.values.fold(Duration.zero, (sum, it) => sum + it);
    final span = total > Duration.zero ? total : (elapsed ?? Duration.zero);

    return Column(
      children: [
        PeekListSection(
          title: strings.timing,
          footer: phases.isEmpty ? strings.noBreakdown : null,
          children: [
            PeekListRow(
              title: strings.duration,
              value: elapsed == null ? strings.none : strings.elapsed(elapsed),
            ),
            PeekListRow(
              title: strings.started,
              value: strings.timestamp(entry.startedAt),
            ),
            PeekListRow(
              title: strings.finished,
              value:
                  finishedAt == null
                      ? strings.none
                      : strings.timestamp(finishedAt),
            ),
          ],
        ),
        if (phases.isNotEmpty)
          PeekListSection(
            title: strings.phases,
            children: [
              for (final (index, MapEntry(:key, :value))
                  in phases.entries.toList().indexed)
                _PhaseRow(
                  name: strings.phase(key),
                  duration: value,
                  offset: phases.values
                      .take(index)
                      .fold(Duration.zero, (sum, it) => sum + it),
                  span: span,
                  color: _colorFor(key, PeekTheme.of(context)),
                ),
            ],
          ),
      ],
    );
  }

  static Color _colorFor(String phase, PeekTheme theme) => switch (phase) {
    'blocked' => theme.tertiaryLabel,
    'dns' => theme.redirect,
    'connect' => theme.clientError,
    'ssl' => theme.failure,
    'send' => theme.success,
    'wait' => theme.secondaryLabel,
    'receive' => theme.accent,
    _ => theme.pending,
  };
}

class _PhaseRow extends StatelessWidget {
  const _PhaseRow({
    required this.name,
    required this.duration,
    required this.offset,
    required this.span,
    required this.color,
  });

  final String name;
  final Duration duration;
  final Duration offset;
  final Duration span;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final strings = PeekScope.stringsOf(context);
    final theme = PeekTheme.of(context);
    final micros = span.inMicroseconds;
    final start = micros == 0 ? 0.0 : offset.inMicroseconds / micros;
    final width = micros == 0 ? 0.0 : duration.inMicroseconds / micros;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: theme.gutter, vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.footnote.copyWith(color: theme.secondaryLabel),
            ),
          ),
          Expanded(
            child: SizedBox(
              height: 10,
              child: LayoutBuilder(
                builder:
                    (context, constraints) => Stack(
                      children: [
                        Positioned(
                          left: constraints.maxWidth * start,
                          top: 0,
                          bottom: 0,
                          // A phase too short to see still gets a mark.
                          width: math.max(3, constraints.maxWidth * width),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ],
                    ),
              ),
            ),
          ),
          SizedBox(
            width: 62,
            child: Text(
              strings.elapsed(duration),
              textAlign: TextAlign.end,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.caption.copyWith(color: theme.label),
            ),
          ),
        ],
      ),
    );
  }
}
