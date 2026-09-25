import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';

import '../support/entries.dart';

void main() {
  const codec = PeekCodec();

  // Through JSON text, the way a file or a frame carries it.
  Object? viaJson(Object? value) => jsonDecode(jsonEncode(value));

  PeekEntry roundTrip(PeekEntry entry) =>
      codec.decodeEntry(viaJson(codec.encodeEntry(entry)));

  PeekBody bodyRoundTrip(PeekBody body) =>
      codec.decodeBody(viaJson(codec.encodeBody(body)));

  group('PeekCodec', () {
    test('reads back every fixture as it was written', () {
      for (final entry in uiFixtures) {
        expect(roundTrip(entry), entry, reason: entry.id.value);
      }
    });

    test('reads back each part of every fixture on its own', () {
      for (final entry in uiFixtures) {
        final reason = entry.id.value;
        final request = entry.request;
        expect(
          codec.decodeRequest(viaJson(codec.encodeRequest(request))),
          request,
          reason: reason,
        );
        expect(
          codec.decodeHeaders(viaJson(codec.encodeHeaders(request.headers))),
          request.headers,
          reason: reason,
        );
        expect(bodyRoundTrip(request.body), request.body, reason: reason);

        if (entry.response case final response?) {
          expect(
            codec.decodeResponse(viaJson(codec.encodeResponse(response))),
            response,
            reason: reason,
          );
          expect(bodyRoundTrip(response.body), response.body, reason: reason);
          for (final redirect in response.redirects) {
            expect(
              codec.decodeRedirect(viaJson(codec.encodeRedirect(redirect))),
              redirect,
              reason: reason,
            );
          }
        }
        if (entry.failure case final failure?) {
          expect(
            codec.decodeFailure(viaJson(codec.encodeFailure(failure))),
            failure,
            reason: reason,
          );
        }
      }
    });

    test('writes short keys and leaves out what is empty', () {
      expect(codec.encodeEntry(e1), {
        'id': 'e1',
        'source': 'dio',
        'startedAt': '2026-09-10T12:00:00.000Z',
        'completedAt': '2026-09-10T12:00:00.120Z',
        'request': {'method': 'GET', 'url': 'https://api.example.com/users'},
        'response': {
          'status': 200,
          'headers': [
            ['Content-Type', 'application/json; charset=utf-8'],
          ],
          'body': {
            'kind': 'text',
            'text': 'body of e1',
            'type': 'application/json; charset=utf-8',
          },
        },
      });
      expect(codec.encodeEntry(e4).keys, [
        'id',
        'source',
        'startedAt',
        'request',
      ]);
      expect(codec.encodeEntry(e5), {
        'id': 'e5',
        'source': 'talker',
        'startedAt': '2026-09-10T12:00:04.000Z',
        'completedAt': '2026-09-10T12:00:09.000Z',
        'pinned': true,
        'request': {
          'method': 'DELETE',
          'url': 'https://api.example.com/users/1',
        },
        'failure': {'kind': 'timeout', 'message': 'slow'},
      });
    });

    test('reads back a call with every field set', () {
      const timings = PeekTimings(
        dns: Duration(microseconds: 1500),
        connect: Duration(milliseconds: 20),
        wait: Duration(milliseconds: 120),
      );
      final entry = PeekEntry(
        id: const PeekId('full'),
        request: PeekRequest(
          method: 'PUT',
          uri: Uri.parse('https://api.example.com/items/7?draft=true'),
          headers: PeekHeaders.fromMap({'Authorization': 'Bearer abc'}),
          body: PeekBody.fromJsonLike({'name': 'Pen'}),
          extra: {'client': 'http', 'attempt': 2},
        ),
        startedAt: fixtureStart,
        source: 'http',
        response: PeekResponse(statusCode: 500, statusMessage: ''),
        failure: const PeekFailure(
          kind: PeekFailureKind.badResponse,
          message: 'Server error',
        ),
        completedAt: fixtureStart.add(const Duration(microseconds: 1234567)),
        isPinned: true,
        timings: timings,
      );

      expect(roundTrip(entry), entry);
      expect(
        codec.encodeEntry(entry)['completedAt'],
        '2026-09-10T12:00:01.234567Z',
      );
    });

    test('ignores keys it does not know', () {
      final json = viaJson(codec.encodeEntry(upload)) as Map<String, Object?>;
      final request = json['request']! as Map<String, Object?>;
      final response = json['response']! as Map<String, Object?>;
      json['priority'] = 'high';
      request['protocol'] = 'h3';
      (request['body']! as Map<String, Object?>)['encoding'] = 'gzip';
      (response['body']! as Map<String, Object?>)['preview'] = {'lines': 1};
      response['cached'] = false;

      expect(codec.decodeEntry(json), upload);
      expect(
        codec.decodeTimings({'dns': 3, 'quic': 1}),
        const PeekTimings(dns: Duration(milliseconds: 3)),
      );
    });

    test('reads an unknown failure kind as unknown', () {
      final failure = codec.decodeFailure({
        'kind': 'dnsLookup',
        'message': 'no such host',
      });
      expect(failure.kind, PeekFailureKind.unknown);
      expect(failure.message, 'no such host');
      expect(
        codec.decodeFailure({'message': 'no kind at all'}).kind,
        PeekFailureKind.unknown,
      );
    });

    test('keeps what it can of a failure it cannot carry whole', () {
      final failure = PeekFailure(
        kind: PeekFailureKind.connection,
        message: 'Connection refused',
        details: const FormatException('bad header'),
        stackTrace: StackTrace.fromString('#0 main (file.dart:1:1)'),
      );
      final decoded = codec.decodeFailure(
        viaJson(codec.encodeFailure(failure)),
      );
      expect(decoded.kind, PeekFailureKind.connection);
      expect(decoded.message, 'Connection refused');
      expect(decoded.details, 'FormatException: bad header');
      expect(decoded.stackTrace.toString(), '#0 main (file.dart:1:1)');
    });

    test('writes an empty body only when asked for one on its own', () {
      final request = PeekRequest(
        method: 'GET',
        uri: Uri.parse('https://api.example.com/'),
      );
      expect(codec.encodeRequest(request), {
        'method': 'GET',
        'url': 'https://api.example.com/',
      });
      expect(codec.encodeBody(const PeekBody.empty()), {'kind': 'empty'});
      expect(bodyRoundTrip(const PeekBody.empty()), const PeekBody.empty());
      expect(
        codec.decodeRequest({'method': 'GET', 'url': 'https://a.example/'}),
        PeekRequest(method: 'GET', uri: Uri.parse('https://a.example/')),
      );

      final emptyText = PeekBody.text('');
      expect(bodyRoundTrip(emptyText), emptyText);
    });

    test('carries multibyte text as it is and keeps the full size', () {
      const text = 'Привет, 世界 👋';
      final whole = PeekBody.text(text, contentType: PeekMediaType.plainText);
      final prefix = PeekBody.text(
        text,
        contentType: PeekMediaType.plainText,
        size: 4096,
      );

      expect(bodyRoundTrip(whole), whole);
      expect(bodyRoundTrip(prefix), prefix);
      expect(bodyRoundTrip(prefix).isTruncated, isTrue);
      expect(codec.encodeBody(whole).containsKey('size'), isFalse);
      expect(codec.encodeBody(prefix)['size'], 4096);
      expect(jsonEncode(codec.encodeBody(whole)), contains(text));
    });

    test('carries bytes as base64', () {
      final png = PeekBody.bytes(
        transparentPixelPng,
        contentType: PeekMediaType.tryParse('image/png'),
      );
      expect(codec.encodeBody(png)['bytes'], base64Encode(transparentPixelPng));
      expect(bodyRoundTrip(png), png);

      final prefix = PeekBody.bytes(Uint8List.fromList([1, 2, 3]), size: 1000);
      expect(bodyRoundTrip(prefix), prefix);
      expect(codec.encodeBody(prefix)['size'], 1000);

      expect(
        () => codec.decodeBody({'kind': 'bytes', 'bytes': 'not base64!'}),
        throwsFormatException,
      );
    });

    test('reads back every reason a body is missing', () {
      for (final reason in PeekBodyUnavailableReason.values) {
        final body = PeekBody.unavailable(
          reason,
          contentType: PeekMediaType.octetStream,
          size: 10,
        );
        expect(bodyRoundTrip(body), body, reason: reason.name);
      }
      expect(
        bodyRoundTrip(
          const PeekBody.unavailable(PeekBodyUnavailableReason.tooLarge),
        ),
        const PeekBody.unavailable(PeekBodyUnavailableReason.tooLarge),
      );
      expect(
        codec.decodeBody({'kind': 'unavailable', 'reason': 'quota'}),
        const PeekBody.unavailable(PeekBodyUnavailableReason.notCaptured),
      );
    });

    test('writes a body held elsewhere and reads it back', () {
      const body = PeekBody.remote(size: 2048, contentType: PeekMediaType.json);
      expect(codec.encodeBody(body), {
        'kind': 'remote',
        'size': 2048,
        'type': 'application/json',
      });
      expect(bodyRoundTrip(body), body);

      const cut = PeekBody.remote(size: 9, isTruncated: true);
      expect(codec.encodeBody(cut), {
        'kind': 'remote',
        'size': 9,
        'truncated': true,
      });
      expect(bodyRoundTrip(cut), cut);

      expect(() => codec.decodeBody({'kind': 'remote'}), throwsFormatException);
    });

    test('reads a body kind from a newer writer as not captured', () {
      expect(
        codec.decodeBody({
          'kind': 'hologram',
          'type': 'application/json',
          'size': 2048,
        }),
        const PeekBody.unavailable(
          PeekBodyUnavailableReason.notCaptured,
          contentType: PeekMediaType.json,
          size: 2048,
        ),
      );
    });

    test('keeps repeated headers, their order and their casing', () {
      final headers = PeekHeaders.fromEntries(const [
        MapEntry('Set-Cookie', 'a=1; Path=/'),
        MapEntry('X-Trace', 'abc'),
        MapEntry('set-cookie', 'b=2'),
      ]);
      final json = codec.encodeHeaders(headers);
      expect(json, [
        ['Set-Cookie', 'a=1; Path=/'],
        ['Set-Cookie', 'b=2'],
        ['X-Trace', 'abc'],
      ]);

      final decoded = codec.decodeHeaders(viaJson(json));
      expect(decoded, headers);
      expect(decoded.names, ['Set-Cookie', 'X-Trace']);
      expect(decoded.setCookies, headers.setCookies);
    });

    test('reads back a form with its fields and files', () {
      final form = PeekBody.form(
        fields: const [PeekFormField('a', '1'), PeekFormField('a', '2')],
        files: [
          const PeekFormFile('doc'),
          PeekFormFile(
            'photo',
            filename: 'beach.jpg',
            contentType: PeekMediaType.tryParse('image/jpeg'),
            size: 1024,
          ),
        ],
        contentType: PeekMediaType.multipartFormData,
      );
      expect(bodyRoundTrip(form), form);
      expect(codec.encodeFormFile(const PeekFormFile('doc')), {'name': 'doc'});
      expect(bodyRoundTrip(PeekBody.form()), PeekBody.form());
    });

    test('reads media types leniently', () {
      expect(codec.decodeMediaType(null), isNull);
      expect(codec.decodeMediaType('not a type'), isNull);
      expect(
        codec.decodeMediaType('Application/JSON; Charset=UTF-8'),
        PeekMediaType.tryParse('application/json; charset=UTF-8'),
      );
      expect(() => codec.decodeMediaType(42), throwsFormatException);
    });

    test('reads timings to the microsecond', () {
      const timings = PeekTimings(
        dns: Duration(microseconds: 1500),
        connect: Duration(milliseconds: 20),
        receive: Duration(microseconds: 1),
      );
      expect(codec.encodeTimings(timings), {
        'dns': 1.5,
        'connect': 20,
        'receive': 0.001,
      });
      expect(
        codec.decodeTimings(viaJson(codec.encodeTimings(timings))),
        timings,
      );
      expect(codec.decodeTimings(<String, Object?>{}), const PeekTimings());
    });

    test('writes extras JSON cannot hold through toString', () {
      final request = PeekRequest(
        method: 'GET',
        uri: Uri.parse('https://api.example.com/'),
        extra: {
          'client': 'dio',
          'attempt': 2,
          'cached': false,
          'ratio': 0.5,
          'none': null,
          'tags': ['a', 'b'],
          'nan': double.nan,
        },
      );
      expect(codec.encodeRequest(request)['extra'], {
        'client': 'dio',
        'attempt': 2,
        'cached': false,
        'ratio': 0.5,
        'none': null,
        'tags': '[a, b]',
        'nan': 'NaN',
      });
    });

    test('writes times in UTC and reads them back in UTC', () {
      final local = DateTime(2026, 9, 10, 19, 30);
      final entry = PeekEntry(
        id: const PeekId('local'),
        request: PeekRequest(
          method: 'GET',
          uri: Uri.parse('https://api.example.com/'),
        ),
        startedAt: local,
        source: 'dio',
      );
      final json = codec.encodeEntry(entry);
      expect(json['startedAt'], local.toUtc().toIso8601String());

      final decoded = codec.decodeEntry(viaJson(json));
      expect(decoded.startedAt.isUtc, isTrue);
      expect(decoded.startedAt.isAtSameMomentAs(local), isTrue);
    });

    test('throws a FormatException on what it cannot read', () {
      final valid = codec.encodeEntry(e1);
      Map<String, Object?> without(String key) => {...valid}..remove(key);

      expect(() => codec.decodeEntry('an entry'), throwsFormatException);
      expect(() => codec.decodeEntry(without('id')), throwsFormatException);
      expect(
        () => codec.decodeEntry({...valid, 'id': ''}),
        throwsFormatException,
      );
      expect(
        () => codec.decodeEntry(without('request')),
        throwsFormatException,
      );
      expect(
        () => codec.decodeEntry({...valid, 'startedAt': 'yesterday'}),
        throwsFormatException,
      );
      expect(
        () => codec.decodeEntry({...valid, 'pinned': 'yes'}),
        throwsFormatException,
      );
      // A response without the time it arrived, and a time without an outcome.
      expect(
        () => codec.decodeEntry(without('completedAt')),
        throwsFormatException,
      );
      expect(
        () => codec.decodeEntry({
          ...codec.encodeEntry(e4),
          'completedAt': '2026-09-10T12:00:04.000Z',
        }),
        throwsFormatException,
      );
      expect(
        () => codec.decodeRequest({'method': 'GET', 'url': 42}),
        throwsFormatException,
      );
      expect(
        () => codec.decodeResponse({'status': '200'}),
        throwsFormatException,
      );
      expect(
        () => codec.decodeHeaders([
          ['Accept'],
        ]),
        throwsFormatException,
      );
      expect(
        () => codec.decodeBody({'text': 'no kind'}),
        throwsFormatException,
      );
    });
  });
}
