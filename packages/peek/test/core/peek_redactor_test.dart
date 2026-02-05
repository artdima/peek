import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';

void main() {
  const redactor = PeekRedactor(PeekRedactionPolicy());
  const none = PeekRedactor(PeekRedactionPolicy.none);

  group('PeekRedactor.redactHeaders', () {
    test('masks matching headers whole, keeping casing and order', () {
      final headers = PeekHeaders.fromMultiMap({
        'Accept': ['application/json'],
        'Authorization': ['Bearer secret'],
        'X-API-Key': ['k1', 'k2'],
      });
      final redacted = redactor.redactHeaders(headers);
      expect(redacted.names, ['Accept', 'Authorization', 'X-API-Key']);
      expect(redacted['accept'], 'application/json');
      expect(redacted['authorization'], '*****');
      expect(redacted.valuesOf('x-api-key'), ['*****', '*****']);
    });

    test('keeps cookie names and Set-Cookie attributes', () {
      final headers = PeekHeaders.fromMultiMap({
        'Cookie': ['sid=abc123; theme=dark;flag'],
        'Set-Cookie': ['sid=abc123; Path=/; HttpOnly', 'plain'],
      });
      final redacted = redactor.redactHeaders(headers);
      expect(redacted['cookie'], 'sid=*****; theme=*****;flag');
      expect(redacted.valuesOf('set-cookie'), [
        'sid=*****; Path=/; HttpOnly',
        'plain',
      ]);
      expect(redacted.cookies.map((cookie) => cookie.name), [
        'sid',
        'theme',
        'flag',
      ]);
      expect(redacted.setCookies.single.path, '/');
    });

    test('returns the same instance when nothing matches', () {
      final headers = PeekHeaders.fromMap({'Accept': 'text/plain'});
      expect(identical(redactor.redactHeaders(headers), headers), isTrue);
      expect(
        identical(redactor.redactHeaders(PeekHeaders.empty), PeekHeaders.empty),
        isTrue,
      );
    });
  });

  group('PeekRedactor.redactUri', () {
    test('masks matching parameters and leaves the rest byte for byte', () {
      final uri = Uri.parse(
        'https://h/p?a=1&token=abc&b=x%20y&api_key&Key=v&c=d%2Be',
      );
      expect(
        redactor.redactUri(uri).toString(),
        'https://h/p?a=1&token=*****&b=x%20y&api_key=*****&Key=*****&c=d%2Be',
      );
    });

    test('returns the same instance without a query or a match', () {
      final bare = Uri.parse('https://h/p');
      final clean = Uri.parse('https://h/p?a=1&b=2');
      expect(identical(redactor.redactUri(bare), bare), isTrue);
      expect(identical(redactor.redactUri(clean), clean), isTrue);
    });
  });

  group('PeekRedactor.redactBody', () {
    PeekTextBody json(String text) =>
        PeekTextBody(text, contentType: PeekMediaType.json);

    String textOf(PeekBody body) => (body as PeekTextBody).text;

    test('masks matching keys at any depth, in maps and lists', () {
      final body = json(
        '{"user":"ann","password":"p","nested":{"Token":"t","keep":1},'
        '"list":[{"secret":"s"},2,{"deep":{"api_key":"k"}}]}',
      );
      expect(
        textOf(redactor.redactBody(body)),
        '{"user":"ann","password":"*****","nested":{"Token":"*****","keep":1},'
        '"list":[{"secret":"*****"},2,{"deep":{"api_key":"*****"}}]}',
      );
    });

    test('leaves null values, structure and content type alone', () {
      final body = json('{"password":null,"token":"t","n":[1,[2,{"a":3}]]}');
      final redacted = redactor.redactBody(body) as PeekTextBody;
      expect(
        redacted.text,
        '{"password":null,"token":"*****","n":[1,[2,{"a":3}]]}',
      );
      expect(redacted.contentType, PeekMediaType.json);
      expect(redacted.size, redacted.capturedSize);
    });

    test('sniffs JSON in text bodies without a JSON content type', () {
      final plain = PeekTextBody(
        ' [{"token":"t"}]',
        contentType: PeekMediaType.plainText,
      );
      expect(textOf(redactor.redactBody(plain)), '[{"token":"*****"}]');

      final untyped = PeekTextBody('{"token":"t"}');
      expect(textOf(redactor.redactBody(untyped)), '{"token":"*****"}');

      final binaryTyped = PeekTextBody(
        '{"token":"t"}',
        contentType: PeekMediaType.octetStream,
      );
      expect(identical(redactor.redactBody(binaryTyped), binaryTyped), isTrue);
    });

    test('returns the same instance for invalid JSON and clean bodies', () {
      final broken = json('{"token": ');
      final clean = json('{"user":"ann"}');
      final prose = PeekTextBody('token=abc', contentType: PeekMediaType.html);
      expect(identical(redactor.redactBody(broken), broken), isTrue);
      expect(identical(redactor.redactBody(clean), clean), isTrue);
      expect(identical(redactor.redactBody(prose), prose), isTrue);
    });

    test('keeps the wire size of a truncated body', () {
      final truncated = PeekTextBody('{"token":"t","x":"y"}', size: 5000);
      final redacted = redactor.redactBody(truncated) as PeekTextBody;
      expect(redacted.size, 5000);
      expect(redacted.isTruncated, isTrue);
    });

    test('masks URL-encoded text bodies with the body keys', () {
      final body = PeekTextBody(
        'user=ann&password=p%40ss&token=t&keep=1',
        contentType: PeekMediaType.formUrlEncoded,
      );
      expect(
        textOf(redactor.redactBody(body)),
        'user=ann&password=*****&token=*****&keep=1',
      );
    });

    test('masks matching form fields and keeps the files', () {
      final body = PeekFormBody(
        fields: const [
          PeekFormField('user', 'ann'),
          PeekFormField('Password', 'p'),
        ],
        files: const [PeekFormFile('avatar', filename: 'me.png')],
        contentType: PeekMediaType.multipartFormData,
      );
      final redacted = redactor.redactBody(body) as PeekFormBody;
      expect(redacted.fields, const [
        PeekFormField('user', 'ann'),
        PeekFormField('Password', '*****'),
      ]);
      expect(redacted.files, body.files);
      expect(redacted.contentType, PeekMediaType.multipartFormData);

      final clean = PeekFormBody(fields: const [PeekFormField('a', '1')]);
      expect(identical(redactor.redactBody(clean), clean), isTrue);
    });

    test('leaves bytes, empty and unavailable bodies untouched', () {
      final bytes = PeekBytesBody(Uint8List.fromList([1, 2]));
      const empty = PeekBody.empty();
      const missing = PeekBody.unavailable(PeekBodyUnavailableReason.streamed);
      expect(identical(redactor.redactBody(bytes), bytes), isTrue);
      expect(identical(redactor.redactBody(empty), empty), isTrue);
      expect(identical(redactor.redactBody(missing), missing), isTrue);
    });

    test('uses the configured replacement', () {
      const custom = PeekRedactor(PeekRedactionPolicy(replacement: '[hidden]'));
      expect(
        textOf(custom.redactBody(json('{"token":1}'))),
        '{"token":"[hidden]"}',
      );
    });
  });

  group('PeekRedactor on requests, responses and entries', () {
    final request = PeekRequest(
      method: 'POST',
      uri: Uri.parse('https://api.example.com/login?token=q'),
      headers: PeekHeaders.fromMap({'Authorization': 'Bearer x'}),
      body: PeekBody.text('{"password":"p"}', contentType: PeekMediaType.json),
    );
    final response = PeekResponse(
      statusCode: 200,
      headers: PeekHeaders.fromMap({'Set-Cookie': 'sid=1; Secure'}),
      body: PeekBody.text(
        '{"access_token":"a"}',
        contentType: PeekMediaType.json,
      ),
    );
    final entry = PeekEntry(
      id: const PeekId('e'),
      request: request,
      startedAt: DateTime.utc(2026),
      source: 'test',
      response: response,
      completedAt: DateTime.utc(2026),
    );

    test('masks every part of a request and a response', () {
      final redacted = redactor.redactRequest(request);
      expect(redacted.uri.query, 'token=*****');
      expect(redacted.headers['authorization'], '*****');
      expect((redacted.body as PeekTextBody).text, '{"password":"*****"}');
      expect(redacted.method, 'POST');

      final answer = redactor.redactResponse(response);
      expect(answer.headers['set-cookie'], 'sid=*****; Secure');
      expect((answer.body as PeekTextBody).text, '{"access_token":"*****"}');
      expect(answer.statusCode, 200);
    });

    test('masks both halves of an entry and keeps the rest', () {
      final redacted = redactor.redactEntry(entry);
      expect(redacted.id, entry.id);
      expect(redacted.source, 'test');
      expect(redacted.state, PeekEntryState.completed);
      expect(redacted.request.uri.query, 'token=*****');
      expect(redacted.response?.headers['set-cookie'], 'sid=*****; Secure');

      final pendingEntry = PeekEntry(
        id: const PeekId('p'),
        request: request,
        startedAt: DateTime.utc(2026),
        source: 'test',
      );
      expect(redactor.redactEntry(pendingEntry).response, isNull);
    });

    test('returns the same instances when there is nothing to hide', () {
      final clean = PeekRequest(
        method: 'GET',
        uri: Uri.parse('https://api.example.com/items?page=1'),
        headers: PeekHeaders.fromMap({'Accept': 'text/plain'}),
        body: PeekBody.text('hello'),
      );
      final cleanEntry = PeekEntry(
        id: const PeekId('c'),
        request: clean,
        startedAt: DateTime.utc(2026),
        source: 'test',
      );
      expect(identical(redactor.redactRequest(clean), clean), isTrue);
      expect(identical(redactor.redactEntry(cleanEntry), cleanEntry), isTrue);
    });

    test('is a no-op with the none policy', () {
      expect(identical(none.redactRequest(request), request), isTrue);
      expect(identical(none.redactResponse(response), response), isTrue);
      expect(identical(none.redactEntry(entry), entry), isTrue);
      expect(
        identical(none.redactHeaders(request.headers), request.headers),
        isTrue,
      );
      expect(identical(none.redactUri(request.uri), request.uri), isTrue);
      expect(identical(none.redactBody(request.body), request.body), isTrue);
    });
  });
}
