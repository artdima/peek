/// An adapter that feeds a logger's output into Peek.
///
/// Implementing this is optional — an adapter only needs a `PeekSink` to
/// report into — but it lets Peek list active sources and release them
/// together.
abstract interface class PeekAdapter {
  /// A short name for the source, such as `dio` or `talker`.
  String get name;

  /// Stops observing and releases subscriptions. Safe to call twice.
  void dispose();
}
