import 'package:meta/meta.dart';

/// How much Peek keeps.
@immutable
final class PeekLimits {
  /// Creates limits; the defaults suit a debug build of a typical app.
  const PeekLimits({
    this.maxEntries = 1000,
    this.maxBodyBytes = 1024 * 1024,
    this.maxPinned = 50,
  }) : assert(maxEntries >= 1, 'maxEntries must be positive'),
       assert(maxBodyBytes >= 0, 'maxBodyBytes must not be negative'),
       assert(maxPinned >= 0, 'maxPinned must not be negative');

  /// The most entries the store holds before evicting old ones.
  final int maxEntries;

  /// The most bytes of a body Peek keeps; the rest is cut off and the body
  /// marked as truncated. Zero keeps sizes but no content.
  ///
  /// What this costs is not one body but [maxEntries] of them, so raising
  /// it raises the worst case in step. A body kept whole is also a body
  /// the JSON tree can decode: cut short, it has no tree.
  final int maxBodyBytes;

  /// The most entries a user can pin. Pinned entries survive eviction, so
  /// this keeps the store from filling up with them.
  final int maxPinned;

  /// A copy with the given fields replaced.
  PeekLimits copyWith({int? maxEntries, int? maxBodyBytes, int? maxPinned}) =>
      PeekLimits(
        maxEntries: maxEntries ?? this.maxEntries,
        maxBodyBytes: maxBodyBytes ?? this.maxBodyBytes,
        maxPinned: maxPinned ?? this.maxPinned,
      );

  @override
  bool operator ==(Object other) =>
      other is PeekLimits &&
      other.maxEntries == maxEntries &&
      other.maxBodyBytes == maxBodyBytes &&
      other.maxPinned == maxPinned;

  @override
  int get hashCode => Object.hash(maxEntries, maxBodyBytes, maxPinned);

  @override
  String toString() =>
      'PeekLimits($maxEntries entries, $maxBodyBytes body bytes, '
      '$maxPinned pinned)';
}
