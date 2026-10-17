import 'package:flutter/widgets.dart';

import 'share/peek_download.dart'
    if (dart.library.js_interop) 'share/peek_download_web.dart';

/// What a [PeekShareContent] is to whatever receives it.
enum PeekShareKind {
  /// A file to save or attach, called [PeekShareContent.filename].
  file,

  /// A line or a few to paste where text goes — a URL, a command, a
  /// summary. The filename is for a receiver that can only take a file.
  text,
}

/// Something Peek would like handed to the rest of the system.
@immutable
final class PeekShareContent {
  /// Creates content named [filename], holding [text].
  const PeekShareContent({
    required this.filename,
    required this.mimeType,
    required this.text,
    this.kind = PeekShareKind.file,
    this.subject,
    this.origin,
  });

  /// What the file should be called when it is saved or sent.
  final String filename;

  /// Whether this is a file to attach or text to paste.
  final PeekShareKind kind;

  /// The media type of [text], for a receiver that saves it as a file.
  final String mimeType;

  /// The content itself.
  final String text;

  /// A line for whatever asks for one, such as an email subject.
  final String? subject;

  /// Where on the screen the sharing was asked for, in global coordinates.
  ///
  /// iPadOS anchors its share sheet to a rectangle and refuses to show one
  /// without: pass this through as `sharePositionOrigin`, falling back to
  /// any rectangle on screen rather than to none.
  final Rect? origin;

  @override
  String toString() =>
      'PeekShareContent(${kind.name} $filename, ${text.length} chars)';
}

/// Hands exported content to the platform's share sheet.
///
/// Peek does not depend on a sharing package: the app that embeds it
/// wires up whichever one it already uses. What arrives says what it is:
/// [PeekShareKind.text] is a URL, a command or a summary to paste,
/// [PeekShareKind.file] a HAR or a session to attach. On the web there is
/// nothing to wire up — the browser shares the text where it can and saves
/// the file otherwise — so a delegate is worth giving only where a share
/// sheet exists, and one given there is used instead.
///
/// ```dart
/// PeekScreen(
///   share: PeekShareDelegate.from((content) async {
///     switch (content.kind) {
///       case PeekShareKind.text:
///         await Share.share(
///           content.text,
///           subject: content.subject,
///           sharePositionOrigin: content.origin,
///         );
///       case PeekShareKind.file:
///         await Share.shareXFiles(
///           [XFile.fromData(utf8.encode(content.text))],
///           sharePositionOrigin: content.origin,
///         );
///     }
///   }),
/// )
/// ```
///
/// Without a delegate, and off the web, Peek offers copying and nothing
/// else: an option that cannot work is worse than no option.
abstract interface class PeekShareDelegate {
  /// Creates a delegate from a function.
  factory PeekShareDelegate.from(
    Future<void> Function(PeekShareContent content) share,
  ) = _CallbackShareDelegate;

  /// Hands [content] over.
  Future<void> share(PeekShareContent content);
}

final class _CallbackShareDelegate implements PeekShareDelegate {
  const _CallbackShareDelegate(this._share);

  final Future<void> Function(PeekShareContent content) _share;

  @override
  Future<void> share(PeekShareContent content) => _share(content);
}

/// What the platform can hand an export to without a delegate.
///
/// The browser on the web — its share sheet for text where it has one, a
/// download otherwise — and nothing anywhere else: a share sheet belongs
/// to a package, and Peek depends on none.
PeekShareDelegate? peekPlatformShareDelegate() => peekPlatformShare();

/// Where the widget at [context] sits on screen, in global coordinates.
///
/// For [PeekShareContent.origin]. Returns null when the widget has not been
/// laid out — a share sheet anchored nowhere is better than none at all.
Rect? peekShareOrigin(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}
