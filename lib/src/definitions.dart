import 'dart:async';

import 'package:http/http.dart' as http;

typedef RequestMethod = Future<http.Response> Function(
  Uri uri,
  dynamic body,
  Map<String, String> headers,
  http.Client?,
);

typedef ProcessResponseMethod = Future<void> Function(http.Response response);

typedef ProcessStreamedResponseMethod = Future<void> Function(
  http.StreamedResponse response,
);

typedef ParserMethod<T> = T Function(Map<String, dynamic> data);

typedef TryParserMethod<T> = FutureOr<T> Function();
