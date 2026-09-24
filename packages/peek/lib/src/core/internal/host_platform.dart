// Where neither dart:io nor the browser is available, Peek cannot tell.

/// The platform the app runs on, as a session header names it.
String hostPlatform() => 'unknown';

/// The version of the operating system, where Dart reports one that reads
/// as a version.
String? hostOsVersion() => null;
