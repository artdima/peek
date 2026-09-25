import 'peek_remote_transport.dart';

/// The transport where there is no `dart:io`.
PeekRemoteTransport platformTransport(Duration timeout) =>
    const _UnsupportedTransport();

final class _UnsupportedTransport implements PeekRemoteTransport {
  const _UnsupportedTransport();

  @override
  Future<PeekRemoteConnection> connect(Uri uri) => Future.error(
    UnsupportedError('peek_remote streams from Android, iOS and desktop apps'),
  );
}
