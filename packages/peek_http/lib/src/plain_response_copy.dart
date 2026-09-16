import 'package:http/http.dart' as http;

/// [response] with its body replaced by [stream] and everything else kept,
/// the final url included when the response had one.
http.StreamedResponse copyPlainResponse(
  http.StreamedResponse response,
  Stream<List<int>> stream,
) => switch (response) {
  http.BaseResponseWithUrl(:final url) => _StreamedResponseWithUrl(
    stream,
    response,
    url,
  ),
  _ => http.StreamedResponse(
    stream,
    response.statusCode,
    contentLength: response.contentLength,
    request: response.request,
    headers: response.headers,
    isRedirect: response.isRedirect,
    persistentConnection: response.persistentConnection,
    reasonPhrase: response.reasonPhrase,
  ),
};

// `http` keeps its own `StreamedResponseV2` private.
final class _StreamedResponseWithUrl extends http.StreamedResponse
    implements http.BaseResponseWithUrl {
  _StreamedResponseWithUrl(
    Stream<List<int>> stream,
    http.StreamedResponse original,
    this.url,
  ) : super(
        stream,
        original.statusCode,
        contentLength: original.contentLength,
        request: original.request,
        headers: original.headers,
        isRedirect: original.isRedirect,
        persistentConnection: original.persistentConnection,
        reasonPhrase: original.reasonPhrase,
      );

  @override
  final Uri url;
}
