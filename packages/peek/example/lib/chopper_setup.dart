import 'package:chopper/chopper.dart';
import 'package:peek/peek.dart';
import 'package:peek_chopper/peek_chopper.dart';

/// Builds a client that reports into [peek], or into [Peek.instance].
///
/// This is the setup `peek_chopper`'s README shows, kept here so the
/// compiler reads it too: a snippet that stops compiling is a snippet that
/// lies.
ChopperClient buildChopperClient({Peek? peek}) => ChopperClient(
  baseUrl: Uri.parse('https://api.example.com'),
  interceptors: [PeekChopperInterceptor(peek ?? Peek.instance)],
  converter: const JsonConverter(),
);
