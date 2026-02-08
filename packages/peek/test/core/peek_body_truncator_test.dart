import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';

void main() {
  PeekTextBody text(PeekBody body) => body as PeekTextBody;

  group('PeekBodyTruncator.truncate', () {
    test('leaves bodies within budget as the same instance', () {
      const truncator = PeekBodyTruncator(5);
      final under = PeekTextBody('abc');
      final exact = PeekTextBody('abcde');
      final bytes = PeekBytesBody(Uint8List.fromList([1, 2, 3, 4, 5]));
      expect(identical(truncator.truncate(under), under), isTrue);
      expect(identical(truncator.truncate(exact), exact), isTrue);
      expect(identical(truncator.truncate(bytes), bytes), isTrue);
    });

    test('cuts text to the budget and keeps the wire size', () {
      final cut = text(
        const PeekBodyTruncator(5).truncate(PeekTextBody('abcdefgh')),
      );
      expect(cut.text, 'abcde');
      expect(cut.capturedSize, 5);
      expect(cut.size, 8);
      expect(cut.isTruncated, isTrue);
    });

    test('never cuts inside a multi-byte character', () {
      final cyrillic = PeekTextBody('привет');
      expect(text(const PeekBodyTruncator(5).truncate(cyrillic)).text, 'пр');
      expect(text(const PeekBodyTruncator(4).truncate(cyrillic)).text, 'пр');
      expect(text(const PeekBodyTruncator(3).truncate(cyrillic)).text, 'п');
      expect(text(const PeekBodyTruncator(1).truncate(cyrillic)).text, '');
      expect(text(const PeekBodyTruncator(1).truncate(cyrillic)).size, 12);
    });

    test('never splits a surrogate pair', () {
      final emoji = PeekTextBody('a😀b');
      expect(text(const PeekBodyTruncator(4).truncate(emoji)).text, 'a');
      expect(text(const PeekBodyTruncator(5).truncate(emoji)).text, 'a😀');
      expect(text(const PeekBodyTruncator(6).truncate(emoji)).text, 'a😀b');
    });

    test('keeps the original size of an already truncated body', () {
      final already = PeekTextBody('abcdef', size: 1000);
      final cut = text(const PeekBodyTruncator(3).truncate(already));
      expect(cut.text, 'abc');
      expect(cut.size, 1000);
    });

    test('keeps a content type and handles a zero budget', () {
      final body = PeekTextBody('{"a":1}', contentType: PeekMediaType.json);
      final cut = text(const PeekBodyTruncator(0).truncate(body));
      expect(cut.text, isEmpty);
      expect(cut.size, 7);
      expect(cut.isTruncated, isTrue);
      expect(cut.contentType, PeekMediaType.json);
    });

    test('cuts bytes to the budget and keeps the wire size', () {
      final png = PeekMediaType.tryParse('image/png');
      final body = PeekBytesBody(
        Uint8List.fromList([1, 2, 3, 4, 5, 6]),
        contentType: png,
      );
      final cut = const PeekBodyTruncator(4).truncate(body) as PeekBytesBody;
      expect(cut.bytes, [1, 2, 3, 4]);
      expect(cut.size, 6);
      expect(cut.isTruncated, isTrue);
      expect(cut.contentType, png);
    });

    test('leaves form, empty and unavailable bodies alone', () {
      const truncator = PeekBodyTruncator(0);
      final form = PeekFormBody(fields: const [PeekFormField('a', 'long')]);
      const empty = PeekBody.empty();
      const missing = PeekBody.unavailable(PeekBodyUnavailableReason.tooLarge);
      expect(identical(truncator.truncate(form), form), isTrue);
      expect(identical(truncator.truncate(empty), empty), isTrue);
      expect(identical(truncator.truncate(missing), missing), isTrue);
    });

    test('rejects a negative budget', () {
      expect(() => PeekBodyTruncator(-1), throwsAssertionError);
    });
  });

  group('PeekBodyTruncator on requests, responses and entries', () {
    const truncator = PeekBodyTruncator(3);
    final request = PeekRequest(
      method: 'POST',
      uri: Uri.parse('https://example.com/'),
      body: PeekBody.text('abcdef'),
    );
    final response = PeekResponse(statusCode: 200, body: PeekBody.text('xyz'));
    final entry = PeekEntry(
      id: const PeekId('e'),
      request: request,
      startedAt: DateTime.utc(2026),
      source: 'test',
      response: response,
      completedAt: DateTime.utc(2026),
    );

    test('cuts only what is over budget', () {
      final cutRequest = truncator.truncateRequest(request);
      expect(text(cutRequest.body).text, 'abc');
      expect(cutRequest.method, 'POST');
      expect(identical(truncator.truncateResponse(response), response), isTrue);

      final cutEntry = truncator.truncateEntry(entry);
      expect(text(cutEntry.request.body).text, 'abc');
      expect(identical(cutEntry.response, response), isTrue);
      expect(cutEntry.id, entry.id);
    });

    test('returns the same entry when nothing is over budget', () {
      final small = entry.copyWith(
        request: request.copyWith(body: PeekBody.text('ab')),
      );
      expect(identical(truncator.truncateEntry(small), small), isTrue);
    });
  });
}
