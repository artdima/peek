import '../internal/formatting.dart';
import '../model/peek_body.dart';
import '../model/peek_entry.dart';
import '../model/peek_form_data.dart';
import '../model/peek_headers.dart';

/// Writes an entry as plain text, for pasting into a chat or a ticket.
final class PeekTextExporter {
  /// Creates an exporter that keeps at most [maxBodyChars] of each body.
  const PeekTextExporter({this.maxBodyChars = 4000});

  /// How much of a body is written before it is cut short.
  final int maxBodyChars;

  /// The entry as text.
  String export(PeekEntry entry) {
    final lines = <String>[
      '${entry.request.method} ${entry.request.uri}',
      _outcome(entry),
      '',
      '--- Request ---',
      ..._headerLines(entry.request.headers),
      ..._bodyLines(entry.request.body),
    ];

    final response = entry.response;
    if (response != null) {
      lines
        ..add('')
        ..add('--- Response ---')
        ..addAll(_headerLines(response.headers))
        ..addAll(_bodyLines(response.body));
    }

    final failure = entry.failure;
    if (failure != null) {
      lines
        ..add('')
        ..add('--- Error ---')
        ..add('${failure.kind.name}: ${failure.message}');
      if (failure.details != null) lines.add('Details: ${failure.details}');
      if (failure.stackTrace != null) {
        lines
          ..add('')
          ..add('${failure.stackTrace}'.trimRight());
      }
    }

    return lines.join('\n');
  }

  /// The status line: outcome, duration, sizes and source.
  String _outcome(PeekEntry entry) {
    final parts = <String>[
      switch (entry.state) {
        PeekEntryState.pending => 'Pending',
        PeekEntryState.completed =>
          '${entry.statusCode} ${entry.response?.statusMessage ?? ''}'.trim(),
        PeekEntryState.failed =>
          'Failed: ${entry.failure?.kind.name ?? 'unknown'}',
      },
      if (entry.duration case final elapsed?) formatDuration(elapsed),
      if (entry.requestSize case final size? when size > 0)
        '↑ ${formatBytes(size)}',
      if (entry.responseSize case final size? when size > 0)
        '↓ ${formatBytes(size)}',
      entry.startedAt.toUtc().toIso8601String(),
      entry.source,
    ];
    return parts.join(' · ');
  }

  List<String> _headerLines(PeekHeaders headers) => [
    if (headers.isEmpty)
      '(no headers)'
    else
      for (final header in headers.entries) '${header.key}: ${header.value}',
  ];

  List<String> _bodyLines(PeekBody body) {
    final description = describeBody(body, maxBodyChars);
    return description == null ? const [] : ['', description];
  }

  static String _describeFile(PeekFormFile file) {
    final size = file.size;
    final suffix = size == null ? '' : ', ${formatBytes(size)}';
    return '${file.name}: <file ${file.filename ?? ''}$suffix>';
  }

  /// A body as text, cut to [maxChars]; `null` when there is nothing to
  /// show. Shared with the Markdown exporter.
  static String? describeBody(PeekBody body, int maxChars) => switch (body) {
    PeekEmptyBody() => null,
    PeekTextBody(:final text) when text.isEmpty => null,
    PeekTextBody(:final text) =>
      text.length > maxChars
          ? '${text.substring(0, maxChars)}\n… ${text.length - maxChars} more '
              'characters'
          : text,
    PeekBytesBody(:final size, :final contentType) =>
      '<${formatBytes(size)} of ${contentType ?? 'binary data'}>',
    PeekFormBody(:final fields, :final files) => [
      for (final field in fields) '${field.name}: ${field.value}',
      for (final file in files) _describeFile(file),
    ].join('\n'),
    PeekUnavailableBody(:final reason) => '<body not captured: ${reason.name}>',
  };
}
