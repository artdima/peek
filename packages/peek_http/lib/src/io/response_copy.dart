import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../plain_response_copy.dart';

/// [response] with its body replaced by [stream], still an
/// [IOStreamedResponse] when it was one, so `detachSocket` keeps working.
http.StreamedResponse copyResponse(
  http.StreamedResponse response,
  Stream<List<int>> stream,
) => switch (response) {
  final IOStreamedResponse io && http.BaseResponseWithUrl(:final url) =>
    _IOStreamedResponseWithUrl(stream, io, url),
  final IOStreamedResponse io => _IOStreamedResponse(stream, io),
  _ => copyPlainResponse(response, stream),
};

class _IOStreamedResponse extends IOStreamedResponse {
  _IOStreamedResponse(Stream<List<int>> stream, IOStreamedResponse original)
    : _original = original,
      super(
        stream,
        original.statusCode,
        contentLength: original.contentLength,
        request: original.request,
        headers: original.headers,
        isRedirect: original.isRedirect,
        persistentConnection: original.persistentConnection,
        reasonPhrase: original.reasonPhrase,
      );

  final IOStreamedResponse _original;

  @override
  Future<Socket> detachSocket() => _original.detachSocket();
}

final class _IOStreamedResponseWithUrl extends _IOStreamedResponse
    implements http.BaseResponseWithUrl {
  _IOStreamedResponseWithUrl(super.stream, super.original, this.url);

  @override
  final Uri url;
}
