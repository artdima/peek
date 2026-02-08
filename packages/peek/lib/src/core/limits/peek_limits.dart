import 'package:meta/meta.dart';

/// How much Peek keeps.
@immutable
final class PeekLimits {
  /// Creates limits; the defaults suit a debug build of a typical app.
  const PeekLimits({this.maxEntries = 1000, this.maxBodyBytes = 512 * 1024})
    : assert(maxEntries >= 1, 'maxEntries must be positive'),
      assert(maxBodyBytes >= 0, 'maxBodyBytes must not be negative');

  /// The most entries the store holds before evicting old ones.
  final int maxEntries;

  /// The most bytes of a body Peek keeps; the rest is cut off and the body
  /// marked as truncated. Zero keeps sizes but no content.
  final int maxBodyBytes;

  /// A copy with the given fields replaced.
  PeekLimits copyWith({int? maxEntries, int? maxBodyBytes}) => PeekLimits(
    maxEntries: maxEntries ?? this.maxEntries,
    maxBodyBytes: maxBodyBytes ?? this.maxBodyBytes,
  );

  @override
  bool operator ==(Object other) =>
      other is PeekLimits &&
      other.maxEntries == maxEntries &&
      other.maxBodyBytes == maxBodyBytes;

  @override
  int get hashCode => Object.hash(maxEntries, maxBodyBytes);

  @override
  String toString() =>
      'PeekLimits($maxEntries entries, $maxBodyBytes body bytes)';
}
