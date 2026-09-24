import 'dart:convert';

import '../model/peek_body.dart';
import '../model/peek_entry.dart';
import '../model/peek_failure.dart';
import '../model/peek_form_data.dart';
import '../model/peek_headers.dart';
import '../model/peek_id.dart';
import '../model/peek_media_type.dart';
import '../model/peek_request.dart';
import '../model/peek_response.dart';
import '../model/peek_timings.dart';

/// Turns the model into JSON-ready values and back: the format of Peek's own
/// session files and of the frames sent to a desktop viewer.
///
/// Unlike the HAR export, nothing is lost: pending calls, the kind of a
/// failure and its stack trace, the source, pins, truncation and the reason a
/// body is missing all survive. Empty and default fields are left out, and
/// cookies travel inside the headers they came in.
///
/// Reading is lenient, because a reader newer or older than the writer is
/// the normal case: unknown keys are ignored, an unknown failure kind reads
/// as [PeekFailureKind.unknown], and an unknown body kind or reason reads as
/// a body that was not captured. A missing required field or a value of the
/// wrong type throws a [FormatException].
///
/// Times are written in UTC as ISO 8601 and read back in UTC. Durations are
/// milliseconds, fractions allowed. A failure's `details` travel as their
/// `toString()` and its stack trace as text, so those two come back as
/// strings rather than the original objects.
///
/// ```dart
/// final line = jsonEncode(const PeekCodec().encodeEntry(entry));
/// final copy = const PeekCodec().decodeEntry(jsonDecode(line));
/// ```
final class PeekCodec {
  /// Creates a codec.
  const PeekCodec();

  /// [entry] as a JSON-ready map.
  Map<String, Object?> encodeEntry(PeekEntry entry) => {
    'id': entry.id.value,
    'source': entry.source,
    'startedAt': _timeText(entry.startedAt),
    if (entry.completedAt case final completedAt?)
      'completedAt': _timeText(completedAt),
    if (entry.isPinned) 'pinned': true,
    'request': encodeRequest(entry.request),
    if (entry.response case final response?)
      'response': encodeResponse(response),
    if (entry.failure case final failure?) 'failure': encodeFailure(failure),
    if (entry.timings case final timings?) 'timings': encodeTimings(timings),
  };

  /// Reads an entry written by [encodeEntry].
  PeekEntry decodeEntry(Object? json) {
    final map = _object(json, 'an entry');
    final id = _string(map, 'id');
    if (id.isEmpty) throw const FormatException('"id" is empty');
    final response = _decodeOptional(map['response'], decodeResponse);
    final failure = _decodeOptional(map['failure'], decodeFailure);
    final completedAt = _optionalTime(map, 'completedAt');
    if ((response == null && failure == null) != (completedAt == null)) {
      throw const FormatException(
        '"completedAt" goes together with a response or a failure',
      );
    }
    return PeekEntry(
      id: PeekId(id),
      request: decodeRequest(map['request']),
      startedAt: _time(map, 'startedAt'),
      source: _string(map, 'source'),
      response: response,
      failure: failure,
      completedAt: completedAt,
      isPinned: _optionalBool(map, 'pinned') ?? false,
      timings: _decodeOptional(map['timings'], decodeTimings),
    );
  }

  /// [request] as a JSON-ready map. `extra` values JSON cannot hold are
  /// written through `toString`.
  Map<String, Object?> encodeRequest(PeekRequest request) => {
    'method': request.method,
    'url': request.uri.toString(),
    if (request.headers.isNotEmpty) 'headers': encodeHeaders(request.headers),
    if (request.body is! PeekEmptyBody) 'body': encodeBody(request.body),
    if (request.extra.isNotEmpty)
      'extra': {
        for (final MapEntry(:key, :value) in request.extra.entries)
          key: _jsonValue(value),
      },
  };

  /// Reads a request written by [encodeRequest].
  PeekRequest decodeRequest(Object? json) {
    final map = _object(json, 'a request');
    final uri = Uri.tryParse(_string(map, 'url'));
    if (uri == null) throw const FormatException('"url" is not a URL');
    return PeekRequest(
      method: _string(map, 'method'),
      uri: uri,
      headers:
          _decodeOptional(map['headers'], decodeHeaders) ?? PeekHeaders.empty,
      body: _decodeOptional(map['body'], decodeBody) ?? const PeekBody.empty(),
      extra: switch (map['extra']) {
        null => const {},
        final Map<String, Object?> extra => extra,
        _ => throw const FormatException('"extra" must be an object'),
      },
    );
  }

  /// [response] as a JSON-ready map.
  Map<String, Object?> encodeResponse(PeekResponse response) => {
    'status': response.statusCode,
    if (response.statusMessage case final message?) 'message': message,
    if (response.headers.isNotEmpty) 'headers': encodeHeaders(response.headers),
    if (response.body is! PeekEmptyBody) 'body': encodeBody(response.body),
    if (response.redirects.isNotEmpty)
      'redirects': [
        for (final redirect in response.redirects) encodeRedirect(redirect),
      ],
  };

