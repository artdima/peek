import 'package:flutter/widgets.dart';

/// The coloured dot that opens a row, standing for its outcome.
final class PeekStatusDot extends StatelessWidget {
  /// Creates a dot in [color].
  const PeekStatusDot(this.color, {this.size = 8, super.key});

  /// What the dot stands for.
  final Color color;

  /// How wide the dot is.
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
