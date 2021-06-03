library request_api;

import 'dart:io';

import 'package:http/http.dart' as http;

import 'src/exceptions.dart';
import 'src/request.dart';

export 'src/definitions.dart';
export 'src/exceptions.dart';
export 'src/request.dart';
export 'src/utils.dart';

class RequestAPI {
  static void init(
    String authority,
    String bearerToken, {
    bool useSSL = true,
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    bool debug = false,
    void Function(String)? logFunction,
  }) {
    final _headers = {
      HttpHeaders.authorizationHeader: bearerToken,
      HttpHeaders.contentTypeHeader: ContentType.json.value,
    };
    if (headers != null) {
      _headers.updateAll(
        (key, value) => headers.containsKey(key) ? headers[key]! : value,
      );
    }

    var processResponseMethod = (http.Response response) async {
      if (response.statusCode == 0 ||
          response.statusCode == 407 ||
          response.statusCode == 408) {
        throw NetworkError('NetworkError: ${response.statusCode}.\n'
            'Response: ${response.toString()}');
      } else if (response.statusCode != 200) {
        throw ServerError('ServerError: ${response.statusCode}.\n'
            'Response: ${response.toString()}');
      }
    };
    var processStreamedResponseMethod = (http.StreamedResponse response) async {
      if (response.statusCode == 0 ||
          response.statusCode == 407 ||
          response.statusCode == 408) {
        throw NetworkError('NetworkError: ${response.statusCode}.\n'
            'Response: ${response.toString()}');
      } else if (response.statusCode != 200) {
        throw ServerError('ServerError: ${response.statusCode}.\n'
            'Response: ${response.toString()}');
      }
    };
    Request.init(
      authority,
      _headers,
      queryParameters ?? {},
      processResponseMethod,
      processStreamedResponseMethod,
      useSSL: useSSL,
      debug: debug,
      logFunction: logFunction,
    );
  }
}
