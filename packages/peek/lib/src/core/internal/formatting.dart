/// A byte count as B, KB or MB with at most one decimal.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${_trim(bytes / 1024)} KB';
  return '${_trim(bytes / (1024 * 1024))} MB';
}

/// A duration as ms, s or m, coarser as it grows.
String formatDuration(Duration duration) {
  final micros = duration.inMicroseconds;
  if (micros < 1000) return '$micros µs';
  if (micros < 1000 * 1000) return '${_trim(micros / 1000)} ms';
  if (duration.inSeconds < 60) return '${_trim(micros / 1000000)} s';
  final minutes = duration.inMinutes;
  return '${minutes}m ${duration.inSeconds - minutes * 60}s';
}

String _trim(double value) {
  final rounded = (value * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1);
}
