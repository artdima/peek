import 'package:dio/dio.dart';
import 'package:peek/peek.dart';
import 'package:talker/talker.dart';

import 'dio_setup.dart';
import 'talker_setup.dart';

/// Which of the two ways of reporting a call is in use.
enum ExampleRoute {
  /// Peek's own interceptor on the client.
  dio('peek_dio'),

  /// Talker logs the call and Peek reads its log.
  talker('peek_talker');

  const ExampleRoute(this.label);

  /// What the switch reads.
  final String label;
}

/// The two clients the example offers, built once and shared.
///
/// One reports through `PeekDioInterceptor`, the other through Talker and
/// `PeekTalkerAdapter`. They are deliberately separate clients: a call
/// reported by both routes would show up twice.
final class ExampleClients {
  /// Builds both clients over [peek].
  ExampleClients(Peek peek)
    : talker = Talker(),
      _direct = buildDio(peek: peek) {
    _logged = buildLoggedDio(peek: peek, talker: talker);
  }

  /// The logger the second client writes to.
  final Talker talker;

  final Dio _direct;
  late final Dio _logged;

  /// The client that reports [route].
  Dio of(ExampleRoute route) => route == ExampleRoute.dio ? _direct : _logged;

  /// Releases both clients.
  void dispose() {
    _direct.close();
    _logged.close();
  }
}
