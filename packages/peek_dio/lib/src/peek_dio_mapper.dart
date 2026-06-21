import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:peek/core.dart';

/// Turns Dio's objects into Peek's, and nothing else.
///
/// Every function here is pure: it reads what Dio hands over and returns a
/// value. What is kept, redacted, truncated or shown is Peek's to decide —
/// an adapter that starts deciding is an adapter that disagrees with the
/// next one.
///
/// The mapper is public because `peek_talker` maps the same objects: Talker
/// logs what Dio saw, so it would otherwise write this twice.
abstract final class PeekDioMapper {
  /// The client label put in [PeekRequest.extra] under `client`.
  static const String client = 'dio';

  /// Maps the options of a call onto a request.
  static PeekRequest request(RequestOptions options) => PeekRequest(
    method: options.method,
    uri: options.uri,
    headers: headers(options.headers),
    body: requestBody(options),
    extra: {'client': client},
  );

  /// Maps a response onto Peek's, by the type Dio was asked to decode it as.
  static PeekResponse response(Response<dynamic> value) => PeekResponse(
    statusCode: value.statusCode ?? 0,
    statusMessage: _trimmed(value.statusMessage),
    headers: PeekHeaders.fromMultiMap(value.headers.map),
    body: responseBody(value),
    redirects: [
      for (final hop in value.redirects)
        PeekRedirect(
          statusCode: hop.statusCode,
          method: hop.method,
          location: hop.location,
        ),
    ],
  );

  /// Maps an exception onto a failure, keeping the original as its details.
  static PeekFailure failure(DioException error) => PeekFailure(
    kind: failureKind(error.type),
    message: _message(error),
    details: error.error,
    stackTrace: error.stackTrace,
  );

  /// Maps Dio's category of exception onto Peek's.
  static PeekFailureKind failureKind(DioExceptionType type) => switch (type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => PeekFailureKind.timeout,
    DioExceptionType.badCertificate => PeekFailureKind.badCertificate,
    DioExceptionType.badResponse => PeekFailureKind.badResponse,
    DioExceptionType.cancel => PeekFailureKind.cancelled,
    DioExceptionType.connectionError => PeekFailureKind.connection,
    DioExceptionType.unknown => PeekFailureKind.unknown,
  };

  /// Maps Dio's loosely typed header map onto Peek's.
  ///
  /// Dio allows any value under a name: a list becomes one value per entry,
  /// anything else is read as it prints.
  static PeekHeaders headers(Map<String, dynamic> map) =>
      PeekHeaders.fromEntries([
        for (final MapEntry(:key, :value) in map.entries)
          if (value is Iterable)
            for (final one in value) MapEntry(key, '$one')
          else
            MapEntry(key, '$value'),
      ]);

  /// The body of a request, by what Dio was given to send.
  static PeekBody requestBody(RequestOptions options) {
    final type = PeekMediaType.tryParse(options.contentType);
    return switch (options.data) {
      null => const PeekBody.empty(),
      final FormData form => _form(form, type),
      final String text => PeekBody.text(text, contentType: type),
      final Uint8List bytes => PeekBody.bytes(bytes, contentType: type),
      final Stream<dynamic> _ => PeekBody.unavailable(
        PeekBodyUnavailableReason.streamed,
        contentType: type,
      ),
      final List<int> bytes => PeekBody.bytes(
        Uint8List.fromList(bytes),
        contentType: type,
      ),
      final Map<dynamic, dynamic> data => _json(data, type),
      final List<dynamic> data => _json(data, type),
      _ => PeekBody.unavailable(
        PeekBodyUnavailableReason.notCaptured,
        contentType: type,
      ),
    };
  }

  /// The body of a response, by the type Dio decoded it as.
  static PeekBody responseBody(Response<dynamic> value) {
    final type = PeekMediaType.tryParse(
      value.headers.value(Headers.contentTypeHeader),
    );
    final data = value.data;
    if (data == null) return const PeekBody.empty();

    return switch (value.requestOptions.responseType) {
      ResponseType.stream => PeekBody.unavailable(
        PeekBodyUnavailableReason.streamed,
        contentType: type,
      ),
      ResponseType.bytes => switch (data) {
        final Uint8List bytes => PeekBody.bytes(bytes, contentType: type),
        final List<int> bytes => PeekBody.bytes(
          Uint8List.fromList(bytes),
          contentType: type,
        ),
        _ => PeekBody.unavailable(
          PeekBodyUnavailableReason.unreadable,
          contentType: type,
        ),
      },
      ResponseType.plain => PeekBody.text('$data', contentType: type),
      ResponseType.json => switch (data) {
        final String text => PeekBody.text(text, contentType: type),
        _ => _json(data, type ?? PeekMediaType.json),
      },
    };
  }

  static PeekBody _form(FormData form, PeekMediaType? contentType) =>
      PeekBody.form(
        contentType: contentType ?? PeekMediaType.multipartFormData,
        fields: [
          for (final MapEntry(:key, :value) in form.fields)
            PeekFormField(key, value),
        ],
        files: [
          for (final MapEntry(key: name, value: file) in form.files)
            PeekFormFile(
              name,
              filename: file.filename,
              contentType: PeekMediaType.tryParse(file.contentType?.mimeType),
              size: file.length,
            ),
        ],
      );

  // A body Dio holds as decoded data is shown as the JSON it came from;
  // one that will not encode is worth saying nothing about rather than
  // printing an object's toString into a log.
  static PeekBody _json(Object? data, PeekMediaType? contentType) {
    try {
      return PeekBody.text(
        jsonEncode(data),
        contentType: contentType ?? PeekMediaType.json,
      );
    } on JsonUnsupportedObjectError {
      return PeekBody.unavailable(
        PeekBodyUnavailableReason.unreadable,
        contentType: contentType,
      );
    }
  }

  static String _message(DioException error) {
    final message = _trimmed(error.message);
    if (message != null) return message;
    final cause = error.error;
    return cause == null ? error.type.name : '$cause';
  }

  static String? _trimmed(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}
