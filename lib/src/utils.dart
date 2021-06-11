import 'dart:convert';
import 'dart:developer';

import 'definitions.dart';
import 'exceptions.dart';

T parseItem<T>(String data, ParserMethod<T> method) {
  return method(jsonDecode(data) as Map<String, dynamic>);
}

List<T> parseList<T>(String data, ParserMethod<T> method) {
  return List<Map<String, dynamic>>.from(jsonDecode(data) as Iterable)
      .map<T>(method)
      .toList();
}

Future<T> tryParse<T>(TryParserMethod<T> method) async {
  T result;
  try {
    result = await method();
  } catch (e) {
    log(e.toString());
    throw NetworkError('NetworkError: Parser exception.\nException: $e');
  }
  return result;
}

void printResponse({
  required String method,
  required String path,
  required int statusCode,
  required String data,
  required void Function(String)? logFunction,
}) {
  final func = logFunction ?? log;
  try {
    // A pretty print json function
    final prettyData = const JsonEncoder.withIndent('    ').convert(
      const JsonDecoder().convert(data),
    );
    func(
      'Response $method: $path\n\t\t'
      'Status: $statusCode\n\t\t'
      'Data: $prettyData',
    );
  } catch (_) {
    func(
      'Response $method: $path\n\t\t'
      'Status: $statusCode\n\t\t'
      'Data: $data',
    );
  }
}

enum HttpMethod {
  get,
  post,
  put,
  patch,
  delete,
  options,
}

extension HttpMethodExtensor on HttpMethod {
  String get name => toString().split('.')[1];
}
