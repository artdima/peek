import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';

void main() {
  const exporter = PeekCurlExporter();
  final uri = Uri.parse('https://api.example.com/users?page=1&q=a%20b');

  PeekRequest request({
    String method = 'GET',
    Map<String, String> headers = const {},
    PeekBody body = const PeekBody.empty(),
  }) => PeekRequest(
    method: method,
    uri: uri,
    headers: PeekHeaders.fromMap(headers),
    body: body,
  );

  group('PeekCurlExporter', () {
    test('keeps a plain GET minimal', () {
      expect(
        exporter.exportRequest(request()),
        "curl 'https://api.example.com/users?page=1&q=a%20b'",
      );
    });

    test('spells out method, headers and a text body over lines', () {
      final command = exporter.exportRequest(
        request(
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': '*****',
          },
          body: PeekBody.text(
            '{"name":"Ann"}',
            contentType: PeekMediaType.json,
          ),
        ),
      );
      expect(
        command,
        "curl -X POST 'https://api.example.com/users?page=1&q=a%20b' \\\n"
        "  -H 'Content-Type: application/json' \\\n"
        "  -H 'Authorization: *****' \\\n"
        "  --data-raw '{\"name\":\"Ann\"}'",
      );
    });

    test('fits on one line when asked', () {
      const single = PeekCurlExporter(multiline: false);
      expect(
        single.exportRequest(
          request(method: 'DELETE', headers: {'Accept': '*/*'}),
        ),
        "curl -X DELETE 'https://api.example.com/users?page=1&q=a%20b' "
        "-H 'Accept: */*'",
      );
    });

    test('quotes single quotes the POSIX way', () {
      final command = exporter.exportRequest(
        request(
          method: 'POST',
          headers: {'X-Note': "it's \"quoted\""},
          body: PeekBody.text("{'a':'b'}"),
        ),
      );
      expect(command, contains("-H 'X-Note: it'\\''s \"quoted\"'"));
      expect(command, contains("--data-raw '{'\\''a'\\'':'\\''b'\\''}'"));
    });

    test('drops Content-Length and repeats multi-valued headers', () {
      final command = exporter.exportRequest(
        PeekRequest(
          method: 'GET',
          uri: uri,
          headers: PeekHeaders.fromMultiMap({
            'Content-Length': ['12'],
            'Accept': ['text/html', 'application/json'],
          }),
        ),
      );
      expect(command, isNot(contains('Content-Length')));
      expect(command, contains("-H 'Accept: text/html'"));
      expect(command, contains("-H 'Accept: application/json'"));
    });

    test('adds -X GET only when a GET carries data', () {
      expect(
        exporter.exportRequest(request(body: PeekBody.text('x'))),
        startsWith("curl -X GET 'https://"),
      );
      expect(
        exporter.exportRequest(
          request(
            body: const PeekBody.unavailable(
              PeekBodyUnavailableReason.streamed,
            ),
          ),
        ),
        "curl 'https://api.example.com/users?page=1&q=a%20b'\n"
        '# body not captured (streamed)',
      );
    });

    test('asks for headers only on HEAD', () {
      expect(
        exporter.exportRequest(request(method: 'HEAD')),
        "curl -I 'https://api.example.com/users?page=1&q=a%20b'",
      );
    });

    test('URL-encodes plain form fields', () {
      final command = exporter.exportRequest(
        request(
          method: 'POST',
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: PeekBody.form(
            fields: const [
              PeekFormField('user', 'ann smith'),
              PeekFormField('note', 'a&b=c'),
            ],
            contentType: PeekMediaType.formUrlEncoded,
          ),
        ),
      );
      expect(
        command,
        "curl -X POST 'https://api.example.com/users?page=1&q=a%20b' \\\n"
        "  -H 'Content-Type: application/x-www-form-urlencoded' \\\n"
        "  --data-urlencode 'user=ann smith' \\\n"
        "  --data-urlencode 'note=a&b=c'",
      );
    });

    test('sends multipart forms with -F and lets curl set the boundary', () {
      final command = exporter.exportRequest(
        request(
          method: 'POST',
          headers: {'Content-Type': 'multipart/form-data; boundary=xyz'},
          body: PeekBody.form(
            fields: const [PeekFormField('album', 'Holiday; 2026')],
            files: [
              PeekFormFile(
                'photo',
                filename: 'beach.jpg',
                contentType: PeekMediaType.tryParse('image/jpeg'),
              ),
              const PeekFormFile('raw'),
            ],
            contentType: PeekMediaType.multipartFormData,
          ),
        ),
      );
      expect(
        command,
        "curl -X POST 'https://api.example.com/users?page=1&q=a%20b' \\\n"
        "  --form-string 'album=Holiday; 2026' \\\n"
        "  -F 'photo=@beach.jpg;type=image/jpeg' \\\n"
        "  -F 'raw=@raw'\n"
        '# file contents are not captured; point @ at real files',
      );
    });

    test('treats a form with files as multipart even without a type', () {
      final command = exporter.exportRequest(
        request(
          method: 'POST',
          body: PeekBody.form(files: const [PeekFormFile('f', filename: 'x')]),
        ),
      );
      expect(command, contains("-F 'f=@x'"));
      expect(command, isNot(contains('--data-urlencode')));
    });

    test('points binary bodies at a file and says so', () {
      final command = exporter.exportRequest(
        request(
          method: 'PUT',
          body: PeekBody.bytes(
            Uint8List.fromList([1, 2, 3]),
            contentType: PeekMediaType.octetStream,
          ),
        ),
      );
      expect(
        command,
        "curl -X PUT 'https://api.example.com/users?page=1&q=a%20b' \\\n"
        "  --data-binary '@body.bin'\n"
        '# body.bin: 3 bytes of application/octet-stream, not exported',
      );
    });

    test('notes a truncated body after the command', () {
      final command = exporter.exportRequest(
        request(method: 'POST', body: PeekBody.text('abc', size: 1000)),
      );
      expect(
        command,
        endsWith("--data-raw 'abc'\n# body truncated: 3 of 1000 bytes"),
      );

      const single = PeekCurlExporter(multiline: false);
      expect(
        single.exportRequest(
          request(method: 'POST', body: PeekBody.text('abc', size: 1000)),
        ),
        endsWith("--data-raw 'abc' # body truncated: 3 of 1000 bytes"),
      );
    });

    test('exports an entry through its request', () {
      final entry = PeekEntry(
        id: const PeekId('e'),
        request: request(method: 'DELETE'),
        startedAt: DateTime.utc(2026),
        source: 'test',
      );
      expect(exporter.export(entry), exporter.exportRequest(entry.request));
      expect(exporter.export(entry), startsWith("curl -X DELETE 'https://"));
    });
  });
}
