import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';

import '../support/entries.dart';

void main() {
  const exporter = PeekMarkdownExporter();
  final started = DateTime.utc(2026, 9, 10, 12);

  PeekEntry entry({
    PeekBody requestBody = const PeekBody.empty(),
    Map<String, String> requestHeaders = const {},
    PeekResponse? response,
    PeekFailure? failure,
  }) => PeekEntry(
    id: const PeekId('e'),
    request: PeekRequest(
      method: 'POST',
      uri: Uri.parse('https://api.example.com/login'),
      headers: PeekHeaders.fromMap(requestHeaders),
      body: requestBody,
    ),
    startedAt: started,
    source: 'dio',
    response: response,
    failure: failure,
    completedAt:
        response == null && failure == null
            ? null
            : started.add(const Duration(milliseconds: 250)),
  );

  group('PeekMarkdownExporter', () {
    test('writes a heading, a summary table and both halves', () {
      expect(
        exporter.export(
          entry(
            requestHeaders: {'Content-Type': 'application/json'},
            requestBody: PeekBody.text(
              '{"user":"ann"}',
              contentType: PeekMediaType.json,
            ),
            response: PeekResponse(
              statusCode: 200,
              statusMessage: 'OK',
              headers: PeekHeaders.fromMap({'Content-Type': 'text/html'}),
              body: PeekBody.text('<b>hi</b>', contentType: PeekMediaType.html),
            ),
          ),
        ),
        '### POST https://api.example.com/login\n'
        '\n'
        '| Field | Value |\n'
        '| --- | --- |\n'
        '| Outcome | `200` OK |\n'
        '| Duration | 250 ms |\n'
        '| Request | 14 B |\n'
        '| Response | 9 B |\n'
        '| Started | 2026-09-10T12:00:00.000Z |\n'
        '| Source | `dio` |\n'
        '\n'
        '#### Request\n'
        '\n'
        '| Header | Value |\n'
        '| --- | --- |\n'
        '| `Content-Type` | application/json |\n'
        '\n'
        '```json\n'
        '{"user":"ann"}\n'
        '```\n'
        '\n'
        '#### Response\n'
        '\n'
        '| Header | Value |\n'
        '| --- | --- |\n'
        '| `Content-Type` | text/html |\n'
        '\n'
        '```html\n'
        '<b>hi</b>\n'
        '```',
      );
    });

    test('tags fences by media type and leaves unknown ones bare', () {
      String fenceOf(PeekMediaType? type) => exporter
          .export(entry(requestBody: PeekBody.text('x', contentType: type)))
          .split('\n')
          .firstWhere((line) => line.startsWith('```'));

      expect(fenceOf(PeekMediaType.json), '```json');
      expect(fenceOf(PeekMediaType.tryParse('application/xml')), '```xml');
      expect(fenceOf(PeekMediaType.html), '```html');
      expect(fenceOf(PeekMediaType.plainText), '```');
      expect(fenceOf(null), '```');
    });

    test('escapes pipes so the header table survives', () {
      final markdown = exporter.export(
        entry(requestHeaders: {'Accept': 'a|b'}),
      );
      expect(markdown, contains(r'| `Accept` | a\|b |'));
    });

    test('says when there are no headers', () {
      expect(
        exporter.export(entry()),
        contains('#### Request\n\n_No headers._'),
      );
    });

    test('writes pending and failed outcomes', () {
      expect(exporter.export(entry()), contains('| Outcome | Pending |'));
      expect(
        exporter.export(
          entry(
            failure: const PeekFailure(
              kind: PeekFailureKind.timeout,
              message: 'too slow',
              details: 'after 30s',
            ),
          ),
        ),
        contains(
          '#### Error\n'
          '\n'
          '**timeout** — too slow\n'
          '\n'
          '```\n'
          'after 30s\n'
          '```',
        ),
      );
    });

    test('handles every fixture without throwing', () {
      for (final fixture in fixtures) {
        expect(exporter.export(fixture), startsWith('### '));
      }
    });
  });

  group('PeekExporters', () {
    test('offers every format from one place', () {
      final value = entry(response: PeekResponse(statusCode: 200));
      expect(PeekExporters.url(value), 'https://api.example.com/login');
      expect(PeekExporters.curl.export(value), startsWith('curl -X POST'));
      expect(PeekExporters.text.export(value), startsWith('POST https://'));
      expect(PeekExporters.markdown.export(value), startsWith('### POST'));
      expect(PeekExporters.har.export([value]), startsWith('{"log":'));
    });
  });
}
