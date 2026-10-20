import 'package:flutter/widgets.dart';

/// The cut of a shoe, which decides its outline.
enum SneakerShape {
  /// A running shoe on a thick, rockered midsole.
  runner,

  /// A low lifestyle shoe on a flat cupsole.
  low,

  /// A high-top court shoe with a strap across the ankle.
  high,
}

/// The colours a pair comes in.
@immutable
final class SneakerColors {
  /// Creates a colourway.
  const SneakerColors({
    required this.upper,
    required this.accent,
    required this.sole,
    required this.outsole,
    required this.lace,
  });

  /// Reads a colourway from hex strings: `{"upper": "#1C1C1E", ...}`.
  factory SneakerColors.fromJson(Map<String, Object?> json) {
    Color read(String key) => Color(
      int.parse((json[key]! as String).substring(1), radix: 16) | 0xFF000000,
    );
    return SneakerColors(
      upper: read('upper'),
      accent: read('accent'),
      sole: read('sole'),
      outsole: read('outsole'),
      lace: read('lace'),
    );
  }

  /// Most of the shoe above the sole.
  final Color upper;

  /// The heel, the saddle and the pull tab.
  final Color accent;

  /// The midsole.
  final Color sole;

  /// The rubber under it.
  final Color outsole;

  /// The laces.
  final Color lace;

  @override
  bool operator ==(Object other) =>
      other is SneakerColors &&
      other.upper == upper &&
      other.accent == accent &&
      other.sole == sole &&
      other.outsole == outsole &&
      other.lace == lace;

  @override
  int get hashCode => Object.hash(upper, accent, sole, outsole, lace);
}

/// A sneaker drawn side on, toe to the right, as a product photo would
/// show it; the shop has no photos to show.
class Sneaker extends StatelessWidget {
  /// Draws [shape] in [colors].
  const Sneaker({required this.shape, required this.colors, super.key});

  /// The outline.
  final SneakerShape shape;

  /// The colours.
  final SneakerColors colors;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: _Outline.width / _Outline.height,
    child: CustomPaint(painter: _SneakerPainter(_outlines[shape]!, colors)),
  );
}

class _SneakerPainter extends CustomPainter {
  const _SneakerPainter(this.outline, this.colors);

  final _Outline outline;
  final SneakerColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / _Outline.width, size.height / _Outline.height);

    final accent = Paint()..color = colors.accent;
    canvas
      ..drawOval(
        Rect.fromCenter(center: const Offset(210, 216), width: 360, height: 16),
        Paint()..color = const Color(0x1A000000),
      )
      ..drawPath(outline.upper, Paint()..color = colors.upper)
      ..drawPath(outline.shade, Paint()..color = const Color(0x14000000))
      ..drawPath(outline.lining, Paint()..color = const Color(0x4D000000))
      ..drawPath(outline.heel, accent)
      ..drawPath(outline.saddle, accent)
      ..drawPath(outline.tab, accent);

    if (outline.dots case (final left, final top)) {
      final dot = Paint()..color = const Color(0x40000000);
      for (var row = 0; row < 2; row++) {
        for (var column = 0; column < 4; column++) {
          canvas.drawCircle(
            Offset(left + column * 10, top + row * 7),
            1.6,
            dot,
          );
        }
      }
    }

    final lace =
        Paint()
          ..color = colors.lace
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round;
    for (final (x1, y1, x2, y2) in outline.laces) {
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), lace);
    }

    canvas
      ..drawPath(outline.midsole, Paint()..color = colors.sole)
      ..drawPath(outline.outsole, Paint()..color = colors.outsole);

    final stitch =
        Paint()
          ..color = const Color(0x2E000000)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
    for (final metric in outline.stitch.computeMetrics()) {
      for (var at = 0.0; at < metric.length; at += 6) {
        canvas.drawPath(metric.extractPath(at, at + 3), stitch);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_SneakerPainter oldDelegate) =>
      oldDelegate.outline != outline || oldDelegate.colors != colors;
}

/// One shape's parts, in a 400 × 240 box; the paths read as SVG path data,
/// absolute commands only.
final class _Outline {
  _Outline({
    required String upper,
    required String shade,
    required String lining,
    required String heel,
    required String saddle,
    required String tab,
    required String midsole,
    required String outsole,
    required String stitch,
    required this.laces,
    this.dots,
  }) : upper = _parse(upper),
       shade = _parse(shade),
       lining = _parse(lining),
       heel = _parse(heel),
       saddle = _parse(saddle),
       tab = _parse(tab),
       midsole = _parse(midsole),
       outsole = _parse(outsole),
       stitch = _parse(stitch);

  static const double width = 400;
  static const double height = 240;

  final Path upper;
  final Path shade;
  final Path lining;
  final Path heel;
  final Path saddle;
  final Path tab;
  final Path midsole;
  final Path outsole;
  final Path stitch;
  final List<(double, double, double, double)> laces;

  /// The top left of two rows of perforations on the toe, where there are
  /// any.
  final (double, double)? dots;

  static Path _parse(String data) {
    final path = Path();
    final tokens = data.split(' ');
    var i = 0;
    double next() => double.parse(tokens[i++]);
    while (i < tokens.length) {
      switch (tokens[i++]) {
        case 'M':
          path.moveTo(next(), next());
        case 'L':
          path.lineTo(next(), next());
        case 'C':
          path.cubicTo(next(), next(), next(), next(), next(), next());
        case 'Z':
          path.close();
      }
    }
    return path;
  }
}