  /// Reads a response written by [encodeResponse].
  PeekResponse decodeResponse(Object? json) {
    final map = _object(json, 'a response');
    return PeekResponse(
      statusCode: _int(map, 'status'),
      statusMessage: _optionalString(map, 'message'),
      headers:
          _decodeOptional(map['headers'], decodeHeaders) ?? PeekHeaders.empty,
      body: _decodeOptional(map['body'], decodeBody) ?? const PeekBody.empty(),
      redirects: [
        for (final redirect in _optionalArray(map, 'redirects'))
          decodeRedirect(redirect),
      ],
    );
  }

  /// [redirect] as a JSON-ready map.
  Map<String, Object?> encodeRedirect(PeekRedirect redirect) => {
    'status': redirect.statusCode,
    'method': redirect.method,
    'location': redirect.location.toString(),
  };

  /// Reads a redirect written by [encodeRedirect].
  PeekRedirect decodeRedirect(Object? json) {
    final map = _object(json, 'a redirect');
    final location = Uri.tryParse(_string(map, 'location'));
    if (location == null) {
      throw const FormatException('"location" is not a URL');
    }
    return PeekRedirect(
      statusCode: _int(map, 'status'),
      method: _string(map, 'method'),
      location: location,
    );
  }

  /// [headers] as `[name, value]` pairs: every value of a repeated name, in
  /// order, with the casing each name was first seen in.
  List<List<String>> encodeHeaders(PeekHeaders headers) => [
    for (final MapEntry(:key, :value) in headers.entries) [key, value],
  ];

  /// Reads headers written by [encodeHeaders].
  PeekHeaders decodeHeaders(Object? json) => PeekHeaders.fromEntries([
    for (final pair in _array(json, 'headers')) _pair(pair, 'a header'),
  ]);

  /// [body] as a JSON-ready map: a `kind` — `empty`, `text`, `bytes` (as
  /// base64), `form` or `unavailable` — and what that kind holds. `size` is
  /// written only when it says more than the content does.
  Map<String, Object?> encodeBody(PeekBody body) => {
    ...switch (body) {
      PeekEmptyBody() => {'kind': 'empty'},
      PeekTextBody(:final text, :final size, :final isTruncated) => {
        'kind': 'text',
        'text': text,
        if (isTruncated) 'size': size,
      },
      PeekBytesBody(:final bytes, :final size, :final isTruncated) => {
        'kind': 'bytes',
        'bytes': base64Encode(bytes),
        if (isTruncated) 'size': size,
      },
      PeekFormBody(:final fields, :final files) => {
        'kind': 'form',
        if (fields.isNotEmpty)
          'fields': [for (final field in fields) encodeFormField(field)],
        if (files.isNotEmpty)
          'files': [for (final file in files) encodeFormFile(file)],
      },
      PeekUnavailableBody(:final reason, :final size) => {
        'kind': 'unavailable',
        'reason': reason.name,
        if (size != null) 'size': size,
      },
    },
    if (body.contentType case final type?) 'type': encodeMediaType(type),
  };

  /// Reads a body written by [encodeBody].
  PeekBody decodeBody(Object? json) {
    final map = _object(json, 'a body');
    final type = decodeMediaType(map['type']);
    final size = _optionalInt(map, 'size');
    return switch (_string(map, 'kind')) {
      'empty' => const PeekBody.empty(),
      'text' => PeekBody.text(
        _string(map, 'text'),
        contentType: type,
        size: size,
      ),
      'bytes' => PeekBody.bytes(
        base64Decode(_string(map, 'bytes')),
        contentType: type,
        size: size,
      ),
      'form' => PeekBody.form(
        fields: [
          for (final field in _optionalArray(map, 'fields'))
            decodeFormField(field),
        ],
        files: [
          for (final file in _optionalArray(map, 'files')) decodeFormFile(file),
        ],
        contentType: type,
      ),
      'unavailable' => PeekBody.unavailable(
        PeekBodyUnavailableReason.values.asNameMap()[map['reason']] ??
            PeekBodyUnavailableReason.notCaptured,
        contentType: type,
        size: size,
      ),
      // A kind from a newer writer: the body exists, but not in a form this
      // reader can hold.
      _ => PeekBody.unavailable(
        PeekBodyUnavailableReason.notCaptured,
        contentType: type,
        size: size,
      ),
    };
  }

  /// [field] as a `[name, value]` pair.
  List<String> encodeFormField(PeekFormField field) => [
    field.name,
    field.value,
  ];

  /// Reads a field written by [encodeFormField].
  PeekFormField decodeFormField(Object? json) {
    final MapEntry(:key, :value) = _pair(json, 'a form field');
    return PeekFormField(key, value);
  }

  /// [file] as a JSON-ready map.
  Map<String, Object?> encodeFormFile(PeekFormFile file) => {
    'name': file.name,
    if (file.filename case final filename?) 'filename': filename,
    if (file.contentType case final type?) 'type': encodeMediaType(type),
    if (file.size case final size?) 'size': size,
  };

