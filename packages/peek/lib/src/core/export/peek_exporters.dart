import '../model/peek_entry.dart';
import 'peek_curl_exporter.dart';
import 'peek_har_exporter.dart';
import 'peek_markdown_exporter.dart';
import 'peek_text_exporter.dart';

/// Every way Peek can hand an entry to something else.
///
/// ```dart
/// Clipboard.setData(ClipboardData(text: PeekExporters.curl.export(entry)));
/// ```
final class PeekExporters {
  const PeekExporters._();

  /// A `curl` command that replays the request.
  static const PeekCurlExporter curl = PeekCurlExporter();

  /// A plain-text summary of one call.
  static const PeekTextExporter text = PeekTextExporter();

  /// A Markdown summary of one call.
  static const PeekMarkdownExporter markdown = PeekMarkdownExporter();

  /// An HTTP Archive document holding many calls.
  static const PeekHarExporter har = PeekHarExporter();

  /// The URL of [entry], the shortest thing worth copying.
  static String url(PeekEntry entry) => entry.request.uri.toString();
}
