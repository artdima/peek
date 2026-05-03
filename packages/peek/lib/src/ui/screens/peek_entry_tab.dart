/// Which part of a call the detail screen is showing.
///
/// [error] and [timing] are offered only when the call has that to show.
enum PeekEntryTab {
  /// How the call went, in summary.
  overview,

  /// What was asked.
  request,

  /// What came back.
  response,

  /// What stopped it.
  error,

  /// Where the time went.
  timing,
}
