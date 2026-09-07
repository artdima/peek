import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:peek/peek.dart';
import 'package:share_plus/share_plus.dart';

/// Hands Peek's exports to the platform's share sheet.
///
/// Peek depends on no sharing package: the app wires up whichever one it
/// already uses. This is what that wiring looks like with `share_plus`.
PeekShareDelegate buildShareDelegate() {
  return PeekShareDelegate.from((content) async {
    final file = XFile.fromData(
      Uint8List.fromList(utf8.encode(content.text)),
      mimeType: content.mimeType,
      name: content.filename,
    );
    await Share.shareXFiles(
      [file],
      subject: content.subject,
      sharePositionOrigin: content.origin ?? _anywhere,
    );
  });
}

/// iPadOS anchors the share sheet to a rectangle and refuses a zero one,
/// so a share triggered from nowhere in particular still needs somewhere.
const Rect _anywhere = Rect.fromLTWH(0, 0, 1, 1);
