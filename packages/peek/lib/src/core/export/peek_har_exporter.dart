import 'dart:convert';
import 'dart:math' as math;

import '../model/peek_body.dart';
import '../model/peek_cookie.dart';
import '../model/peek_entry.dart';
import '../model/peek_headers.dart';
import '../model/peek_request.dart';
import '../model/peek_response.dart';
import '../model/peek_timings.dart';
import '../version.dart';

/// Writes entries as an HTTP Archive (HAR 1.2) document.
///
/// Pending calls are left out — HAR has no notion of a call without an
/// outcome. Failed calls are written the way browsers do it: status `0`
/// and an `_error` field. Other fields starting with `_` are Peek's own
/// and are ignored by HAR readers.
final class PeekHarExporter {
  /// Creates an exporter.
  const PeekHarExporter();

  /// The HAR document for [entries] as JSON text.
  String export(Iterable<PeekEntry> entries, {bool pretty = false}) =>
      pretty
          ? const JsonEncoder.withIndent('  ').convert(toJson(entries))
          : jsonEncode(toJson(entries));

  /// The HAR document for [entries] as a JSON-ready map.
  Map<String, Object?> toJson(Iterable<PeekEntry> entries) => {
    'log': {
      'version': '1.2',
      'creator': {'name': 'Peek', 'version': peekVersion},
      'entries': [
        for (final entry in entries)
          if (entry.state != PeekEntryState.pending) _entry(entry),
      ],
    },
  };

  Map<String, Object?> _entry(PeekEntry entry) {
    final timings = _timings(
      entry.timings,
      _millis(entry.duration ?? Duration.zero),
    );
    final failure = entry.failure;
    return {
      'startedDateTime': entry.startedAt.toUtc().toIso8601String(),
      'time': _total(timings),
      'request': _request(entry.request),
      'response': _response(entry.response),
      'cache': <String, Object?>{},
      'timings': timings,
      if (failure != null)
        '_error': {'kind': failure.kind.name, 'message': failure.message},
      '_peek': {'id': entry.id.value, 'source': entry.source},
    };
  }

  Map<String, Object?> _request(PeekRequest request) => {
    'method': request.method,
    'url': request.uri.toString(),
    'httpVersion': 'HTTP/1.1',
    'cookies': [for (final cookie in request.headers.cookies) _cookie(cookie)],
    'headers': _headers(request.headers),
    'queryString': [
      for (final MapEntry(:key, :value) in request.queryParameters.entries)
        for (final single in value) {'name': key, 'value': single},
    ],
    if (_postData(request) case final postData?) 'postData': postData,
    'headersSize': -1,
    'bodySize': request.contentLength ?? -1,
  };

  Map<String, Object?>? _postData(PeekRequest request) {
    final mimeType = request.mediaType?.mimeType ?? 'application/octet-stream';
    return switch (request.body) {
      PeekTextBody(:final text, :final isTruncated) => {
        'mimeType': mimeType,
        'text': text,
        if (isTruncated) 'comment': 'truncated by Peek',
      },
      PeekBytesBody(:final bytes) => {
        'mimeType': mimeType,
        'text': base64Encode(bytes),
        '_encoding': 'base64',
      },
      PeekFormBody(:final fields, :final files) => {
        'mimeType': mimeType,
        'params': [
          for (final field in fields)
            {'name': field.name, 'value': field.value},
          for (final file in files)
            {
              'name': file.name,
              if (file.filename != null) 'fileName': file.filename,
              if (file.contentType != null)
                'contentType': file.contentType.toString(),
            },
        ],
      },
      PeekEmptyBody() || PeekUnavailableBody() => null,
    };
  }

  Map<String, Object?> _response(PeekResponse? response) {
    if (response == null) {
      return {
        'status': 0,
        'statusText': '',
        'httpVersion': 'HTTP/1.1',
        'cookies': <Object?>[],
        'headers': <Object?>[],
        'content': {'size': 0, 'mimeType': 'x-unknown'},
        'redirectURL': '',
        'headersSize': -1,
        'bodySize': -1,
      };
    }
    return {
      'status': response.statusCode,
      'statusText': response.statusMessage ?? '',
      'httpVersion': 'HTTP/1.1',
      'cookies': [
        for (final cookie in response.headers.setCookies) _cookie(cookie),
      ],
      'headers': _headers(response.headers),
      'content': _content(response),
      'redirectURL': response.headers['location'] ?? '',
      'headersSize': -1,
      'bodySize': response.contentLength ?? -1,
    };
  }

  Map<String, Object?> _content(PeekResponse response) {
    final body = response.body;
    final mimeType = response.mediaType?.mimeType ?? 'x-unknown';
    return {
      'size': body.size ?? -1,
      'mimeType': mimeType,
      ...switch (body) {
        PeekTextBody(:final text, :final isTruncated) => {
          'text': text,
          if (isTruncated) 'comment': 'truncated by Peek',
        },
        PeekBytesBody(:final bytes, :final isTruncated) => {
          'text': base64Encode(bytes),
          'encoding': 'base64',
          if (isTruncated) 'comment': 'truncated by Peek',
        },
        PeekUnavailableBody(:final reason) => {
          'comment': 'not captured by Peek (${reason.name})',
        },
        PeekFormBody() || PeekEmptyBody() => <String, Object?>{},
      },
    };
  }

  Map<String, double> _timings(PeekTimings? timings, double total) {
    final blocked = _millisOrNone(timings?.blocked);
    final dns = _millisOrNone(timings?.dns);
    final connect = _millisOrNone(timings?.connect);
    final send = _millis(timings?.send ?? Duration.zero);
    final receive = _millis(timings?.receive ?? Duration.zero);
    final wait = timings?.wait;
    final measured = _total({
      'blocked': blocked,
      'dns': dns,
      'connect': connect,
      'send': send,
      'receive': receive,
    });
    return {
      'blocked': blocked,
      'dns': dns,
      'connect': connect,
      'ssl': _millisOrNone(timings?.ssl),
      'send': send,
      // Whatever the named phases leave over was spent waiting.
      'wait': wait == null ? math.max(total - measured, 0.0) : _millis(wait),
      'receive': receive,
    };
  }

  /// The elapsed time HAR expects beside the phases: their sum, with `ssl`
  /// left out because it is already counted inside `connect`.
  static double _total(Map<String, double> timings) => timings.entries
      .where((phase) => phase.key != 'ssl' && phase.value >= 0)
      .fold(0, (sum, phase) => sum + phase.value);

  static List<Map<String, String>> _headers(PeekHeaders headers) => [
    for (final entry in headers.entries)
      {'name': entry.key, 'value': entry.value},
  ];

  static Map<String, Object?> _cookie(PeekCookie cookie) => {
    'name': cookie.name,
    'value': cookie.value,
    if (cookie.path != null) 'path': cookie.path,
    if (cookie.domain != null) 'domain': cookie.domain,
    if (cookie.expiresAt case final expires?)
      'expires': expires.toIso8601String(),
    'httpOnly': cookie.isHttpOnly,
    'secure': cookie.isSecure,
  };

  static double _millis(Duration duration) => duration.inMicroseconds / 1000;

  static double _millisOrNone(Duration? duration) =>
      duration == null ? -1 : _millis(duration);
}