  /// Reads a file part written by [encodeFormFile].
  PeekFormFile decodeFormFile(Object? json) {
    final map = _object(json, 'a form file');
    return PeekFormFile(
      _string(map, 'name'),
      filename: _optionalString(map, 'filename'),
      contentType: decodeMediaType(map['type']),
      size: _optionalInt(map, 'size'),
    );
  }

  /// [type] as a `Content-Type` value.
  String encodeMediaType(PeekMediaType type) => type.toString();

  /// Reads a media type written by [encodeMediaType]; `null` when absent or
  /// not a `type/subtype` pair.
  PeekMediaType? decodeMediaType(Object? json) => switch (json) {
    null => null,
    final String value => PeekMediaType.tryParse(value),
    _ => throw const FormatException('a media type must be a string'),
  };

  /// [failure] as a JSON-ready map.
  Map<String, Object?> encodeFailure(PeekFailure failure) => {
    'kind': failure.kind.name,
    'message': failure.message,
    if (failure.details case final details?) 'details': details.toString(),
    if (failure.stackTrace case final stackTrace?)
      'stackTrace': stackTrace.toString(),
  };

  /// Reads a failure written by [encodeFailure].
  PeekFailure decodeFailure(Object? json) {
    final map = _object(json, 'a failure');
    final stackTrace = _optionalString(map, 'stackTrace');
    return PeekFailure(
      kind:
          PeekFailureKind.values.asNameMap()[map['kind']] ??
          PeekFailureKind.unknown,
      message: _string(map, 'message'),
      details: _optionalString(map, 'details'),
      stackTrace: stackTrace == null ? null : StackTrace.fromString(stackTrace),
    );
  }

  /// [timings] as milliseconds by phase, known phases only.
  Map<String, Object?> encodeTimings(PeekTimings timings) => {
    for (final MapEntry(:key, :value) in timings.known.entries)
      key: _millis(value),
  };

  /// Reads timings written by [encodeTimings].
  PeekTimings decodeTimings(Object? json) {
    final map = _object(json, 'timings');
    return PeekTimings(
      blocked: _optionalMillis(map, 'blocked'),
      dns: _optionalMillis(map, 'dns'),
      connect: _optionalMillis(map, 'connect'),
      ssl: _optionalMillis(map, 'ssl'),
      send: _optionalMillis(map, 'send'),
      wait: _optionalMillis(map, 'wait'),
      receive: _optionalMillis(map, 'receive'),
    );
  }
}

T? _decodeOptional<T>(Object? json, T Function(Object? json) decode) =>
    json == null ? null : decode(json);

Map<String, Object?> _object(Object? json, String what) => switch (json) {
  final Map<String, Object?> map => map,
  _ => throw FormatException('expected $what as an object'),
};

List<Object?> _array(Object? json, String what) => switch (json) {
  final List<Object?> list => list,
  _ => throw FormatException('expected $what as an array'),
};

List<Object?> _optionalArray(Map<String, Object?> map, String key) =>
    map[key] == null ? const [] : _array(map[key], '"$key"');

MapEntry<String, String> _pair(Object? json, String what) => switch (json) {
  [final String name, final String value] => MapEntry(name, value),
  _ => throw FormatException('expected $what as a [name, value] pair'),
};

String _string(Map<String, Object?> map, String key) => switch (map[key]) {
  final String value => value,
  _ => throw FormatException('"$key" must be a string'),
};

String? _optionalString(Map<String, Object?> map, String key) =>
    map[key] == null ? null : _string(map, key);

int _int(Map<String, Object?> map, String key) => switch (map[key]) {
  final int value => value,
  _ => throw FormatException('"$key" must be an integer'),
};

int? _optionalInt(Map<String, Object?> map, String key) =>
    map[key] == null ? null : _int(map, key);

bool? _optionalBool(Map<String, Object?> map, String key) => switch (map[key]) {
  null => null,
  final bool value => value,
  _ => throw FormatException('"$key" must be true or false'),
};

String _timeText(DateTime time) => time.toUtc().toIso8601String();

DateTime _time(Map<String, Object?> map, String key) {
  final time = DateTime.tryParse(_string(map, key));
  if (time == null) throw FormatException('"$key" is not an ISO 8601 time');
  return time.toUtc();
}

DateTime? _optionalTime(Map<String, Object?> map, String key) =>
    map[key] == null ? null : _time(map, key);

/// Whole milliseconds as an integer, anything finer as a fraction.
num _millis(Duration duration) {
  final micros = duration.inMicroseconds;
  return micros % 1000 == 0 ? micros ~/ 1000 : micros / 1000;
}

Duration? _optionalMillis(Map<String, Object?> map, String key) =>
    switch (map[key]) {
      null => null,
      final num millis => Duration(microseconds: (millis * 1000).round()),
      _ => throw FormatException('"$key" must be a number'),
    };

Object? _jsonValue(Object? value) => switch (value) {
  null || bool() || String() || int() => value,
  final double number when number.isFinite => number,
  _ => value.toString(),
};
