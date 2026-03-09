import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';

import '../support/entries.dart';

void main() {
  const exporter = PeekHarExporter();

  Map<String, Object?> log(Iterable<PeekEntry> entries) =>
      exporter.toJson(entries)['log']! as Map<String, Object?>;

  List<Map<String, Object?>> entriesOf(Iterable<PeekEntry> entries) =>
      (log(entries)['entries']! as List<Object?>).cast<Map<String, Object?>>();

  Map<String, Object?> single(PeekEntry entry) => entriesOf([entry]).single;

  final started = DateTime.utc(2026, 9, 10, 12);
  final rich = PeekEntry(
    id: const PeekId('rich'),
    request: PeekRequest(
      method: 'POST',
      uri: Uri.parse('https://api.example.com/items?q=a&q=b&page=2'),
      headers: PeekHeaders.fromMap({
        'Content-Type': 'application/json',
        'Cookie': 'sid=abc; theme=dark',
      }),
      body: PeekBody.text('{"name":"x"}', contentType: PeekMediaType.json),
    ),
    startedAt: started,
    source: 'dio',
    response: PeekResponse(
      statusCode: 201,
      statusMessage: 'Created',
      headers: PeekHeaders.fromMultiMap({
        'Content-Type': ['application/json; charset=utf-8'],
        'Location': ['https://api.example.com/items/9'],
        'Set-Cookie': ['sid=def; Path=/; HttpOnly'],
      }),
      body: PeekBody.text('{"id":9}', contentType: PeekMediaType.json),
    ),
    completedAt: started.add(const Duration(milliseconds: 250)),
  );

  group('PeekHarExporter', () {
    test('writes a HAR 1.2 log with Peek as the creator', () {
      final document = log(fixtures);
      expect(document['version'], '1.2');
      expect(document['creator'], {'name': 'Peek', 'version': peekVersion});
      expect(document['entries'], isA<List<Object?>>());
    });

    test('leaves pending calls out and keeps failed ones', () {
      final entries = entriesOf(fixtures);
      expect(entries, hasLength(5));
      expect(
        entries.map((entry) => (entry['_peek']! as Map<String, Object?>)['id']),
        ['e1', 'e2', 'e3', 'e5', 'e6'],
      );
    });

    test('maps the request half', () {
      final request = single(rich)['request']! as Map<String, Object?>;
      expect(request['method'], 'POST');
      expect(request['url'], 'https://api.example.com/items?q=a&q=b&page=2');
      expect(request['httpVersion'], 'HTTP/1.1');
      expect(request['headers'], [
        {'name': 'Content-Type', 'value': 'application/json'},
        {'name': 'Cookie', 'value': 'sid=abc; theme=dark'},
      ]);
      expect(request['cookies'], [
        {'name': 'sid', 'value': 'abc', 'httpOnly': false, 'secure': false},
        {'name': 'theme', 'value': 'dark', 'httpOnly': false, 'secure': false},
      ]);
      expect(request['queryString'], [
        {'name': 'q', 'value': 'a'},
        {'name': 'q', 'value': 'b'},
        {'name': 'page', 'value': '2'},
      ]);
      expect(request['postData'], {
        'mimeType': 'application/json',
        'text': '{"name":"x"}',
      });
      expect(request['headersSize'], -1);
      expect(request['bodySize'], 12);
    });

    test('maps the response half', () {
      final response = single(rich)['response']! as Map<String, Object?>;
      expect(response['status'], 201);
      expect(response['statusText'], 'Created');
      expect(response['redirectURL'], 'https://api.example.com/items/9');
      expect(response['cookies'], [
        {
          'name': 'sid',
          'value': 'def',
          'path': '/',
          'httpOnly': true,
          'secure': false,
        },
      ]);
      expect(response['content'], {
        'size': 8,
        'mimeType': 'application/json',
        'text': '{"id":9}',
      });
      expect(response['bodySize'], 8);
    });

    test('records when the call started and how long it took', () {
      final entry = single(rich);
      expect(entry['startedDateTime'], '2026-09-10T12:00:00.000Z');
      expect(entry['time'], 250.0);
      expect(entry['timings'], {
        'blocked': -1.0,
        'dns': -1.0,
        'connect': -1.0,
        'ssl': -1.0,
        'send': 0.0,
        'wait': 250.0,
        'receive': 0.0,
      });
      expect(entry['cache'], <String, Object?>{});
    });

    test('writes known phase timings in milliseconds', () {
      final timed = rich.copyWith(
        timings: const PeekTimings(
          dns: Duration(milliseconds: 3),
          connect: Duration(microseconds: 1500),
          send: Duration(milliseconds: 1),
          wait: Duration(milliseconds: 200),
          receive: Duration(milliseconds: 40),
        ),
      );
      expect(single(timed)['timings'], {
        'blocked': -1.0,
        'dns': 3.0,
        'connect': 1.5,
        'ssl': -1.0,
        'send': 1.0,
        'wait': 200.0,
        'receive': 40.0,
      });
    });

    test('base64-encodes binary bodies on both sides', () {
      final binary = PeekEntry(
        id: const PeekId('bin'),
        request: PeekRequest(
          method: 'PUT',
          uri: Uri.parse('https://example.com/blob'),
          body: PeekBody.bytes(Uint8List.fromList([1, 2, 3])),
        ),
        startedAt: started,
        source: 'dio',
        response: PeekResponse(
          statusCode: 200,
          body: PeekBody.bytes(
            Uint8List.fromList([255, 0]),
            contentType: PeekMediaType.octetStream,
          ),
        ),
        completedAt: started,
      );
      final entry = single(binary);
      final request = entry['request']! as Map<String, Object?>;
      final response = entry['response']! as Map<String, Object?>;
      expect(request['postData'], {
        'mimeType': 'application/octet-stream',
        'text': 'AQID',
        '_encoding': 'base64',
      });
      expect(response['content'], {
        'size': 2,
        'mimeType': 'application/octet-stream',
        'text': '/wA=',
        'encoding': 'base64',
      });
    });

    test('writes form bodies as params', () {
      final form = PeekEntry(
        id: const PeekId('form'),
        request: PeekRequest(
          method: 'POST',
          uri: Uri.parse('https://example.com/upload'),
          body: PeekBody.form(
            fields: const [PeekFormField('album', 'Holiday')],
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
        startedAt: started,
        source: 'dio',
        response: PeekResponse(statusCode: 204),
        completedAt: started,
      );
      final request = single(form)['request']! as Map<String, Object?>;
      expect(request['postData'], {
        'mimeType': 'multipart/form-data',
        'params': [
          {'name': 'album', 'value': 'Holiday'},
          {
            'name': 'photo',
            'fileName': 'beach.jpg',
            'contentType': 'image/jpeg',
          },
          {'name': 'raw'},
        ],
      });
      expect(request['bodySize'], -1);
      final response = single(form)['response']! as Map<String, Object?>;
      expect(response['content'], {'size': 0, 'mimeType': 'x-unknown'});
    });

    test('writes failures the way browsers do', () {
      final entry = single(e5);
      expect(entry['response'], {
        'status': 0,
        'statusText': '',
        'httpVersion': 'HTTP/1.1',
        'cookies': <Object?>[],
        'headers': <Object?>[],
        'content': {'size': 0, 'mimeType': 'x-unknown'},
        'redirectURL': '',
        'headersSize': -1,
        'bodySize': -1,
      });
      expect(entry['_error'], {'kind': 'timeout', 'message': 'slow'});
      expect(entry['time'], 5000.0);
      expect(single(rich).containsKey('_error'), isFalse);
    });

    test('marks truncated and missing bodies in comments', () {
      final cut = rich.copyWith(
        request: rich.request.copyWith(body: PeekBody.text('ab', size: 99)),
        response: rich.response!.copyWith(
          body: const PeekBody.unavailable(PeekBodyUnavailableReason.streamed),
        ),
      );
      final entry = single(cut);
      final request = entry['request']! as Map<String, Object?>;
      final response = entry['response']! as Map<String, Object?>;
      expect(request['postData'], {
        'mimeType': 'application/json',
        'text': 'ab',
        'comment': 'truncated by Peek',
      });
      expect(response['content'], {
        'size': -1,
        'mimeType': 'application/json',
        'comment': 'not captured by Peek (streamed)',
      });
    });

    test('exports valid JSON, compact or pretty', () {
      final compact = exporter.export(fixtures);
      final pretty = exporter.export(fixtures, pretty: true);
      expect(compact, isNot(contains('\n')));
      expect(pretty, contains('\n  "log": {\n'));
      expect(jsonDecode(compact), jsonDecode(pretty));
      expect(jsonDecode(compact), exporter.toJson(fixtures));
    });

    test('gives every entry the fields HAR 1.2 requires', () {
      const entryKeys = [
        'startedDateTime',
        'time',
        'request',
        'response',
        'cache',
        'timings',
      ];
      const requestKeys = [
        'method',
        'url',
        'httpVersion',
        'cookies',
        'headers',
        'queryString',
        'headersSize',
        'bodySize',
      ];
      const responseKeys = [
        'status',
        'statusText',
        'httpVersion',
        'cookies',
        'headers',
        'content',
        'redirectURL',
        'headersSize',
        'bodySize',
      ];
      const timingKeys = ['send', 'wait', 'receive'];

      for (final entry in entriesOf([...fixtures, rich])) {
        expect(entry.keys, containsAll(entryKeys));
        final request = entry['request']! as Map<String, Object?>;
        final response = entry['response']! as Map<String, Object?>;
        final timings = entry['timings']! as Map<String, Object?>;
        final content = response['content']! as Map<String, Object?>;
        expect(request.keys, containsAll(requestKeys));
        expect(response.keys, containsAll(responseKeys));
        expect(timings.keys, containsAll(timingKeys));
        expect(content.keys, containsAll(['size', 'mimeType']));
        for (final key in timingKeys) {
          expect(timings[key], isA<double>());
          expect(timings[key]! as double, isNonNegative);
        }
        expect(entry['time'], isA<double>());
      }
    });
  });
}
