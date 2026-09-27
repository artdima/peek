import 'dart:async';

import 'package:bonsoir/bonsoir.dart';
import 'package:meta/meta.dart';

import 'peek_remote_discovery.dart';

/// [PeekRemoteDiscovery] over `bonsoir`: one browse per listener.
@internal
final class BonjourDiscovery implements PeekRemoteDiscovery {
  /// Creates the discovery; nothing is browsed until someone listens.
  BonjourDiscovery();

  @override
  Stream<List<PeekRemoteDiscovered>> watch() {
    final desktops = DiscoveredDesktops();
    BonsoirDiscovery? discovery;
    StreamSubscription<BonsoirDiscoveryEvent>? events;
    late final StreamController<List<PeekRemoteDiscovered>> controller;

    Future<void> begin() async {
      try {
        final browser = discovery = BonsoirDiscovery(
          type: PeekRemoteDiscovery.serviceType,
          printLogs: false,
        );
        await browser.initialize();
        if (controller.isClosed) return;
        controller.add(const []);
        events = browser.eventStream?.listen(
          (event) => _handle(event, browser, desktops, controller),
          onError: controller.addError,
        );
        await browser.start();
      } on Object catch (error, stackTrace) {
        if (!controller.isClosed) controller.addError(error, stackTrace);
      }
    }

    Future<void> end() async {
      await events?.cancel();
      try {
        await discovery?.stop();
      } on Object {
        // Stopping a browse that never started is not worth reporting.
      }
    }

    controller = StreamController(
      onListen: () => unawaited(begin()),
      onCancel: end,
    );
    return controller.stream;
  }

  static void _handle(
    BonsoirDiscoveryEvent event,
    BonsoirDiscovery browser,
    DiscoveredDesktops desktops,
    StreamController<List<PeekRemoteDiscovered>> controller,
  ) {
    if (controller.isClosed) return;
    switch (event) {
      case BonsoirDiscoveryServiceFoundEvent(:final service):
        unawaited(service.resolve(browser.serviceResolver));
      case BonsoirDiscoveryServiceResolvedEvent(:final service) ||
          BonsoirDiscoveryServiceUpdatedEvent(:final service):
        final changed = desktops.found(
          name: service.name,
          addresses: service.hostAddresses,
          hostname: service.hostname,
          port: service.port,
          attributes: service.attributes,
        );
        if (changed) controller.add(desktops.list);
      case BonsoirDiscoveryServiceLostEvent(:final service):
        if (desktops.lost(service.name)) controller.add(desktops.list);
      default:
        break;
    }
  }
}
