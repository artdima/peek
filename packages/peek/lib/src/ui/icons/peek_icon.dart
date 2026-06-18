import 'package:flutter/widgets.dart';

import '../theme/peek_theme.dart';
import 'peek_icon_data.dart';

/// One of Peek's glyphs, drawn at [size] in [color].
///
/// The glyph is a path rather than a character, so it needs no font and no
/// asset, and it keeps its shape at any size.
final class PeekIcon extends StatelessWidget {
  /// Creates an icon showing [icon].
  const PeekIcon(
    this.icon, {
    this.size = 20,
    this.color,
    this.knockout,
    super.key,
  });

  /// Which glyph to draw.
  final PeekIconData icon;

  /// How large the glyph is drawn, along its longer side.
  final double size;

  /// An override for the colour; the accent otherwise.
  final Color? color;

  /// What the marks over a filled shape are drawn in — the surface behind
  /// the glyph, so they read as cut out of it. [color] otherwise.
  final Color? knockout;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? PeekTheme.of(context).accent;
    final scale = size / (icon.width > icon.height ? icon.width : icon.height);

    return SizedBox(
      width: icon.width * scale,
      height: icon.height * scale,
      child: CustomPaint(
        painter: _PeekIconPainter(
          icon: icon,
          color: tint,
          knockout: knockout ?? tint,
        ),
      ),
    );
  }
}

class _PeekIconPainter extends CustomPainter {
  const _PeekIconPainter({
    required this.icon,
    required this.color,
    required this.knockout,
  });

  final PeekIconData icon;
  final Color color;
  final Color knockout;

  @override
  void paint(Canvas canvas, Size size) {
    final marks = Paint()..color = icon.filled > 0 ? knockout : color;
    if (icon.strokeWidth > 0) {
      marks
        ..style = PaintingStyle.stroke
        ..strokeWidth = icon.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
    }

    canvas
      ..save()
      ..scale(size.width / icon.width, size.height / icon.height)
      ..drawPath(icon.solid, Paint()..color = color)
      ..drawPath(icon.stroked, marks)
      ..restore();
  }

  @override
  bool shouldRepaint(_PeekIconPainter oldDelegate) =>
      oldDelegate.icon != icon ||
      oldDelegate.color != color ||
      oldDelegate.knockout != knockout;
}
