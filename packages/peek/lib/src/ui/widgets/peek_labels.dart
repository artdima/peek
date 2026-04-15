import 'package:flutter/material.dart';

import '../peek_scope.dart';
import '../theme/peek_theme.dart';

/// How long a call took, or a dash while it is still running.
final class PeekDurationLabel extends StatelessWidget {
  /// Creates a label for [duration].
  const PeekDurationLabel(this.duration, {this.style, super.key});

  /// The duration, or `null` while the call is in flight.
  final Duration? duration;

  /// An override for the text style.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final strings = PeekScope.stringsOf(context);
    final value = duration;
    return Text(
      value == null ? strings.none : strings.elapsed(value),
      style: style ?? _secondaryStyle(context),
    );
  }
}

/// A size in bytes, or a dash when it is unknown.
final class PeekSizeLabel extends StatelessWidget {
  /// Creates a label for [bytes].
  const PeekSizeLabel(this.bytes, {this.style, super.key});

  /// The size, or `null` when Peek does not know it.
  final int? bytes;

  /// An override for the text style.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final strings = PeekScope.stringsOf(context);
    final value = bytes;
    return Text(
      value == null ? strings.none : strings.bytes(value),
      style: style ?? _secondaryStyle(context),
    );
  }
}

/// A moment, as a wall-clock time.
final class PeekTimeLabel extends StatelessWidget {
  /// Creates a label for [time]; [withMillis] adds the fraction.
  const PeekTimeLabel(
    this.time, {
    this.withMillis = false,
    this.style,
    super.key,
  });

  /// The moment to show, in local time.
  final DateTime time;

  /// Whether to show milliseconds too.
  final bool withMillis;

  /// An override for the text style.
  final TextStyle? style;

  /// [time] as `HH:mm:ss`, with `.SSS` when [withMillis].
  String format() {
    final local = time.toLocal();
    final base =
        '${_two(local.hour)}:${_two(local.minute)}:${_two(local.second)}';
    if (!withMillis) return base;
    return '$base.${local.millisecond.toString().padLeft(3, '0')}';
  }

  @override
  Widget build(BuildContext context) =>
      Text(format(), style: style ?? _secondaryStyle(context));

  static String _two(int value) => value.toString().padLeft(2, '0');
}

TextStyle _secondaryStyle(BuildContext context) {
  final theme = PeekTheme.of(context);
  return theme.caption.copyWith(color: theme.secondaryLabel);
}
