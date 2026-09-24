import 'package:meta/meta.dart';

import '../internal/host_platform.dart'
    if (dart.library.io) '../internal/host_platform_io.dart'
    if (dart.library.js_interop) '../internal/host_platform_web.dart';
import '../version.dart';

// Inside the class the field of the same name hides the package constant.
const String _thisPeekVersion = peekVersion;

/// The first line of a session: which Peek wrote it, for which app, when.
///
/// Dart alone cannot learn an app's name, its bundle id or the device model,
/// so the header holds only what it can: the platform, the version of the
/// operating system where it reads as one, and the name the app gave itself
/// in `PeekOptions.name`.
@immutable
final class PeekSessionHeader {
  /// Creates a header; the versions default to this Peek's.
  const PeekSessionHeader({
    required this.platform,
    required this.startedAt,
    this.name,
    this.osVersion,
    this.peekVersion = _thisPeekVersion,
    this.formatVersion = currentFormatVersion,
  });

  /// Describes the app Peek runs in: its platform and, on iOS and macOS,
  /// the version of the operating system.
  factory PeekSessionHeader.current({
    required DateTime startedAt,
    String? name,
  }) => PeekSessionHeader(
    platform: hostPlatform(),
    osVersion: hostOsVersion(),
    startedAt: startedAt,
    name: name,
  );

  /// The version of the session format this Peek writes.
  ///
  /// It changes only when a reader would get the file wrong, and apart from
  /// the package version: a reader takes a newer format as far as it can
  /// and refuses an older one.
  static const int currentFormatVersion = 1;

  /// The version of the session format the file is written in.
  final int formatVersion;

  /// The version of the Peek that wrote the file.
  final String peekVersion;

  /// What the app calls itself, when it said so.
  final String? name;

  /// Where the app ran: `android`, `ios`, `macos`, `windows`, `linux`,
  /// `fuchsia` or `web`, and `unknown` when Peek could not tell. Readers
  /// should expect other values from newer writers.
  final String platform;

  /// The version of the operating system, such as `26.0`; `null` where Dart
  /// does not report one that reads as a version.
  final String? osVersion;

  /// When the session began.
  final DateTime startedAt;

  /// Whether a newer Peek wrote the file, which may then hold more than
  /// this one can read.
  bool get isNewerFormat => formatVersion > currentFormatVersion;

  @override
  bool operator ==(Object other) =>
      other is PeekSessionHeader &&
      other.formatVersion == formatVersion &&
      other.peekVersion == peekVersion &&
      other.name == name &&
      other.platform == platform &&
      other.osVersion == osVersion &&
      other.startedAt == startedAt;

  @override
  int get hashCode => Object.hash(
    formatVersion,
    peekVersion,
    name,
    platform,
    osVersion,
    startedAt,
  );

  @override
  String toString() {
    final system = osVersion == null ? platform : '$platform $osVersion';
    return 'PeekSessionHeader(${name ?? '-'}, $system, '
        'format $formatVersion)';
  }
}
