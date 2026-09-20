import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import '../peek_share.dart';

/// The browser is the platform's share sheet: it saves the file.
PeekShareDelegate? peekPlatformShare() => const _DownloadShareDelegate();

/// Hands content to the browser as a download.
///
/// An anchor that clicks itself — the same few lines every web app writes,
/// and the reason Peek needs no package to share on the web.
final class _DownloadShareDelegate implements PeekShareDelegate {
  const _DownloadShareDelegate();

  /// How long the blob outlives the click. Revoking it in the same turn
  /// cancels the download in some browsers; a saved file needs it only
  /// until the download has started.
  static const Duration _linger = Duration(seconds: 10);

  @override
  Future<void> share(PeekShareContent content) async {
    final blob = _Blob(
      [utf8.encode(content.text).toJS].toJS,
      _BlobOptions(type: content.mimeType),
    );
    final url = _createObjectUrl(blob);
    // In the document before the click and out of it after: a detached
    // anchor is not enough everywhere.
    final anchor =
        _Anchor._(_document.createElement('a'))
          ..setAttribute('href', url)
          ..setAttribute('download', content.filename);
    _document.body.append(anchor);
    anchor
      ..click()
      ..remove();
    unawaited(Future<void>.delayed(_linger, () => _revokeObjectUrl(url)));
  }
}

@JS('document')
external _Document get _document;

@JS('URL.createObjectURL')
external String _createObjectUrl(JSObject blob);

@JS('URL.revokeObjectURL')
external void _revokeObjectUrl(String url);

extension type _Document._(JSObject _) implements JSObject {
  external JSObject createElement(String tag);

  external _Element get body;
}

extension type _Element._(JSObject _) implements JSObject {
  external void append(JSObject node);

  external void remove();

  external void setAttribute(String name, String value);
}

extension type _Anchor._(JSObject _) implements _Element {
  external void click();
}

@JS('Blob')
extension type _Blob._(JSObject _) implements JSObject {
  external factory _Blob(JSArray<JSAny> parts, _BlobOptions options);
}

extension type _BlobOptions._(JSObject _) implements JSObject {
  external factory _BlobOptions({String type});
}
