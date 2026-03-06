import '../internal/formatting.dart';
import '../model/peek_body.dart';
import '../model/peek_entry.dart';
import '../model/peek_headers.dart';
import '../model/peek_media_type.dart';
import 'peek_text_exporter.dart';

/// Writes an entry as Markdown, for an issue or a pull request.
///
/// Bodies go in fenced blocks tagged with a language the media type
/// suggests, so JSON arrives highlighted.
final class PeekMarkdownExporter {
  /// Creates an exporter that keeps at most [maxBodyChars] of each body.
  const PeekMarkdownExporter({this.maxBodyChars = 4000});

  /// How much of a body is written before it is cut short.
  final int maxBodyChars;

  /// The entry as Markdown.
  String export(PeekEntry entry) {
    final request = entry.request;
    final lines = <String>[
      '### ${request.method} ${request.uri}',
      '',
      ..._summary(entry),
      '',
      '#### Request',
      ..._headers(request.headers),
      ..._body(request.body, request.mediaType),
    ];

    final response = entry.response;
    if (response != null) {
      lines
        ..add('')
        ..add('#### Response')
        ..addAll(_headers(response.headers))
        ..addAll(_body(response.body, response.mediaType));
    }

    final failure = entry.failure;
    if (failure != null) {
      lines
        ..add('')
        ..add('#### Error')
        ..add('')
        ..add('**${failure.kind.name}** — ${failure.message}');
      if (failure.details != null) {
        lines
          ..add('')
          ..add('```')
          ..add('${failure.details}')
          ..add('```');
      }
    }

    return lines.join('\n');
  }

  List<String> _summary(PeekEntry entry) {
    final message = entry.response?.statusMessage;
    final rows = <(String, String)>[
      (
        'Outcome',
        switch (entry.state) {
          PeekEntryState.pending => 'Pending',
          PeekEntryState.completed =>
            '`${entry.statusCode}`${message == null ? '' : ' $message'}',
          PeekEntryState.failed =>
            'Failed — `${entry.failure?.kind.name ?? 'unknown'}`',
        },
      ),
      if (entry.duration case final elapsed?)
        ('Duration', formatDuration(elapsed)),
      if (entry.requestSize case final size? when size > 0)
        ('Request', formatBytes(size)),
      if (entry.responseSize case final size? when size > 0)
        ('Response', formatBytes(size)),
      ('Started', entry.startedAt.toUtc().toIso8601String()),
      ('Source', '`${entry.source}`'),
    ];
    return [
      '| Field | Value |',
      '| --- | --- |',
      for (final (name, value) in rows) '| $name | $value |',
    ];
  }

  List<String> _headers(PeekHeaders headers) {
    if (headers.isEmpty) return ['', '_No headers._'];
    return [
      '',
      '| Header | Value |',
      '| --- | --- |',
      for (final header in headers.entries)
        '| `${header.key}` | ${_escape(header.value)} |',
    ];
  }

  List<String> _body(PeekBody body, PeekMediaType? mediaType) {
    final text = PeekTextExporter.describeBody(body, maxBodyChars);
    if (text == null) return const [];
    return ['', '```${_language(body, mediaType)}', text, '```'];
  }

  static String _language(PeekBody body, PeekMediaType? mediaType) {
    if (body is! PeekTextBody || mediaType == null) return '';
    if (mediaType.isJson) return 'json';
    if (mediaType.isXml) return 'xml';
    if (mediaType.isHtml) return 'html';
    return '';
  }

  static String _escape(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll('|', r'\|');
}
