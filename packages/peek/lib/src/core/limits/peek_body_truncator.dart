import 'dart:typed_data';

import '../internal/utf8.dart';
import '../model/peek_body.dart';
import '../model/peek_entry.dart';
import '../model/peek_request.dart';
import '../model/peek_response.dart';

/// Cuts bodies down to a byte budget, keeping their size on the wire so
/// they read as truncated rather than small.
///
/// Text is cut between characters, never inside a multi-byte sequence or a
/// surrogate pair. Bodies within budget come back as the same instance.
final class PeekBodyTruncator {
  /// Creates a truncator that keeps at most [maxBytes] of each body.
  const PeekBodyTruncator(this.maxBytes)
    : assert(maxBytes >= 0, 'maxBytes must not be negative');

  /// The most bytes kept of any single body.
  final int maxBytes;

  /// Cuts the bodies of [entry].
  PeekEntry truncateEntry(PeekEntry entry) {
    final response = entry.response;
    final request = truncateRequest(entry.request);
    final cut = response == null ? null : truncateResponse(response);
    if (identical(request, entry.request) && identical(cut, response)) {
      return entry;
    }
    return entry.copyWith(request: request, response: cut);
  }

  /// Cuts the body of [request].
  PeekRequest truncateRequest(PeekRequest request) {
    final body = truncate(request.body);
    return identical(body, request.body)
        ? request
        : request.copyWith(body: body);
  }

  /// Cuts the body of [response].
  PeekResponse truncateResponse(PeekResponse response) {
    final body = truncate(response.body);
    return identical(body, response.body)
        ? response
        : response.copyWith(body: body);
  }

  /// Cuts [body] if it holds more than [maxBytes].
  PeekBody truncate(PeekBody body) => switch (body) {
    PeekTextBody() when body.capturedSize > maxBytes => _cutText(body),
    PeekBytesBody() when body.bytes.length > maxBytes => PeekBody.bytes(
      Uint8List.sublistView(body.bytes, 0, maxBytes),
      contentType: body.contentType,
      size: body.size,
    ),
    _ => body,
  };

  PeekBody _cutText(PeekTextBody body) {
    final runes = body.text.runes.iterator;
    var bytes = 0;
    var end = 0;
    while (runes.moveNext()) {
      final width = utf8Width(runes.current);
      if (bytes + width > maxBytes) break;
      bytes += width;
      end = runes.rawIndex + runes.currentSize;
    }
    return PeekBody.text(
      body.text.substring(0, end),
      contentType: body.contentType,
      size: body.size,
    );
  }
}
