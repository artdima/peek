import 'package:http/http.dart' as http;
import 'package:peek/peek.dart';
import 'package:peek_http/peek_http.dart';

/// Builds a client that reports into [peek], or into [Peek.instance].
///
/// This is the setup `peek_http`'s README shows, kept here so the compiler
/// reads it too.
http.Client buildHttpClient({Peek? peek}) =>
    PeekHttpClient(peek ?? Peek.instance, http.Client());
