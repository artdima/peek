// Peek reads the calls Talker already logs: one adapter next to the Talker
// an app has, and the loggers it already runs feed Peek unchanged. This is
// a Dart script so it can run anywhere; the full app is under
// `packages/peek/example`.

import 'package:dio/dio.dart';
import 'package:peek/core.dart';
import 'package:peek_talker/peek_talker.dart';
import 'package:talker/talker.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';

/// Lets Peek see what Talker logged, before and after it was attached.
Future<void> main() async {
  final talker = Talker();
  final dio = Dio()..interceptors.add(TalkerDioLogger(talker: talker));

  // Logged before Peek exists: replayed from Talker's history on attach.
  await dio.get<dynamic>('https://httpbin.org/get');

  final peek = Peek();
  peek.attach(PeekTalkerAdapter(peek, talker: talker));

  // Logged after: reported live, through Talker's stream.
  await dio.get<dynamic>('https://httpbin.org/uuid');

  // The stream delivers asynchronously; give it a turn of the event loop.
  await Future<void>.delayed(Duration.zero);
  assert(peek.store.length == 2, 'both calls are in the store');

  peek.dispose();
}
