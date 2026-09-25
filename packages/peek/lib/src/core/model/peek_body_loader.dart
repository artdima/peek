import 'peek_body.dart';
import 'peek_entry.dart';
import 'peek_id.dart';

/// Which half of a call a body belongs to.
enum PeekBodySide {
  /// The body the app sent.
  request,

  /// The body that came back.
  response,
}

/// Fetches a [PeekRemoteBody] from wherever it is held.
///
/// Peek cannot fetch one itself; the screen that shows calls from elsewhere
/// hands a loader to `PeekScreen`, which offers to load such bodies and puts
/// what comes back into the store, so a body is loaded once.
///
/// ```dart
/// PeekScreen(
///   bodyLoader: PeekBodyLoader.from((id, side) => device.fetchBody(id, side)),
/// )
/// ```
abstract interface class PeekBodyLoader {
  /// Creates a loader from a function.
  factory PeekBodyLoader.from(
    Future<PeekBody> Function(PeekId id, PeekBodySide side) load,
  ) = _CallbackBodyLoader;

  /// The body of the call with [id] on [side]; throws when it cannot be had.
  Future<PeekBody> load(PeekId id, PeekBodySide side);
}

final class _CallbackBodyLoader implements PeekBodyLoader {
  const _CallbackBodyLoader(this._load);

  final Future<PeekBody> Function(PeekId id, PeekBodySide side) _load;

  @override
  Future<PeekBody> load(PeekId id, PeekBodySide side) => _load(id, side);
}

/// Reaching a body by its side.
extension PeekEntryBodies on PeekEntry {
  /// The body on [side]; `null` for a response that has not arrived.
  PeekBody? bodyOn(PeekBodySide side) => switch (side) {
    PeekBodySide.request => request.body,
    PeekBodySide.response => response?.body,
  };

  /// A copy with [body] on [side]; unchanged when there is no response to
  /// hold a response body.
  PeekEntry withBody(PeekBodySide side, PeekBody body) => switch (side) {
    PeekBodySide.request => copyWith(request: request.copyWith(body: body)),
    PeekBodySide.response => switch (response) {
      final held? => copyWith(response: held.copyWith(body: body)),
      null => this,
    },
  };
}
