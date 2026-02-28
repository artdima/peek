import '../model/peek_body.dart';
import '../model/peek_entry.dart';
import '../model/peek_request.dart';

/// Turns a request into a `curl` command that can be pasted into a shell.
///
/// Values are single-quoted for POSIX shells. Masked values stay masked:
/// Peek never held the originals. Bodies it cannot reproduce — bytes,
/// streams — become a trailing comment instead of a broken command.
final class PeekCurlExporter {
  /// Creates an exporter; [multiline] puts every header and data option
  /// on its own continued line after `curl -X METHOD 'url'`.
  const PeekCurlExporter({this.multiline = true});

  /// Whether options after the URL are split across continued lines.
  final bool multiline;

  /// The command that replays the request of [entry].
  String export(PeekEntry entry) => exportRequest(entry.request);

  /// The command that replays [request].
  String exportRequest(PeekRequest request) {
    final body = request.body;
    final head = <String>['curl'];
    final options = <String>[];
    final notes = <String>[];

    final sendsData = switch (body) {
      PeekTextBody() || PeekFormBody() || PeekBytesBody() => true,
      PeekEmptyBody() || PeekUnavailableBody() => false,
    };
    if (request.method != 'GET' || sendsData) {
      head.add('-X ${request.method}');
    }
    head.add(_quote(request.uri.toString()));

    final isMultipart = body is PeekFormBody && _isMultipart(body);
    for (final header in request.headers.entries) {
      final name = header.key.toLowerCase();
      if (name == 'content-length') continue;
      if (isMultipart && name == 'content-type') continue;
      options.add('-H ${_quote('${header.key}: ${header.value}')}');
    }

    switch (body) {
      case PeekTextBody():
        options.add('--data-raw ${_quote(body.text)}');
        if (body.isTruncated) {
          notes.add(
            'body truncated: ${body.capturedSize} of ${body.size} bytes',
          );
        }
      case PeekFormBody() when isMultipart:
        for (final field in body.fields) {
          options.add(
            '--form-string ${_quote('${field.name}=${field.value}')}',
          );
        }
        for (final file in body.files) {
          final type = file.contentType;
          final spec =
              type == null
                  ? '${file.name}=@${file.filename ?? file.name}'
                  : '${file.name}=@${file.filename ?? file.name};type=$type';
          options.add('-F ${_quote(spec)}');
        }
        if (body.files.isNotEmpty) {
          notes.add('file contents are not captured; point @ at real files');
        }
      case PeekFormBody():
        for (final field in body.fields) {
          options.add(
            '--data-urlencode ${_quote('${field.name}=${field.value}')}',
          );
        }
      case PeekBytesBody():
        options.add("--data-binary '@body.bin'");
        notes.add(
          'body.bin: ${body.size} bytes'
          '${body.contentType == null ? '' : ' of ${body.contentType}'}, '
          'not exported',
        );
      case PeekUnavailableBody():
        notes.add('body not captured (${body.reason.name})');
      case PeekEmptyBody():
        break;
    }

    final separator = multiline ? ' \\\n  ' : ' ';
    final command = [head.join(' '), ...options].join(separator);
    if (notes.isEmpty) return command;
    final comments = notes.map((note) => '# $note').join('\n');
    return multiline ? '$command\n$comments' : '$command $comments';
  }

  static bool _isMultipart(PeekFormBody body) =>
      body.files.isNotEmpty || (body.contentType?.isMultipart ?? false);

  static String _quote(String value) => "'${value.replaceAll("'", r"'\''")}'";
}