final Map<SneakerShape, _Outline> _outlines = {
  SneakerShape.runner: _Outline(
    upper:
        'M 44 166 C 36 150 34 124 40 106 C 44 94 52 88 62 88 C 78 90 '
        '92 102 110 104 C 126 106 138 96 148 84 C 154 74 158 64 166 '
        '60 C 174 56 184 58 186 66 C 206 94 248 118 300 128 C 340 136 '
        '374 146 386 166 L 388 182 L 44 182 Z',
    shade: 'M 250 168 C 290 166 340 168 386 176 L 386 182 L 250 182 Z',
    lining:
        'M 60 90 C 76 92 92 102 110 104 C 126 106 138 96 148 84 L 151 '
        '90 C 141 104 127 113 110 112 C 92 111 76 100 60 97 Z',
    heel:
        'M 44 166 C 36 150 34 124 40 106 C 44 96 50 92 58 92 C 72 116 '
        '86 142 96 168 Z',
    saddle:
        'M 204 84 C 220 110 226 140 224 172 L 262 172 C 262 144 252 '
        '118 238 104 Z',
    tab:
        'M 50 96 L 54 74 C 55 70 58 69 62 70 L 68 72 C 71 73 72 76 71 '
        '79 L 64 98 Z',
    midsole:
        'M 28 168 C 28 160 34 156 44 156 C 120 160 220 170 300 174 C '
        '340 176 372 172 392 164 C 397 172 394 184 386 192 C 374 202 '
        '352 206 330 206 L 52 206 C 36 206 26 196 26 184 C 26 178 26 '
        '172 28 168 Z',
    outsole:
        'M 26 192 C 30 202 40 206 52 206 L 330 206 C 352 206 374 202 '
        '386 192 L 390 196 C 380 208 356 213 330 213 L 52 213 C 36 '
        '213 26 206 24 196 Z',
    stitch: 'M 60 186 C 140 190 240 194 330 192',
    laces: [
      (194, 84, 204, 75),
      (212, 96, 222, 87),
      (230, 106, 240, 97),
      (248, 115, 258, 106),
      (266, 122, 276, 113),
    ],
  ),
  SneakerShape.low: _Outline(
    upper:
        'M 46 190 C 38 170 38 140 46 122 C 52 112 62 110 72 112 C 92 '
        '118 110 124 128 120 C 140 116 150 104 160 96 C 166 90 174 88 '
        '180 92 C 206 112 248 130 296 138 C 338 146 374 156 384 178 L '
        '386 192 L 46 192 Z',
    shade: 'M 240 176 C 290 174 340 176 384 182 L 384 192 L 240 192 Z',
    lining:
        'M 64 113 C 88 118 110 124 128 120 C 140 116 150 104 160 96 L '
        '163 102 C 152 114 142 126 128 127 C 108 129 88 122 64 119 Z',
    heel:
        'M 46 190 C 38 170 38 140 46 122 C 50 116 56 113 62 113 C 66 '
        '140 70 166 78 190 Z',
    saddle:
        'M 172 98 C 206 118 248 134 296 142 L 298 154 C 246 148 200 '
        '130 166 108 Z',
    tab:
        'M 50 120 L 52 104 C 53 100 56 99 60 100 L 66 101 C 69 102 70 '
        '105 69 108 L 66 122 Z',
    midsole:
        'M 32 200 C 32 188 36 182 44 182 L 372 182 C 386 182 394 190 '
        '394 200 L 394 204 C 394 210 390 213 384 213 L 42 213 C 36 '
        '213 32 209 32 204 Z',
    outsole:
        'M 32 203 L 394 203 L 394 205 C 394 210 390 213 384 213 L 42 '
        '213 C 36 213 32 209 32 205 Z',
    stitch: 'M 300 150 C 330 156 360 162 376 172',
    laces: [
      (186, 96, 196, 90),
      (202, 108, 212, 101),
      (219, 118, 228, 111),
      (236, 127, 245, 120),
      (253, 135, 262, 128),
    ],
    dots: (330, 168),
  ),
  SneakerShape.high: _Outline(
    upper:
        'M 48 186 C 40 160 40 100 46 60 C 48 48 56 42 68 42 C 86 42 '
        '102 48 116 52 C 128 54 136 50 144 44 C 150 38 160 36 166 42 '
        'C 180 70 196 100 230 118 C 270 134 330 142 368 154 C 382 160 '
        '390 170 390 182 L 390 190 L 48 190 Z',
    shade: 'M 240 172 C 290 170 340 172 388 178 L 388 190 L 240 190 Z',
    lining:
        'M 66 44 C 86 44 102 50 116 54 C 128 56 136 52 144 46 L 147 '
        '53 C 137 62 127 64 114 61 C 100 57 84 51 66 50 Z',
    heel: 'M 48 186 C 40 160 40 120 44 96 C 62 104 76 130 84 186 Z',
    saddle:
        'M 92 84 L 172 66 C 176 65 179 67 180 71 L 184 86 C 185 90 '
        '183 93 179 94 L 100 112 C 96 113 93 111 92 107 Z',
    tab:
        'M 52 50 L 56 30 C 57 26 60 25 64 26 L 70 28 C 73 29 74 32 73 '
        '35 L 66 54 Z',
    midsole:
        'M 34 194 C 34 184 38 178 46 178 L 372 178 C 386 178 396 186 '
        '396 198 L 396 204 C 396 210 392 213 386 213 L 44 213 C 38 '
        '213 34 209 34 204 Z',
    outsole:
        'M 34 202 L 396 202 L 396 205 C 396 210 392 213 386 213 L 44 '
        '213 C 38 213 34 209 34 205 Z',
    stitch: 'M 250 134 C 300 148 340 152 372 160',
    laces: [
      (168, 54, 178, 47),
      (178, 72, 188, 64),
      (190, 89, 200, 81),
      (204, 103, 214, 95),
      (220, 115, 230, 107),
    ],
    dots: (318, 160),
  ),
};
