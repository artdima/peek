import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import '../peek_share.dart';

/// The browser is the platform's share sheet: it shares text where it has
/// one of its own and saves a file otherwise.
PeekShareDelegate? peekPlatformShare() => const _BrowserShareDelegate();

/// Hands text to the Web Share API and files to the browser as downloads.
///
/// An anchor that clicks itself — the same few lines every web app writes,
/// and the reason Peek needs no package to share on the web.
final class _BrowserShareDelegate implements PeekShareDelegate {
  const _BrowserShareDelegate();

  /// How long the blob outlives the click. Revoking it in the same turn
  /// cancels the download in some browsers; a saved file needs it only
  /// until the download has started.
  static const Duration _linger = Duration(seconds: 10);

  @override
  Future<void> share(PeekShareContent content) async {
    if (content.kind == PeekShareKind.text && _navigator.canShareText) {
      if (await _shareText(content)) return;
    }
    _download(content);
  }

  /// Whether the browser took the text: a cancelled sheet counts, a browser
  /// that refused — a tap too long ago, say — does not.
  Future<bool> _shareText(PeekShareContent content) async {
    final data = _ShareData(
      title: content.subject ?? content.filename,
      text: content.text,
    );
    // Settled in JS: a Dart `is` on the reason would be a runtime check of
    // a JS interop type, which the analyzer forbids.
    final sharing = _navigator.share(data).recover(_refusalName.toJS);
    final refusal = await sharing.toDart;
    return refusal == null || refusal.toDart == 'AbortError';
  }

  void _download(PeekShareContent content) {
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

@JS('navigator')
external _Navigator get _navigator;

extension type _Navigator._(JSObject _) implements JSObject {
  @JS('share')
  external JSAny? get _shareFunction;

  external _Sharing share(_ShareData data);

  /// Whether the Web Share API is there at all: phones have it, desktop
  /// browsers only some.
  bool get canShareText => _shareFunction != null;
}

extension type _ShareData._(JSObject _) implements JSObject {
  external factory _ShareData({String title, String text});
}

/// The promise `navigator.share` returns.
extension type _Sharing._(JSObject _) implements JSObject {
  /// Settles with what [onRejected] returns when the share was refused,
  /// and with nothing when it went through.
  @JS('catch')
  external JSPromise<JSString?> recover(JSFunction onRejected);
}

/// What a refused share comes back with: a `DOMException`, usually.
extension type _Refusal._(JSAny _) implements JSAny {
  /// `AbortError` when the person closed the sheet without choosing.
  external String? get name;
}

/// Names a refusal for [_Sharing.recover]; anything nameless is an error.
JSString _refusalName(JSAny? reason) {
  final name = reason == null ? null : _Refusal._(reason).name;
  return (name ?? 'Error').toJS;
}

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
