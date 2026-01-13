/// Source of the current time for everything Peek timestamps.
///
/// Inject a [PeekFakeClock] in tests to make timings deterministic.
abstract interface class PeekClock {
  /// The current moment.
  DateTime now();
}

/// The wall clock.
final class PeekSystemClock implements PeekClock {
  /// Creates a clock backed by [DateTime.now].
  const PeekSystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// A clock that only moves when told to.
final class PeekFakeClock implements PeekClock {
  /// Creates a clock stopped at [start], or at a fixed date when omitted.
  PeekFakeClock([DateTime? start]) : _now = start ?? DateTime.utc(2026);

  DateTime _now;

  @override
  DateTime now() => _now;

  /// Moves the clock by [duration].
  void advance(Duration duration) {
    _now = _now.add(duration);
  }
}
