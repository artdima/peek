import 'package:chopper/chopper.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:peek/peek.dart';
import 'package:talker/talker.dart';

import 'chopper_setup.dart';
import 'dio_setup.dart';
import 'http_setup.dart';
import 'talker_setup.dart';

/// Which of the four ways of reporting a call is in use.
enum ExampleRoute {
  /// Peek's own interceptor on a Dio client.
  dio('peek_dio'),

  /// Talker logs the call and Peek reads its log.
  talker('peek_talker'),

  /// Peek's own interceptor in a Chopper chain.
  chopper('peek_chopper'),

  /// Peek's client wrapped around a `package:http` one.
  http('peek_http');

  const ExampleRoute(this.label);

  /// What the switch reads.
  final String label;
}

/// The clients the example offers, built once and shared.
///
/// Each reports through a different route. They are deliberately separate
/// clients: a call reported by two routes would show up twice.
final class ExampleClients {
  /// Builds every client over [peek].
  ExampleClients(Peek peek)
    : talker = Talker(),
      _direct = buildDio(peek: peek),
      chopper = buildChopperClient(peek: peek),
      httpClient = buildHttpClient(peek: peek) {
    _logged = buildLoggedDio(peek: peek, talker: talker);
  }

  /// The logger the second client writes to.
  final Talker talker;

  /// The client of the Chopper route.
  final ChopperClient chopper;

  /// The client of the `package:http` route.
  final http.Client httpClient;

  final Dio _direct;
  late final Dio _logged;

  /// The Dio client behind [route]; the other routes have [chopper] and
  /// [httpClient].
  Dio dioOf(ExampleRoute route) =>
      route == ExampleRoute.talker ? _logged : _direct;

  /// Releases every client.
  void dispose() {
    _direct.close();
    _logged.close();
    chopper.dispose();
    httpClient.close();
  }
}
