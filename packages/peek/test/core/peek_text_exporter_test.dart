import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';

import '../support/entries.dart';

void main() {
  const exporter = PeekTextExporter();
  final started = DateTime.utc(2026, 9, 10, 12);

  PeekEntry entry({
    PeekBody requestBody = const PeekBody.empty(),
    Map<String, String> requestHeaders = const {},
    PeekResponse? response,
    PeekFailure? failure,
    Duration? took,
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
            : started.add(took ?? const Duration(milliseconds: 250)),
  );

  group('PeekTextExporter', () {
    test('writes a completed call in full', () {
      expect(
        exporter.export(
          entry(
            requestHeaders: {'Content-Type': 'application/json'},
            requestBody: PeekBody.text('{"user":"ann"}'),
            response: PeekResponse(
              statusCode: 200,
              statusMessage: 'OK',
              headers: PeekHeaders.fromMap({'Content-Length': '9'}),
              body: PeekBody.text('{"ok":1}'),
            ),
          ),
        ),
        'POST https://api.example.com/login\n'
        '200 OK · 250 ms · ↑ 14 B · ↓ 9 B · 2026-09-10T12:00:00.000Z · dio\n'
        '\n'
        '--- Request ---\n'
        'Content-Type: application/json\n'
        '\n'
        '{"user":"ann"}\n'
        '\n'
        '--- Response ---\n'
        'Content-Length: 9\n'
        '\n'
        '{"ok":1}',
      );
    });

    test('leaves out sizes nothing was sent or received in', () {
      final text = exporter.export(
        entry(response: PeekResponse(statusCode: 204)),
      );
      expect(text, isNot(contains('↑')));
      expect(text, isNot(contains('↓')));
      expect(text, contains('204 · 250 ms · 2026-09-10'));
    });

    test('says when a call is still pending', () {
      final text = exporter.export(entry());
      expect(
        text,
        'POST https://api.example.com/login\n'
        'Pending · 2026-09-10T12:00:00.000Z · dio\n'
        '\n'
        '--- Request ---\n'
        '(no headers)',
      );
      expect(text, isNot(contains('Response')));
    });

    test('writes failures with details and a trace', () {
      final trace = StackTrace.fromString('#0 main\n#1 run\n');
      final text = exporter.export(
        entry(
          failure: PeekFailure(
            kind: PeekFailureKind.connection,
            message: 'Connection reset',
            details: 'errno 54',
            stackTrace: trace,
          ),
          took: const Duration(seconds: 2),
        ),
      );
      expect(text, contains('Failed: connection · 2 s ·'));
      expect(
        text,
        endsWith(
          '--- Error ---\n'
          'connection: Connection reset\n'
          'Details: errno 54\n'
          '\n'
          '#0 main\n'
          '#1 run',
        ),
      );
    });

    test('describes bodies it cannot print', () {
      final binary = exporter.export(
        entry(
          requestBody: PeekBody.bytes(
            Uint8List(2048),
            contentType: PeekMediaType.octetStream,
          ),
        ),
      );
      expect(binary, contains('<2 KB of application/octet-stream>'));

      final missing = exporter.export(
        entry(
          requestBody: const PeekBody.unavailable(
            PeekBodyUnavailableReason.streamed,
          ),
        ),
      );
      expect(missing, contains('<body not captured: streamed>'));

      final form = exporter.export(
        entry(
          requestBody: PeekBody.form(
            fields: const [PeekFormField('album', 'Holiday')],
            files: const [
              PeekFormFile('photo', filename: 'beach.jpg', size: 4096),
              PeekFormFile('raw'),
            ],
          ),
        ),
      );
      expect(
        form,
        contains(
          'album: Holiday\n'
          'photo: <file beach.jpg, 4 KB>\n'
          'raw: <file >',
        ),
      );
    });

    test('skips empty bodies and cuts long ones', () {
      expect(exporter.export(entry()), isNot(contains('\n\n\n')));
      expect(
        exporter.export(entry(requestBody: PeekBody.text(''))),
        isNot(contains('---\n\n')),
      );

      const short = PeekTextExporter(maxBodyChars: 10);
      final cut = short.export(
        entry(requestBody: PeekBody.text('0123456789abcdef')),
      );
      expect(cut, contains('0123456789\n… 6 more characters'));
      expect(cut, isNot(contains('abcdef')));
    });

    test('formats sizes and durations by magnitude', () {
      String outcomeAfter(Duration took) =>
          exporter
              .export(
                entry(response: PeekResponse(statusCode: 204), took: took),
              )
              .split('\n')[1];

      expect(
        outcomeAfter(const Duration(microseconds: 900)),
        contains('900 µs'),
      );
      expect(
        outcomeAfter(const Duration(milliseconds: 1500)),
        contains('1.5 s'),
      );
      expect(outcomeAfter(const Duration(seconds: 90)), contains('1m 30s'));
      expect(
        exporter.export(entry(requestBody: PeekBody.bytes(Uint8List(1536)))),
        contains('↑ 1.5 KB'),
      );
      expect(
        exporter.export(
          entry(requestBody: PeekBody.bytes(Uint8List(3 * 1024 * 1024))),
        ),
        contains('↑ 3 MB'),
      );
    });

    test('handles every fixture without throwing', () {
      for (final fixture in fixtures) {
        expect(exporter.export(fixture), startsWith(fixture.request.method));
      }
    });
  });
}
