import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:peek/core.dart';

/// Turns `package:http` objects into Peek's, and nothing else.
///
/// Every function here is pure: what is kept, redacted, truncated or shown
/// is Peek's to decide.
abstract final class PeekHttpMapper {
  /// The client label put in [PeekRequest.extra] under `client`.
  static const String client = 'http';

  /// Maps a request onto Peek's, as it stands before it is sent.
  static PeekRequest request(http.BaseRequest value) => PeekRequest(
    method: value.method,
    uri: value.url,
    headers: PeekHeaders.fromMap(value.headers),
    body: requestBody(value),
    extra: const {'client': client},
  );

  /// The body of a request, described without finalizing it.
  ///
  /// Finalizing belongs to the client that sends the request, and a
  /// multipart file's stream can be read only once.
  static PeekBody requestBody(http.BaseRequest value) {
    final type = PeekMediaType.tryParse(value.headers['content-type']);
    return switch (value) {
      // `body` decodes with the declared charset and throws on one it does
      // not know; the bytes are what goes out either way.
      http.Request(:final bodyBytes) =>
        bodyBytes.isEmpty
            ? const PeekBody.empty()
            : _decoded(bodyBytes, type, size: bodyBytes.length),
      http.MultipartRequest() => _form(value),
      http.StreamedRequest() => PeekBody.unavailable(
        PeekBodyUnavailableReason.streamed,
        contentType: type,
        size: value.contentLength,
      ),
      _ => PeekBody.unavailable(
        PeekBodyUnavailableReason.notCaptured,
        contentType: type,
        size: value.contentLength,
      ),
    };
  }

  /// Maps a response onto Peek's, with the [body] that was read from it.
  static PeekResponse response(http.BaseResponse value, PeekBody body) =>
      PeekResponse(
        statusCode: value.statusCode,
        statusMessage: _trimmed(value.reasonPhrase),
        // The folded map loses the boundaries between Set-Cookie values,
        // whose dates carry commas of their own.
        headers: PeekHeaders.fromMultiMap(value.headersSplitValues),
        body: body,
      );

  /// The body of [value] from the first bytes that arrived — [captured] —
  /// and the count of all of them, [received].
  ///
  /// The size is [received], not `contentLength`: for a body that arrived
  /// unzipped, that one is the size on the wire.
  static PeekBody responseBody(
    http.BaseResponse value,
    List<int> captured, {
    required int received,
  }) {
    if (received == 0) return const PeekBody.empty();
    final type = PeekMediaType.tryParse(value.headers['content-type']);
    return _decoded(captured, type, size: received);
  }

  /// Maps an error out of `send` or out of the body stream onto a failure.
  static PeekFailure failure(Object error, StackTrace stackTrace) =>
      PeekFailure(
        kind: failureKind(error),
        message: '$error',
        details: error,
        stackTrace: stackTrace,
      );

  /// Sorts an error into one of Peek's kinds.
  ///
  /// An abort is asked about first: `RequestAbortedException` is itself a
  /// `ClientException`. A refused certificate is not separable here.
  static PeekFailureKind failureKind(Object error) => switch (error) {
    http.RequestAbortedException() => PeekFailureKind.cancelled,
    TimeoutException() => PeekFailureKind.timeout,
    http.ClientException() => PeekFailureKind.connection,
    _ => PeekFailureKind.unknown,
  };

  // The boundary is chosen in `finalize`, so before sending there is no
  // content-type to read.
  static PeekBody _form(http.MultipartRequest value) => PeekBody.form(
    contentType: PeekMediaType.multipartFormData,
    fields: [
      for (final MapEntry(:key, value: text) in value.fields.entries)
        PeekFormField(key, text),
    ],
    files: [
      for (final file in value.files)
        PeekFormFile(
          file.field,
          filename: file.filename,
          contentType: PeekMediaType.tryParse('${file.contentType}'),
          size: file.length,
        ),
    ],
  );

  static PeekBody _decoded(
    List<int> bytes,
    PeekMediaType? type, {
    required int size,
  }) {
    final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    if (type != null && !type.isText && !type.isJson) {
      return PeekBody.bytes(data, contentType: type, size: size);
    }
    final text = _utf8(data, truncated: size > data.length);
    return text == null
        ? PeekBody.bytes(data, contentType: type, size: size)
        : PeekBody.text(text, contentType: type, size: size);
  }

  // A prefix may end inside a character; up to three trailing bytes are the
  // rest of it, not a sign that the body is binary.
  static String? _utf8(Uint8List bytes, {required bool truncated}) {
    final spare = truncated ? 3 : 0;
    for (var cut = 0; cut <= spare && cut <= bytes.length; cut++) {
      try {
        return utf8.decode(Uint8List.sublistView(bytes, 0, bytes.length - cut));
      } on FormatException {
        continue;
      }
    }
    return null;
  }

  static String? _trimmed(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}
