import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';

void main() {
  group('PeekStatusClass', () {
    test('is the first digit of the code', () {
      const expected = {
        100: PeekStatusClass.informational,
        101: PeekStatusClass.informational,
        200: PeekStatusClass.success,
        204: PeekStatusClass.success,
        299: PeekStatusClass.success,
        301: PeekStatusClass.redirect,
        304: PeekStatusClass.redirect,
        400: PeekStatusClass.clientError,
        404: PeekStatusClass.clientError,
        499: PeekStatusClass.clientError,
        500: PeekStatusClass.serverError,
        503: PeekStatusClass.serverError,
        599: PeekStatusClass.serverError,
      };
      for (final entry in expected.entries) {
        expect(
          PeekStatusClass.of(entry.key),
          entry.value,
          reason: '${entry.key}',
        );
      }
    });

    test('calls everything outside 100–599 unknown', () {
      for (final code in [0, -1, 99, 600, 999]) {
        expect(
          PeekStatusClass.of(code),
          PeekStatusClass.unknown,
          reason: '$code',
        );
      }
    });

    test('treats only 4xx and 5xx as errors', () {
      expect(PeekStatusClass.clientError.isError, isTrue);
      expect(PeekStatusClass.serverError.isError, isTrue);
      expect(PeekStatusClass.success.isError, isFalse);
      expect(PeekStatusClass.redirect.isError, isFalse);
      expect(PeekStatusClass.informational.isError, isFalse);
      expect(PeekStatusClass.unknown.isError, isFalse);
    });
  });
}
