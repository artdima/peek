import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';

void main() {
  group('PeekBody.empty', () {
    test('has nothing and knows it', () {
      const body = PeekBody.empty();
      expect(body, isA<PeekEmptyBody>());
      expect(body.size, 0);
      expect(body.isEmpty, isTrue);
      expect(body.isTruncated, isFalse);
      expect(body.contentType, isNull);
      expect(body, const PeekEmptyBody());
      expect(body.hashCode, const PeekEmptyBody().hashCode);
      expect(body.toString(), 'PeekEmptyBody()');
    });
  });

  group('PeekBody.text', () {
    test('measures its size in UTF-8 bytes', () {
      expect(PeekBody.text('hello'), isA<PeekTextBody>());
      expect(PeekTextBody('hello').size, 5);
      expect(PeekTextBody('hello').capturedSize, 5);
      expect(PeekTextBody('привет').size, 12);
      expect(PeekTextBody('a😀').size, 5);
      expect(PeekTextBody('').size, 0);
    });

    test('treats a larger size as truncation and ignores a smaller one', () {
      final truncated = PeekTextBody('abc', size: 100);
      expect(truncated.size, 100);
      expect(truncated.capturedSize, 3);
      expect(truncated.isTruncated, isTrue);

      final clamped = PeekTextBody('abc', size: 1);
      expect(clamped.size, 3);
      expect(clamped.isTruncated, isFalse);
    });

    test('is empty only without text', () {
      expect(PeekTextBody('').isEmpty, isTrue);
      expect(PeekTextBody(' ').isEmpty, isFalse);
    });

    test('compares by text, size and content type', () {
      final json = PeekTextBody('{}', contentType: PeekMediaType.json);
      final same = PeekTextBody('{}', contentType: PeekMediaType.json);
      expect(json, same);
      expect(json.hashCode, same.hashCode);
      expect(json, isNot(PeekTextBody('{}')));
      expect(json, isNot(PeekTextBody('{ }', contentType: PeekMediaType.json)));
      expect(
        json,
        isNot(PeekTextBody('{}', contentType: PeekMediaType.json, size: 9)),
      );
    });

    test('prints size and type, never the text', () {
      final body = PeekTextBody('secret', contentType: PeekMediaType.plainText);
      expect(body.toString(), 'PeekTextBody(6 B, text/plain)');
      expect(PeekTextBody('x').toString(), 'PeekTextBody(1 B, -)');
    });
  });

  group('PeekBody.bytes', () {
    test('copies the bytes and freezes the copy', () {
      final source = Uint8List.fromList([1, 2, 3]);
      final body = PeekBytesBody(source);
      source[0] = 9;
      expect(body.bytes, [1, 2, 3]);
      expect(() => body.bytes[0] = 9, throwsUnsupportedError);
    });

    test('measures and truncates like text', () {
      expect(PeekBody.bytes(Uint8List(0)), isA<PeekBytesBody>());

      final body = PeekBytesBody(Uint8List.fromList([1, 2, 3]));
      expect(body.size, 3);
      expect(body.isTruncated, isFalse);
      expect(body.isEmpty, isFalse);
      expect(PeekBytesBody(Uint8List(0)).isEmpty, isTrue);

      final truncated = PeekBytesBody(Uint8List.fromList([1]), size: 10);
      expect(truncated.isTruncated, isTrue);
      expect(PeekBytesBody(Uint8List.fromList([1, 2]), size: 1).size, 2);
    });

    test('compares by content', () {
      final png = PeekMediaType.tryParse('image/png');
      final body = PeekBytesBody(Uint8List.fromList([1, 2]), contentType: png);
      final same = PeekBytesBody(Uint8List.fromList([1, 2]), contentType: png);
      final swapped = PeekBytesBody(
        Uint8List.fromList([2, 1]),
        contentType: png,
      );
      expect(body, same);
      expect(body.hashCode, same.hashCode);
      expect(body, isNot(swapped));
      expect(body, isNot(PeekBytesBody(Uint8List.fromList([1, 2]))));
      expect(body.toString(), 'PeekBytesBody(2 B, image/png)');
    });
  });

  group('PeekBody.form', () {
    test('keeps fields and files in order, unmodifiable', () {
      expect(PeekBody.form(), isA<PeekFormBody>());

      final body = PeekFormBody(
        fields: const [PeekFormField('a', '1'), PeekFormField('b', '2')],
        files: const [PeekFormFile('avatar', filename: 'me.png', size: 1024)],
        contentType: PeekMediaType.multipartFormData,
      );
      expect(body.fields.map((field) => field.name), ['a', 'b']);
      expect(body.files.single.filename, 'me.png');
      expect(body.files.single.size, 1024);
      expect(body.size, isNull);
      expect(body.isTruncated, isFalse);
      expect(body.isEmpty, isFalse);
      expect(body.fields.clear, throwsUnsupportedError);
      expect(body.files.clear, throwsUnsupportedError);
      expect(body.toString(), 'PeekFormBody(2 fields, 1 files)');
    });

    test('is empty without fields and files', () {
      expect(PeekFormBody().isEmpty, isTrue);
      expect(
        PeekFormBody(fields: const [PeekFormField('a', '')]).isEmpty,
        isFalse,
      );
    });

    test('is detached from the source lists', () {
      final fields = <PeekFormField>[];
      fields.add(const PeekFormField('a', '1'));
      final body = PeekFormBody(fields: fields);
      fields.add(const PeekFormField('b', '2'));
      expect(body.fields, hasLength(1));
    });

    test('compares by fields, files and content type', () {
      final body = PeekFormBody(fields: const [PeekFormField('a', '1')]);
      final same = PeekFormBody(fields: const [PeekFormField('a', '1')]);
      expect(body, same);
      expect(body.hashCode, same.hashCode);
      expect(
        body,
        isNot(PeekFormBody(fields: const [PeekFormField('a', '2')])),
      );
      expect(
        body,
        isNot(
          PeekFormBody(
            fields: const [PeekFormField('a', '1')],
            contentType: PeekMediaType.formUrlEncoded,
          ),
        ),
      );
      expect(
        body,
        isNot(
          PeekFormBody(
            fields: const [PeekFormField('a', '1')],
            files: const [PeekFormFile('f')],
          ),
        ),
      );
    });
  });

  group('PeekFormField and PeekFormFile', () {
    test('compare by value and print their names only', () {
      expect(const PeekFormField('a', '1'), const PeekFormField('a', '1'));
      expect(
        const PeekFormField('a', '1'),
        isNot(const PeekFormField('a', '2')),
      );
      expect(const PeekFormField('a', 'secret').toString(), 'PeekFormField(a)');

      const file = PeekFormFile('f', filename: 'x.png', size: 1);
      expect(file, const PeekFormFile('f', filename: 'x.png', size: 1));
      expect(
        file.hashCode,
        const PeekFormFile('f', filename: 'x.png', size: 1).hashCode,
      );
      expect(file, isNot(const PeekFormFile('f', filename: 'x.png')));
      expect(file.toString(), 'PeekFormFile(f, x.png)');
      expect(const PeekFormFile('f').toString(), 'PeekFormFile(f, -)');
    });
  });

  group('PeekBody.unavailable', () {
    test('carries the reason and what little is known', () {
      const body = PeekUnavailableBody(
        PeekBodyUnavailableReason.streamed,
        size: 4096,
      );
      expect(body.reason, PeekBodyUnavailableReason.streamed);
      expect(body.size, 4096);
      expect(body.isEmpty, isFalse);
      expect(body.isTruncated, isFalse);
      expect(body.contentType, isNull);
      expect(
        body,
        const PeekBody.unavailable(
          PeekBodyUnavailableReason.streamed,
          size: 4096,
        ),
      );
      expect(
        body,
        isNot(
          const PeekUnavailableBody(
            PeekBodyUnavailableReason.tooLarge,
            size: 4096,
          ),
        ),
      );
      expect(body.toString(), 'PeekUnavailableBody(streamed)');
    });
  });

  group('PeekBody.fromJsonLike', () {
    test('encodes maps and lists as compact JSON', () {
      expect(
        PeekBody.fromJsonLike({
          'a': [1, 2],
          'b': null,
        }),
        isA<PeekTextBody>()
            .having((body) => body.text, 'text', '{"a":[1,2],"b":null}')
            .having(
              (body) => body.contentType,
              'contentType',
              PeekMediaType.json,
            ),
      );
      expect(
        PeekBody.fromJsonLike([1, 'x']),
        isA<PeekTextBody>().having((body) => body.text, 'text', '[1,"x"]'),
      );
    });

    test('wraps scalars and stringifies what JSON cannot hold', () {
      expect(
        PeekBody.fromJsonLike('str'),
        isA<PeekTextBody>().having((body) => body.text, 'text', '"str"'),
      );
      expect(
        PeekBody.fromJsonLike(42),
        isA<PeekTextBody>().having((body) => body.text, 'text', '42'),
      );
      expect(
        PeekBody.fromJsonLike({'when': DateTime.utc(2026)}),
        isA<PeekTextBody>().having(
          (body) => body.text,
          'text',
          '{"when":"2026-01-01 00:00:00.000Z"}',
        ),
      );
    });

    test('turns null into an empty body and honours a custom type', () {
      expect(PeekBody.fromJsonLike(null), const PeekBody.empty());

      final problem = PeekMediaType.tryParse('application/problem+json');
      expect(
        PeekBody.fromJsonLike(<String, Object?>{}, contentType: problem),
        isA<PeekTextBody>().having(
          (body) => body.contentType,
          'contentType',
          problem,
        ),
      );
    });
  });

  group('PeekBody', () {
    test('is exhaustively switchable', () {
      String describe(PeekBody body) => switch (body) {
        PeekTextBody() => 'text',
        PeekBytesBody() => 'bytes',
        PeekFormBody() => 'form',
        PeekEmptyBody() => 'empty',
        PeekUnavailableBody() => 'unavailable',
      };

      expect(describe(PeekBody.text('')), 'text');
      expect(describe(PeekBody.bytes(Uint8List(0))), 'bytes');
      expect(describe(PeekBody.form()), 'form');
      expect(describe(const PeekBody.empty()), 'empty');
      expect(
        describe(
          const PeekBody.unavailable(PeekBodyUnavailableReason.notCaptured),
        ),
        'unavailable',
      );
    });
  });
}
