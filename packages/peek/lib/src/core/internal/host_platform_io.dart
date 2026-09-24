import 'dart:io';

import 'os_version.dart';

/// The platform the app runs on, as a session header names it.
String hostPlatform() => Platform.operatingSystem;

/// The version of the operating system, where Dart reports one that reads
/// as a version: only Apple platforms do. Android reports the Linux kernel,
/// which says nothing about the device.
String? hostOsVersion() =>
    Platform.isIOS || Platform.isMacOS
        ? appleOsVersion(Platform.operatingSystemVersion)
        : null;
