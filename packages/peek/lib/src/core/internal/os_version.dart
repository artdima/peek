final RegExp _appleVersion = RegExp(r'^Version (\d+(?:\.\d+)*)');

/// The version number in what iOS and macOS report as their version, such
/// as `26.0` from `Version 26.0 (Build 25A354)`; `null` for anything else.
String? appleOsVersion(String reported) =>
    _appleVersion.firstMatch(reported.trim())?[1];
