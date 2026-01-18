import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';

void main() {
  group('PeekMediaType.tryParse', () {
    test('splits type, subtype and parameters', () {
      final type =
          PeekMediaType.tryParse('Application/JSON; Charset="UTF-8"; q=1')!;
      expect(type.type, 'application');
      expect(type.subtype, 'json');
      expect(type.mimeType, 'application/json');
      expect(type.parameters, {'charset': 'UTF-8', 'q': '1'});
      expect(type.charset, 'utf-8');
    });

    test('tolerates whitespace and skips broken parameters', () {
      final type =
          PeekMediaType.tryParse(
            '  text/plain ;charset = utf-8 ; ; flag; =nameless',
          )!;
      expect(type.mimeType, 'text/plain');
      expect(type.parameters, {'charset': 'utf-8'});
    });

    test('rejects values without a proper type/subtype', () {
      const broken = [
        null,
        '',
        'text',
        '/plain',
        'text/',
        'te xt/plain',
        'a/b/c',
        ';charset=utf-8',
      ];
      for (final value in broken) {
        expect(PeekMediaType.tryParse(value), isNull, reason: '$value');
      }
    });
  });

  group('PeekMediaType', () {
    test('normalises the case of type, subtype and parameter names', () {
      final type = PeekMediaType(
        'TEXT',
        ' Html ',
        parameters: {'Charset': 'ISO-8859-1'},
      );
      expect(type.mimeType, 'text/html');
      expect(type.parameters.keys, ['charset']);
      expect(type.parameters['charset'], 'ISO-8859-1');
      expect(type.charset, 'iso-8859-1');
      expect(type.parameters.clear, throwsUnsupportedError);
    });

    test('classifies common types', () {
      PeekMediaType parse(String value) => PeekMediaType.tryParse(value)!;

      expect(parse('application/json').isJson, isTrue);
      expect(parse('application/vnd.api+json').isJson, isTrue);
      expect(parse('text/json').isJson, isTrue);
      expect(parse('text/plain').isJson, isFalse);

      expect(parse('application/xml').isXml, isTrue);
      expect(parse('text/xml').isXml, isTrue);
      expect(parse('image/svg+xml').isXml, isTrue);
      expect(parse('application/json').isXml, isFalse);

      expect(parse('text/html').isHtml, isTrue);
      expect(parse('application/xhtml+xml').isHtml, isTrue);
      expect(parse('text/plain').isHtml, isFalse);

      expect(parse('image/png').isImage, isTrue);
      expect(parse('image/svg+xml').isImage, isTrue);
      expect(parse('video/mp4').isImage, isFalse);

      expect(parse('multipart/form-data; boundary=x').isMultipart, isTrue);
      expect(parse('multipart/mixed').isMultipart, isTrue);
      expect(parse('application/x-www-form-urlencoded').isMultipart, isFalse);

      expect(
        parse('application/x-www-form-urlencoded').isFormUrlEncoded,
        isTrue,
      );
      expect(parse('multipart/form-data').isFormUrlEncoded, isFalse);
    });

    test('knows which types can be shown as text', () {
      const textual = [
        'text/plain',
        'text/csv',
        'application/json',
        'application/problem+json',
        'application/xml',
        'image/svg+xml',
        'application/javascript',
        'application/x-www-form-urlencoded',
        'application/graphql',
        'application/x-ndjson',
        'application/yaml',
      ];
      const binary = [
        'image/png',
        'application/octet-stream',
        'application/pdf',
        'multipart/form-data',
        'audio/mpeg',
      ];
      for (final value in textual) {
        expect(PeekMediaType.tryParse(value)!.isText, isTrue, reason: value);
      }
      for (final value in binary) {
        expect(PeekMediaType.tryParse(value)!.isText, isFalse, reason: value);
      }
    });

    test('prints back as a Content-Type value', () {
      expect(
        PeekMediaType.tryParse('application/json; charset=utf-8').toString(),
        'application/json; charset=utf-8',
      );
      expect(PeekMediaType.json.toString(), 'application/json');
    });

    test('compares by normalised content', () {
      expect(PeekMediaType.tryParse('Application/Json'), PeekMediaType.json);
      expect(
        PeekMediaType.tryParse('Application/Json').hashCode,
        PeekMediaType.json.hashCode,
      );
      expect(
        PeekMediaType.tryParse('application/json; charset=utf-8'),
        isNot(PeekMediaType.json),
      );
      expect(PeekMediaType.json, isNot(PeekMediaType.plainText));
    });

    test('offers constants for the usual suspects', () {
      expect(PeekMediaType.plainText.mimeType, 'text/plain');
      expect(PeekMediaType.html.isHtml, isTrue);
      expect(PeekMediaType.octetStream.isText, isFalse);
      expect(PeekMediaType.formUrlEncoded.isFormUrlEncoded, isTrue);
      expect(PeekMediaType.multipartFormData.isMultipart, isTrue);
    });
  });
}
