import 'dart:convert';

import '../model/peek_body.dart';
import '../model/peek_entry.dart';
import '../model/peek_form_data.dart';
import '../model/peek_headers.dart';
import '../model/peek_request.dart';
import '../model/peek_response.dart';
import 'peek_redaction_policy.dart';

/// Applies a [PeekRedactionPolicy] to what adapters report.
///
/// Anything untouched by the policy comes back as the same instance, so a
/// call with nothing to hide costs nothing.
final class PeekRedactor {
  /// Creates a redactor for [policy].
  const PeekRedactor(this.policy);

  /// What to mask.
  final PeekRedactionPolicy policy;

  /// Masks the request and, when present, the response of [entry].
  PeekEntry redactEntry(PeekEntry entry) {
    if (policy.isEmpty) return entry;
    final response = entry.response;
    final request = redactRequest(entry.request);
    final redacted = response == null ? null : redactResponse(response);
    if (identical(request, entry.request) && identical(redacted, response)) {
      return entry;
    }
    return entry.copyWith(request: request, response: redacted);
  }

  /// Masks the URL query, headers and body of [request].
  PeekRequest redactRequest(PeekRequest request) {
    if (policy.isEmpty) return request;
    final uri = redactUri(request.uri);
    final headers = redactHeaders(request.headers);
    final body = redactBody(request.body);
    if (identical(uri, request.uri) &&
        identical(headers, request.headers) &&
        identical(body, request.body)) {
      return request;
    }
    return request.copyWith(uri: uri, headers: headers, body: body);
  }

  /// Masks the headers and body of [response].
  PeekResponse redactResponse(PeekResponse response) {
    if (policy.isEmpty) return response;
    final headers = redactHeaders(response.headers);
    final body = redactBody(response.body);
    if (identical(headers, response.headers) &&
        identical(body, response.body)) {
      return response;
    }
    return response.copyWith(headers: headers, body: body);
  }

  /// Masks the values of matching headers. Cookie headers keep their cookie
  /// names and attributes.
  PeekHeaders redactHeaders(PeekHeaders headers) {
    if (policy.headerNames.isEmpty || headers.isEmpty) return headers;
    var changed = false;
    final entries = <MapEntry<String, String>>[];
    for (final entry in headers.entries) {
      if (policy.matchesHeader(entry.key)) {
        changed = true;
        entries.add(MapEntry(entry.key, _maskHeader(entry.key, entry.value)));
      } else {
        entries.add(entry);
      }
    }
    return changed ? PeekHeaders.fromEntries(entries) : headers;
  }

  /// Masks the values of matching query parameters, leaving the rest of the
  /// query byte for byte as it was.
  Uri redactUri(Uri uri) {
    if (policy.queryKeys.isEmpty || !uri.hasQuery) return uri;
    final query = _redactQuery(uri.query, policy.matchesQuery);
    return query == null ? uri : uri.replace(query: query);
  }

  /// Masks matching keys in JSON and URL-encoded text bodies and matching
  /// fields in form bodies. Other bodies come back untouched.
  PeekBody redactBody(PeekBody body) => switch (body) {
    PeekTextBody() => _redactText(body),
    PeekFormBody() => _redactForm(body),
    PeekBytesBody() || PeekEmptyBody() || PeekUnavailableBody() => body,
  };

  String _maskHeader(String name, String value) => switch (name.toLowerCase()) {
    'cookie' => value.replaceAllMapped(
      _cookiePair,
      (match) => '${match[1]}=${policy.replacement}',
    ),
    'set-cookie' => value.replaceFirstMapped(
      _cookiePair,
      (match) => '${match[1]}=${policy.replacement}',
    ),
    _ => policy.replacement,
  };

  static final RegExp _cookiePair = RegExp(r'([^=;\s][^=;]*)=[^;]*');

  PeekBody _redactText(PeekTextBody body) {
    if (policy.bodyKeys.isEmpty) return body;
    final type = body.contentType;
    final String? redacted;
    if (type != null && type.isFormUrlEncoded) {
      redacted = _redactQuery(body.text, policy.matchesBodyKey);
    } else if ((type == null || type.isJson || type.isText) &&
        _looksLikeJson(body.text)) {
      redacted = _redactJson(body.text);
    } else {
      redacted = null;
    }
    if (redacted == null) return body;
    return PeekBody.text(
      redacted,
      contentType: type,
      size: body.isTruncated ? body.size : null,
    );
  }

  PeekBody _redactForm(PeekFormBody body) {
    if (policy.bodyKeys.isEmpty) return body;
    var changed = false;
    final fields = <PeekFormField>[];
    for (final field in body.fields) {
      if (policy.matchesBodyKey(field.name)) {
        changed = true;
        fields.add(PeekFormField(field.name, policy.replacement));
      } else {
        fields.add(field);
      }
    }
    if (!changed) return body;
    return PeekBody.form(
      fields: fields,
      files: body.files,
      contentType: body.contentType,
    );
  }

  String? _redactQuery(String query, bool Function(String name) matches) {
    var changed = false;
    final pairs = <String>[];
    for (final pair in query.split('&')) {
      final separator = pair.indexOf('=');
      final rawName = separator < 0 ? pair : pair.substring(0, separator);
      if (matches(rawName.replaceAll('+', ' '))) {
        changed = true;
        pairs.add('$rawName=${Uri.encodeComponent(policy.replacement)}');
      } else {
        pairs.add(pair);
      }
    }
    return changed ? pairs.join('&') : null;
  }

  String? _redactJson(String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      return null;
    }
    final (value, changed) = _walk(decoded);
    return changed ? jsonEncode(value) : null;
  }

  (Object?, bool) _walk(Object? node) => switch (node) {
    Map<String, Object?>() => _walkMap(node),
    List<Object?>() => _walkList(node),
    _ => (node, false),
  };

  (Map<String, Object?>, bool) _walkMap(Map<String, Object?> map) {
    var changed = false;
    final out = <String, Object?>{};
    for (final MapEntry(:key, :value) in map.entries) {
      if (value != null && policy.matchesBodyKey(key)) {
        out[key] = policy.replacement;
        changed = true;
      } else {
        final (walked, touched) = _walk(value);
        out[key] = walked;
        changed = changed || touched;
      }
    }
    return (out, changed);
  }

  (List<Object?>, bool) _walkList(List<Object?> list) {
    var changed = false;
    final out = <Object?>[];
    for (final item in list) {
      final (walked, touched) = _walk(item);
      out.add(walked);
      changed = changed || touched;
    }
    return (out, changed);
  }

  static bool _looksLikeJson(String text) {
    final trimmed = text.trimLeft();
    return trimmed.startsWith('{') || trimmed.startsWith('[');
  }
}
