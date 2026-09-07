import 'dart:convert';
import 'dart:typed_data';

import 'package:peek/peek.dart';

/// Reports a handful of lifelike calls into [peek], the way an adapter
/// would: a request event, then the response or the failure.
///
/// Everything here goes through the public API, so the demo also serves as
/// a check that reporting a call needs nothing private.
void fillWithDemoData(Peek peek) {
  final now = DateTime.now();

  for (final call in _calls) {
    final id = PeekId.generate();
    final startedAt = now.subtract(call.ago);
    peek.report(
      PeekRequestStarted(
        id: id,
        timestamp: startedAt,
        request: call.request,
        source: 'demo',
      ),
    );

    final failure = call.failure;
    if (call.pending) continue;
    if (failure != null) {
      peek.report(
        PeekRequestFailed(
          id: id,
          timestamp: startedAt.add(call.took),
          failure: failure,
          response: call.response,
        ),
      );
    } else {
      peek.report(
        PeekResponseReceived(
          id: id,
          timestamp: startedAt.add(call.took),
          response: call.response!,
        ),
      );
    }
  }
}

class _Call {
  const _Call({
    required this.request,
    required this.ago,
    this.took = const Duration(milliseconds: 120),
    this.response,
    this.failure,
    this.pending = false,
  });

  final PeekRequest request;
  final Duration ago;
  final Duration took;
  final PeekResponse? response;
  final PeekFailure? failure;
  final bool pending;
}

PeekRequest _get(String url, {Map<String, String> headers = const {}}) =>
    PeekRequest(
      method: 'GET',
      uri: Uri.parse(url),
      headers: PeekHeaders.fromMap({'Accept': 'application/json', ...headers}),
    );

PeekResponse _json(int status, String body, {String? message}) => PeekResponse(
  statusCode: status,
  statusMessage: message,
  headers: PeekHeaders.fromMap({
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': '${body.length}',
  }),
  body: PeekBody.text(body, contentType: PeekMediaType.json),
);

final List<_Call> _calls = [
  _Call(
    request: _get('https://api.example.com/v1/users?page=1&per_page=20'),
    ago: const Duration(minutes: 6),
    took: const Duration(milliseconds: 142),
    response: _json(
      200,
      jsonEncode({
        'page': 1,
        'users': [
          for (var i = 1; i <= 3; i++)
            {'id': i, 'name': 'User $i', 'email': 'user$i@example.com'},
        ],
      }),
      message: 'OK',
    ),
  ),
  _Call(
    request: PeekRequest(
      method: 'POST',
      uri: Uri.parse('https://api.example.com/v1/session'),
      headers: PeekHeaders.fromMap(const {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer demo-token',
      }),
      body: PeekBody.text(
        '{"email":"ann@example.com","password":"hunter2"}',
        contentType: PeekMediaType.json,
      ),
    ),
    ago: const Duration(minutes: 5),
    took: const Duration(milliseconds: 310),
    response: _json(
      401,
      '{"error":"invalid_credentials"}',
      message: 'Unauthorized',
    ),
  ),
  _Call(
    request: _get('https://cdn.example.com/avatars/ann.png'),
    ago: const Duration(minutes: 4),
    took: const Duration(milliseconds: 38),
    response: PeekResponse(
      statusCode: 200,
      headers: PeekHeaders.fromMap(const {'Content-Type': 'image/png'}),
      body: PeekBody.bytes(
        _pngPixel,
        contentType: PeekMediaType.tryParse('image/png'),
      ),
    ),
  ),
  _Call(
    request: PeekRequest(
      method: 'POST',
      uri: Uri.parse('https://api.example.com/v1/photos'),
      headers: PeekHeaders.fromMap(const {
        'Content-Type': 'multipart/form-data; boundary=demo',
      }),
      body: PeekBody.form(
        fields: const [PeekFormField('album', 'Holiday')],
        files: [
          PeekFormFile(
            'photo',
            filename: 'beach.jpg',
            contentType: PeekMediaType.tryParse('image/jpeg'),
            size: 2 * 1024 * 1024,
          ),
        ],
        contentType: PeekMediaType.multipartFormData,
      ),
    ),
    ago: const Duration(minutes: 3),
    took: const Duration(seconds: 3, milliseconds: 200),
    response: _json(201, '{"id":42}', message: 'Created'),
  ),
  _Call(
    request: _get('https://api.example.com/v1/reports/2026'),
    ago: const Duration(minutes: 2),
    took: const Duration(milliseconds: 640),
    response: _json(500, '{"error":"internal"}', message: 'Server Error'),
  ),
  _Call(
    request: _get('https://api.example.com/v1/sync'),
    ago: const Duration(minutes: 1),
    took: const Duration(seconds: 30),
    failure: const PeekFailure(
      kind: PeekFailureKind.timeout,
      message: 'Connection timed out after 30s',
      details: 'SocketException: timeout',
    ),
  ),
  _Call(
    request: _get('https://api.example.com/v1/feed'),
    ago: const Duration(seconds: 2),
    pending: true,
  ),
];

final Uint8List _pngPixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk'
  'YPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);
