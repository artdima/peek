import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:chopper/chopper.dart';
import 'package:http/http.dart' as http;
import 'package:peek/core.dart';

/// Turns Chopper's objects into Peek's, and nothing else.
///
/// Every function here is pure: it reads what Chopper hands over and returns
/// a value. What is kept, redacted, truncated or shown is Peek's to decide —
/// an adapter that starts deciding is an adapter that disagrees with the
/// next one.
///
/// By the time an interceptor runs, the converter has already done its work:
/// the request carries the body that goes on the wire and the URL Chopper is
/// about to call. That is what is mapped here, rather than what the calling
/// code wrote.
abstract final class PeekChopperMapper {
  /// The client label put in [PeekRequest.extra] under `client`.
  static const String client = 'chopper';

  /// Maps a request onto Peek's.
  static PeekRequest request(Request value) => PeekRequest(
    method: value.method,
    uri: value.url,
    headers: PeekHeaders.fromMap(value.headers),
    body: requestBody(value),
    extra: {'client': client, if (value.tag case final tag?) 'tag': '$tag'},
  );

  /// Maps a response onto Peek's, reading the `package:http` response under
  /// it rather than the value the converter produced: a failed call has no
  /// converted body at all, and the bytes the server sent are the point.
  static PeekResponse response(Response<dynamic> value) => PeekResponse(
    statusCode: value.statusCode,
    statusMessage: _trimmed(value.base.reasonPhrase),
    headers: PeekHeaders.fromMap(value.headers),
    body: responseBody(value),
  );

  /// Maps an error thrown out of the chain onto a failure.
  static PeekFailure failure(Object error, StackTrace stackTrace) =>
      PeekFailure(
        kind: failureKind(error),
        message: '$error',
        details: error,
        stackTrace: stackTrace,
      );

  /// Sorts an error into one of Peek's kinds.
  ///
  /// Cancellation is asked about first: `RequestAbortedException` is itself a
  /// `ClientException`, and the other order would call every abort a broken
  /// connection. A refused certificate is not separable here — `package:http`
  /// reports it as a `ClientException` like any other transport failure.
  static PeekFailureKind failureKind(Object error) => switch (error) {
    http.RequestAbortedException() => PeekFailureKind.cancelled,
    TimeoutException() => PeekFailureKind.timeout,
    http.ClientException() => PeekFailureKind.connection,
    ChopperHttpException() => PeekFailureKind.badResponse,
    _ => PeekFailureKind.unknown,
  };

  /// The answer an error carries, when it carries one.
  static PeekResponse? responseOf(Object error) =>
      error is ChopperHttpException ? response(error.response) : null;

  /// The body of a request, by what Chopper was given to send.
  static PeekBody requestBody(Request value) {
    final type = PeekMediaType.tryParse(value.headers['content-type']);
    if (value.multipart) return _parts(value.parts, type);

    return switch (value.body) {
      null => const PeekBody.empty(),
      final String text => PeekBody.text(text, contentType: type),
      final Uint8List bytes => PeekBody.bytes(bytes, contentType: type),
      final List<int> bytes => PeekBody.bytes(
        Uint8List.fromList(bytes),
        contentType: type,
      ),
      final Stream<dynamic> _ => PeekBody.unavailable(
        PeekBodyUnavailableReason.streamed,
        contentType: type,
      ),
      final Object data => PeekBody.fromJsonLike(data, contentType: type),
    };
  }

  /// The body of a response, as the server sent it.
  static PeekBody responseBody(Response<dynamic> value) {
    final type = PeekMediaType.tryParse(value.headers['content-type']);
    final base = value.base;

    if (base is http.StreamedResponse) {
      return PeekBody.unavailable(
        PeekBodyUnavailableReason.streamed,
        contentType: type,
      );
    }
    if (base is http.Response) {
      final bytes = base.bodyBytes;
      return bytes.isEmpty ? const PeekBody.empty() : _decoded(bytes, type);
    }

    // A response of some other shape: the converted value is all there is,
    // and on a failure it sits in `error` rather than in `body`.
    final data = value.body ?? value.error;
    return switch (data) {
      null => const PeekBody.empty(),
      final String text => PeekBody.text(text, contentType: type),
      final Object value => PeekBody.fromJsonLike(value, contentType: type),
    };
  }

  /// Describes multipart parts without opening a single file.
  static PeekBody _parts(
    List<PartValue<dynamic>> parts,
    PeekMediaType? contentType,
  ) {
    final fields = <PeekFormField>[];
    final files = <PeekFormFile>[];

    for (final part in parts) {
      switch (part.value) {
        case final http.MultipartFile file:
          files.add(
            PeekFormFile(
              part.name,
              filename: file.filename,
              contentType: PeekMediaType.tryParse('${file.contentType}'),
              size: file.length,
            ),
          );
        case final List<int> bytes when part is PartValueFile:
          files.add(PeekFormFile(part.name, size: bytes.length));
        case final String path when part is PartValueFile:
          files.add(PeekFormFile(part.name, filename: path));
        case final value:
          fields.add(PeekFormField(part.name, '$value'));
      }
    }

    return PeekBody.form(
      contentType: contentType ?? PeekMediaType.multipartFormData,
      fields: fields,
      files: files,
    );
  }

  // Text is worth more than a hex dump, so bytes that decode as UTF-8 are
  // shown as text unless the media type says they are something else.
  static PeekBody _decoded(Uint8List bytes, PeekMediaType? type) {
    if (type != null && !type.isText && !type.isJson) {
      return PeekBody.bytes(bytes, contentType: type);
    }
    try {
      return PeekBody.text(utf8.decode(bytes), contentType: type);
    } on FormatException {
      return PeekBody.bytes(bytes, contentType: type);
    }
  }

  static String? _trimmed(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}
