import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';

void main() {
  final uri = Uri.parse('https://api.example.com/v1/items?q=a&q=b&page=2');

  group('PeekRequest', () {
    test('uppercases the method', () {
      expect(PeekRequest(method: 'get', uri: uri).method, 'GET');
      expect(PeekRequest(method: 'Post', uri: uri).method, 'POST');
    });

    test('takes host, path and every query value apart from the uri', () {
      final request = PeekRequest(method: 'GET', uri: uri);
      expect(request.host, 'api.example.com');
      expect(request.path, '/v1/items');
      expect(request.queryParameters, {
        'q': ['a', 'b'],
        'page': ['2'],
      });
    });

    test('defaults to no headers and an empty body', () {
      final request = PeekRequest(method: 'GET', uri: uri);
      expect(request.headers, PeekHeaders.empty);
      expect(request.body, const PeekBody.empty());
      expect(request.extra, isEmpty);
      expect(request.contentLength, 0);
    });

    test('prefers the Content-Length header over the body size', () {
      final fromHeader = PeekRequest(
        method: 'POST',
        uri: uri,
        headers: PeekHeaders.fromMap({'Content-Length': '100'}),
        body: PeekBody.text('abc'),
      );
      expect(fromHeader.contentLength, 100);

      final fromBody = PeekRequest(
        method: 'POST',
        uri: uri,
        body: PeekBody.text('abc'),
      );
      expect(fromBody.contentLength, 3);

      final unknown = PeekRequest(
        method: 'POST',
        uri: uri,
        body: PeekBody.form(fields: const [PeekFormField('a', '1')]),
      );
      expect(unknown.contentLength, isNull);
    });

    test('reads its media type from the body, else from the headers', () {
      final typed = PeekRequest(
        method: 'POST',
        uri: uri,
        headers: PeekHeaders.fromMap({'Content-Type': 'text/plain'}),
        body: PeekBody.text('{}', contentType: PeekMediaType.json),
      );
      expect(typed.mediaType, PeekMediaType.json);

      final fromHeaders = PeekRequest(
        method: 'POST',
        uri: uri,
        headers: PeekHeaders.fromMap({'Content-Type': 'text/plain'}),
        body: PeekBody.text('{}'),
      );
      expect(fromHeaders.mediaType, PeekMediaType.plainText);
      expect(PeekRequest(method: 'GET', uri: uri).mediaType, isNull);
    });

    test('copies extra and freezes the copy', () {
      final extra = <String, Object?>{};
      extra['client'] = 'shop';
      final request = PeekRequest(method: 'GET', uri: uri, extra: extra);
      extra['client'] = 'other';
      expect(request.extra, {'client': 'shop'});
      expect(() => request.extra['x'] = 1, throwsUnsupportedError);
    });

    test('compares by value', () {
      final request = PeekRequest(
        method: 'POST',
        uri: uri,
        headers: PeekHeaders.fromMap({'Accept': 'application/json'}),
        body: PeekBody.text('{}', contentType: PeekMediaType.json),
        extra: const {'client': 'shop'},
      );
      final same = PeekRequest(
        method: 'post',
        uri: Uri.parse('https://api.example.com/v1/items?q=a&q=b&page=2'),
        headers: PeekHeaders.fromMap({'accept': 'application/json'}),
        body: PeekBody.text('{}', contentType: PeekMediaType.json),
        extra: const {'client': 'shop'},
      );
      expect(request, same);
      expect(request.hashCode, same.hashCode);
      expect(request, isNot(request.copyWith(method: 'PUT')));
      expect(request, isNot(request.copyWith(extra: const {})));
      expect(request, isNot(request.copyWith(body: const PeekBody.empty())));
    });

    test('copies with replaced fields and nothing else', () {
      final request = PeekRequest(
        method: 'GET',
        uri: uri,
        extra: const {'client': 'shop'},
      );
      final other = Uri.parse('https://example.org/');
      final copy = request.copyWith(uri: other, method: 'head');
      expect(copy.uri, other);
      expect(copy.method, 'HEAD');
      expect(copy.extra, request.extra);
      expect(copy.headers, request.headers);
      expect(request.copyWith(), request);
    });

    test('prints method, host and path only', () {
      final request = PeekRequest(
        method: 'GET',
        uri: uri,
        headers: PeekHeaders.fromMap({'Authorization': 'Bearer secret'}),
      );
      expect(request.toString(), 'PeekRequest(GET api.example.com/v1/items)');
    });
  });
}
