import 'package:meta/meta.dart';

/// Something Peek would like handed to the rest of the system.
@immutable
final class PeekShareContent {
  /// Creates content named [filename], holding [text].
  const PeekShareContent({
    required this.filename,
    required this.mimeType,
    required this.text,
    this.subject,
  });

  /// What the file should be called when it is saved or sent.
  final String filename;

  /// What kind of thing it is.
  final String mimeType;

  /// The content itself.
  final String text;

  /// A line for whatever asks for one, such as an email subject.
  final String? subject;

  @override
  String toString() => 'PeekShareContent($filename, ${text.length} chars)';
}

/// Hands exported content to the platform's share sheet.
///
/// Peek does not depend on a sharing package: the app that embeds it
/// wires up whichever one it already uses.
///
/// ```dart
/// PeekScreen(
///   share: PeekShareDelegate.from((content) async {
///     await Share.shareXFiles([XFile.fromData(utf8.encode(content.text))]);
///   }),
/// )
/// ```
///
/// Without a delegate Peek offers copying and nothing else: an option
/// that cannot work is worse than no option.
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
