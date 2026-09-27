import 'dart:async';

import 'package:peek_remote/peek_remote.dart';

/// A network the test fills by hand.
final class FakeDiscovery implements PeekRemoteDiscovery {
  // Lives as long as the test; nothing to release.
  // ignore: close_sinks
  final StreamController<List<PeekRemoteDiscovered>> _found =
      StreamController.broadcast();

  /// How many are listening now.
  int listeners = 0;

  @override
  Stream<List<PeekRemoteDiscovered>> watch() {
    StreamSubscription<List<PeekRemoteDiscovered>>? source;
    // Closed with the listener's cancel; the analyzer cannot follow that.
    // ignore: close_sinks
    final controller = StreamController<List<PeekRemoteDiscovered>>();
    controller
      ..onListen = () {
        listeners++;
        source = _found.stream.listen(controller.add);
      }
      ..onCancel = () async {
        listeners--;
        await source?.cancel();
        await controller.close();
      };
    return controller.stream;
  }

  /// The network now holds [desktops].
  void show(List<PeekRemoteDiscovered> desktops) => _found.add(desktops);
}
