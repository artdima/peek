import 'package:dio/dio.dart';
import 'package:peek/peek.dart';
import 'package:peek_dio/peek_dio.dart';

/// Builds a client that reports into [peek], or into [Peek.instance].
///
/// This is the setup `peek_dio`'s README shows, kept here so the compiler
/// reads it too: a snippet that stops compiling is a snippet that lies.
Dio buildDio({Peek? peek}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
  dio.interceptors.add(PeekDioInterceptor(peek ?? Peek.instance));
  return dio;
}
