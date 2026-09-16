import 'package:http/http.dart' as http;

import 'plain_response_copy.dart';

/// [response] with its body replaced by [stream]; see the `dart:io` variant.
http.StreamedResponse copyResponse(
  http.StreamedResponse response,
  Stream<List<int>> stream,
) => copyPlainResponse(response, stream);
