import 'dart:convert';
import 'dart:js_interop';

import '../peek_share.dart';

/// The browser is the platform's share sheet: it saves the file.
PeekShareDelegate? peekPlatformShare() => const _DownloadShareDelegate();

/// Hands content to the browser as a download.
///
/// A blob and an anchor that clicks itself: the same few lines every web
/// app writes, and the reason Peek needs no package to share on the web.
final class _DownloadShareDelegate implements PeekShareDelegate {
  const _DownloadShareDelegate();

  @override
  Future<void> share(PeekShareContent content) async {
    final blob = _Blob(
      [utf8.encode(content.text).toJS].toJS,
      _BlobOptions(type: content.mimeType),
    );
    final url = _createObjectUrl(blob);
    try {
      _Anchor._(_createElement('a'))
        ..href = url
        ..download = content.filename
        ..click();
    } finally {
      _revokeObjectUrl(url);
    }
  }
}

@JS('document.createElement')
external JSObject _createElement(String tag);

@JS('URL.createObjectURL')
external String _createObjectUrl(JSObject blob);

@JS('URL.revokeObjectURL')
external void _revokeObjectUrl(String url);

extension type _Anchor._(JSObject _) implements JSObject {
  external set href(String value);

  external set download(String value);

  external void click();
}

@JS('Blob')
extension type _Blob._(JSObject _) implements JSObject {
  external factory _Blob(JSArray<JSAny> parts, _BlobOptions options);
}

extension type _BlobOptions._(JSObject _) implements JSObject {
  external factory _BlobOptions({String type});
}
