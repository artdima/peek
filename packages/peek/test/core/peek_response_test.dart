import 'package:flutter_test/flutter_test.dart';
import 'package:peek/core.dart';

void main() {
  group('PeekResponse', () {
    test('classifies its status code', () {
      expect(
        PeekResponse(statusCode: 200).statusClass,
        PeekStatusClass.success,
      );
      expect(
        PeekResponse(statusCode: 404).statusClass,
        PeekStatusClass.clientError,
      );
      expect(PeekResponse(statusCode: 0).statusClass, PeekStatusClass.unknown);
    });

    test('defaults to no headers, an empty body and no redirects', () {
      final response = PeekResponse(statusCode: 204);
      expect(response.statusMessage, isNull);
      expect(response.headers, PeekHeaders.empty);
      expect(response.body, const PeekBody.empty());
      expect(response.redirects, isEmpty);
      expect(response.contentLength, 0);
    });

    test('prefers the Content-Length header over the body size', () {
      final response = PeekResponse(
        statusCode: 200,
        headers: PeekHeaders.fromMap({'content-length': '9'}),
        body: PeekBody.text('abc'),
      );
      expect(response.contentLength, 9);
      expect(
        PeekResponse(statusCode: 200, body: PeekBody.text('abc')).contentLength,
        3,
      );
    });

    test('reads its media type from the body, else from the headers', () {
      final fromHeaders = PeekResponse(
        statusCode: 200,
        headers: PeekHeaders.fromMap({'content-type': 'image/png'}),
      );
      expect(fromHeaders.mediaType?.mimeType, 'image/png');
      expect(
        PeekResponse(
          statusCode: 200,
          body: PeekBody.text('x', contentType: PeekMediaType.html),
        ).mediaType,
        PeekMediaType.html,
      );
      expect(PeekResponse(statusCode: 204).mediaType, isNull);
    });

    test('copies redirects and freezes the copy', () {
      final redirects = <PeekRedirect>[];
      redirects.add(
        PeekRedirect(
          statusCode: 301,
          method: 'GET',
          location: Uri.parse('https://example.com/new'),
        ),
      );
      final response = PeekResponse(statusCode: 200, redirects: redirects);
      redirects.clear();
      expect(response.redirects, hasLength(1));
      expect(response.redirects.first.statusCode, 301);
      expect(response.redirects.clear, throwsUnsupportedError);
    });

    test('compares by value', () {
      final response = PeekResponse(
        statusCode: 200,
        statusMessage: 'OK',
        headers: PeekHeaders.fromMap({'Content-Type': 'text/plain'}),
        body: PeekBody.text('hi', contentType: PeekMediaType.plainText),
      );
      final same = PeekResponse(
        statusCode: 200,
        statusMessage: 'OK',
        headers: PeekHeaders.fromMap({'content-type': 'text/plain'}),
        body: PeekBody.text('hi', contentType: PeekMediaType.plainText),
      );
      expect(response, same);
      expect(response.hashCode, same.hashCode);
      expect(response, isNot(response.copyWith(statusCode: 201)));
      expect(response, isNot(response.copyWith(statusMessage: 'Created')));
      expect(response, isNot(response.copyWith(body: const PeekBody.empty())));
      expect(
        response,
        isNot(
          response.copyWith(
            redirects: [
              PeekRedirect(
                statusCode: 302,
                method: 'GET',
                location: Uri.parse('https://example.com/'),
              ),
            ],
          ),
        ),
      );
    });

    test('copies with replaced fields and nothing else', () {
      final response = PeekResponse(
        statusCode: 200,
        statusMessage: 'OK',
        body: PeekBody.text('hi'),
      );
      final copy = response.copyWith(statusCode: 500);
      expect(copy.statusCode, 500);
      expect(copy.statusMessage, 'OK');
      expect(copy.body, response.body);
      expect(response.copyWith(), response);
    });

    test('prints the status line only', () {
      expect(
        PeekResponse(statusCode: 200, statusMessage: 'OK').toString(),
        'PeekResponse(200 OK)',
      );
      expect(PeekResponse(statusCode: 204).toString(), 'PeekResponse(204)');
    });
  });

  group('PeekRedirect', () {
    test('compares by value and prints the hop', () {
      final location = Uri.parse('https://example.com/new');
      final redirect = PeekRedirect(
        statusCode: 301,
        method: 'GET',
        location: location,
      );
      expect(
        redirect,
        PeekRedirect(statusCode: 301, method: 'GET', location: location),
      );
      expect(
        redirect.hashCode,
        PeekRedirect(
          statusCode: 301,
          method: 'GET',
          location: location,
        ).hashCode,
      );
      expect(
        redirect,
        isNot(PeekRedirect(statusCode: 302, method: 'GET', location: location)),
      );
      expect(redirect.toString(), 'PeekRedirect(301 GET example.com)');
    });
  });
}
