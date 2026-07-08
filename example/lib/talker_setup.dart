import 'package:dio/dio.dart';
import 'package:peek/peek.dart';
import 'package:peek_talker/peek_talker.dart';
import 'package:talker/talker.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';

/// Wires an existing [talker] into [peek], and a client into [talker].
///
/// This is the setup `peek_talker`'s README shows, kept here so the
/// compiler reads it too: a snippet that stops compiling is a snippet that
/// lies.
Dio buildLoggedDio({required Peek peek, required Talker talker}) {
  peek.attach(PeekTalkerAdapter(peek, talker: talker));

  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
  dio.interceptors.add(TalkerDioLogger(talker: talker));
  return dio;
}
