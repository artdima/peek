/// Where Peek Pro and the remote package live, for the screen to point at.
///
/// One place, so the addresses change together once Peek Pro is published.
abstract final class PeekLinks {
  /// Peek Pro's repository.
  static const String peekPro = 'https://github.com/artdima/peek-pro';

  /// The `peek_remote` package.
  static const String peekRemote = 'https://pub.dev/packages/peek_remote';

  /// The guide to remote viewing.
  static const String remoteGuide =
      'https://github.com/artdima/peek/blob/main/doc/remote.md';

  /// What goes into `pubspec.yaml`.
  static const String dependency = 'peek_remote: ^2.0.0';

  /// What goes into the app, where Peek is set up.
  static const String setup = 'peek.attach(PeekRemote(peek)..start());';
}
