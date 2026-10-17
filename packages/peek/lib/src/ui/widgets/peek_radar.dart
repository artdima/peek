import 'dart:math' as math;

import 'package:flutter/material.dart' show Icons;
import 'package:flutter/widgets.dart';

import '../theme/peek_theme.dart';

/// Three arcs of a radar sweeping out from a point, behind an empty list.
///
/// With a pulse at the centre it says Peek is listening — recording, and
/// nothing has come. With a filter there it says the search and the
/// filters caught everything, and a stray dot on each arc shows what.
final class PeekRadar extends StatelessWidget {
  /// Recording and waiting for a call; [active] is false while recording
  /// is paused, and the pulse goes grey.
  const PeekRadar.listening({this.active = true, super.key})
    : _filtered = false;

  /// A filter that caught everything.
  const PeekRadar.filtered({super.key}) : _filtered = true, active = false;

  /// Whether the pulse is live.
  final bool active;

  final bool _filtered;

  /// How far the outermost arc reaches from the centre.
  static const double outerRadius = 116;

  /// Room around the arcs, so a stroke is not clipped.
  static const double _margin = 4;

  /// Half the centrepiece: what hangs below the arcs' baseline.
  static const double _centre = 24;

  @override
  Widget build(BuildContext context) {
    final theme = PeekTheme.of(context);
    const origin = Offset(outerRadius + _margin, outerRadius + _margin);
    return SizedBox(
      width: (outerRadius + _margin) * 2,
      height: outerRadius + _margin + _centre,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _Arcs(
                color: theme.separator,
                origin: origin,
                dashed: _filtered,
              ),
            ),
          ),
          Positioned(
            left: origin.dx - _centre,
            top: origin.dy - _centre,
            child:
                _filtered
                    ? _Catch(theme: theme)
                    : _Pulse(theme: theme, active: active),
          ),
        ],
      ),
    );
  }
}

/// The filter that caught everything, on a disc.
class _Catch extends StatelessWidget {
  const _Catch({required this.theme});

  final PeekTheme theme;

  @override
  Widget build(BuildContext context) => Container(
    width: PeekRadar._centre * 2,
    height: PeekRadar._centre * 2,
    decoration: BoxDecoration(color: theme.fill, shape: BoxShape.circle),
    child: Icon(Icons.filter_list, size: 22, color: theme.label),
  );
}

/// The recording light: a dot in a halo, green while it listens.
class _Pulse extends StatelessWidget {
  const _Pulse({required this.theme, required this.active});

  final PeekTheme theme;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? theme.success : theme.cancelled;
    return SizedBox(
      width: PeekRadar._centre * 2,
      height: PeekRadar._centre * 2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ],
      ),
    );
  }
}

/// The arcs, fading outward; dashed, with a dot caught on each, for a
/// filter.
class _Arcs extends CustomPainter {
  const _Arcs({
    required this.color,
    required this.origin,
    required this.dashed,
  });

  final Color color;
  final Offset origin;
  final bool dashed;

  static const List<double> _radii = [44, 80, 116];
  static const List<double> _alphas = [1, 0.6, 0.33];

  /// Where a dot sits on each arc, as an angle from the horizontal:
  /// scattered, the way a catch would be.
  static const List<double> _dots = [5.67, 3.9, 5.25];

  static const double _dash = 6;
  static const double _gap = 5;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (index, radius) in _radii.indexed) {
      final paint =
          Paint()
            ..color = color.withValues(alpha: _alphas[index])
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..strokeCap = StrokeCap.round;
      final rect = Rect.fromCircle(center: origin, radius: radius);
      if (!dashed) {
        canvas.drawArc(rect, math.pi, math.pi, false, paint);
        continue;
      }
      final dash = _dash / radius;
      final gap = _gap / radius;
      for (var angle = math.pi; angle < math.pi * 2; angle += dash + gap) {
        final sweep = math.min(dash, math.pi * 2 - angle);
        canvas.drawArc(rect, angle, sweep, false, paint);
      }
      final dot = Paint()..color = color;
      canvas.drawCircle(
        origin +
            Offset(
              math.cos(_dots[index]) * radius,
              math.sin(_dots[index]) * radius,
            ),
        4,
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(_Arcs oldDelegate) =>
      color != oldDelegate.color ||
      origin != oldDelegate.origin ||
      dashed != oldDelegate.dashed;
}
