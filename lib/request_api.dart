library request_api;

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:request_api/src/definitions.dart';
import 'package:request_api/src/exceptions.dart';
import 'package:request_api/src/utils.dart';

export 'src/definitions.dart';
export 'src/exceptions.dart';
export 'src/utils.dart';

class RequestAPI {
  final String authority;
  final Map<String, String> headers;
  final Map<String, String> queryParameters;
  final ProcessResponseMethod processResponseMethod;
  final ProcessStreamedResponseMethod processStreamedResponseMethod;
  final bool useJsonEncode;
  final bool useSSL;
  final bool debug;
  final void Function(String)? logFunction;

  const RequestAPI({
    required this.authority,
    required this.headers,
    required this.queryParameters,
    required this.processResponseMethod,
    required this.processStreamedResponseMethod,
    this.useJsonEncode = true,
    this.useSSL = true,
    this.debug = false,
    this.logFunction,
  });

  factory RequestAPI.factory({
    required String authority,
    String? bearerToken,
    bool useSSL = true,
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    bool debug = false,
    void Function(String)? logFunction,
    bool replaceDefaultHeaders = false,
  }) {
    final _headers = {
      if (bearerToken != null && !replaceDefaultHeaders)
        HttpHeaders.authorizationHeader: bearerToken,
      if (!replaceDefaultHeaders)
        HttpHeaders.contentTypeHeader: ContentType.json.value,
    };
    if (headers != null) {
      _headers.updateAll(
        (key, value) => headers.containsKey(key) ? headers[key]! : value,
      );
    }
    return RequestAPI(
      authority: authority,
      headers: _headers,
      queryParameters: queryParameters ?? {},
      processResponseMethod: _processResponseMethod,
      processStreamedResponseMethod: _processStreamedResponseMethod,
      useSSL: useSSL,
      debug: debug,
      logFunction: logFunction,
    );
  }

  Future<String> sendFile(
    HttpMethod method,
    String path,
    String field,
    String filePath, {
    ProcessStreamedResponseMethod? processStreamedResponseMethod,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    String? authority,
    bool headersReplace = false,
    bool queryParametersReplace = false,
    required bool? useSSL,
  }) async {
    return sendFiles(
      method,
      path,
      [field],
      [filePath],
      processStreamedResponseMethod: processStreamedResponseMethod,
      queryParameters: queryParameters,
      headers: headers,
      authority: authority,
      headersReplace: headersReplace,
      queryParametersReplace: queryParametersReplace,
      useSSL: useSSL,
    );
  }

  Future<String> sendFiles(
    HttpMethod method,
    String path,
    List<String> fields,
    List<String> filePaths, {
    ProcessStreamedResponseMethod? processStreamedResponseMethod,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    String? authority,
    bool headersReplace = false,
    bool queryParametersReplace = false,
    required bool? useSSL,
  }) async {
    final _queryParameters = <String, String>{};
    if (!queryParametersReplace) {
      _queryParameters.addAll(this.queryParameters);
    }
    _queryParameters.addAll(queryParameters ?? {});
    final uri = (useSSL ?? this.useSSL)
        ? Uri.https(authority ?? this.authority, path, _queryParameters)
        : Uri.http(authority ?? this.authority, path, _queryParameters);
    final request = http.MultipartRequest(method.name, uri);
    if (!headersReplace) request.headers.addAll(this.headers);
    request.headers.addAll(headers ?? {});
    if (debug) {
      final func = logFunction ?? dev.log;
      final queryString = _queryParameters.entries
          .map((e) => '$e.key=$e.value')
          .reduce((a, b) => '$a&$b');
      final query = queryString.isNotEmpty ? '?$queryString' : '';
      func(
        'Request $method.name: $uri$query\n\t\t'
        '${request.headers.isNotEmpty ? 'Headers: $request.headers\n\t\t' : ''}',
      );
    }
    final length = min(filePaths.length, fields.length);
    for (var i = 0; i < length; ++i) {
      final file = await http.MultipartFile.fromPath(fields[i], filePaths[i]);
      request.files.add(file);
    }
    final response = await request.send();
    final body = utf8.decode(await response.stream.toBytes());
    if (debug) {
      printResponse(
        method: method.name,
        path: path,
        statusCode: response.statusCode,
        data: body,
        logFunction: logFunction,
      );
    }
    if (processStreamedResponseMethod != null) {
      await processStreamedResponseMethod(response);
    } else {
      await _processStreamedResponseMethod(response);
    }
    return body;
  }

  Future<http.Response> _method({
    required String path,
    required body,
    required RequestMethod requestMethod,
    required ProcessResponseMethod? processResponseMethod,
    required Map<String, String>? queryParameters,
    required Map<String, String>? headers,
    required String? authority,
    required String nameOfMethod,
    required http.Client? client,
    required bool headersReplace,
    required bool queryParametersReplace,
    required bool? useSSL,
    required bool useJsonEncode,
  }) async {
    final _queryParameters = <String, String>{};
    if (!queryParametersReplace) {
      _queryParameters.addAll(this.queryParameters);
    }
    _queryParameters.addAll(queryParameters ?? {});
    final uri = (useSSL ?? this.useSSL)
        ? Uri.https(authority ?? this.authority, path, _queryParameters)
        : Uri.http(authority ?? this.authority, path, _queryParameters);
    final _headers = <String, String>{};
    if (!headersReplace) {
      _headers.addAll(this.headers);
    }
    _headers.addAll(headers ?? {});
    if (debug) {
      final func = logFunction ?? dev.log;
      final queryString = _queryParameters.entries
          .map((e) => '$e.key=$e.value')
          .reduce((a, b) => '$a&$b');
      final query = queryString.isNotEmpty ? '?$queryString' : '';
      func(
        'Request $nameOfMethod: $uri$query\n\t\t'
        '${_headers.isNotEmpty ? 'Headers: $_headers\n\t\t' : ''}'
        '${body != null ? 'Body: $body' : ''}',
      );
    }
    final response = await requestMethod(
      uri,
      body,
      _headers,
      client,
      useJsonEncode,
    );
    if (debug) {
      printResponse(
        method: nameOfMethod,
        path: path,
        statusCode: response.statusCode,
        data: response.body,
        logFunction: logFunction,
      );
    }
    if (processResponseMethod != null) {
      await processResponseMethod(response);
    } else {
      await _processResponseMethod(response);
    }
    return response;
  }

  Future<http.Response> _get(
    Uri uri,
    dynamic body,
    Map<String, String> headers,
    http.Client? client,
    bool useJsonEncode,
  ) {
    if (client == null) return http.get(uri, headers: headers);
    return client.get(uri, headers: headers);
  }

  Future<http.Response> get(
    String path, {
    ProcessResponseMethod? processResponseMethod,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    String? authority,
    http.Client? client,
    bool headersReplace = false,
    bool queryParametersReplace = false,
    bool? useSSL,
  }) {
    return _method(
      path: path,
      body: null,
      requestMethod: _get,
      processResponseMethod: processResponseMethod,
      queryParameters: queryParameters,
      headers: headers,
      authority: authority,
      nameOfMethod: 'GET',
      client: client,
      headersReplace: headersReplace,
      queryParametersReplace: queryParametersReplace,
      useSSL: useSSL,
      useJsonEncode: true,
    );
  }

  Future<http.Response> _post(
    Uri uri,
    dynamic body,
    Map<String, String> headers,
    http.Client? client,
    bool useJsonEncode,
  ) {
    if (client == null) {
      return http.post(
        uri,
        body: useJsonEncode ? jsonEncode(body) : body,
        headers: headers,
      );
    }
    return client.post(
      uri,
      body: useJsonEncode ? jsonEncode(body) : body,
      headers: headers,
    );
  }

  Future<http.Response> post(
    String path, {
    dynamic body,
    ProcessResponseMethod? processResponseMethod,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    String? authority,
    http.Client? client,
    bool headersReplace = false,
    bool queryParametersReplace = false,
    bool? useJsonEncode,
    bool? useSSL,
  }) async {
    return _method(
      path: path,
      body: body,
      requestMethod: _post,
      processResponseMethod: processResponseMethod,
      queryParameters: queryParameters,
      headers: headers,
      authority: authority,
      nameOfMethod: 'POST',
      client: client,
      headersReplace: headersReplace,
      queryParametersReplace: queryParametersReplace,
      useSSL: useSSL,
      useJsonEncode: useJsonEncode ?? this.useJsonEncode,
    );
  }

  Future<http.Response> _put(
    Uri uri,
    dynamic body,
    Map<String, String> headers,
    http.Client? client,
    bool useJsonEncode,
  ) {
    if (client == null) {
      return http.put(
        uri,
        body: useJsonEncode ? jsonEncode(body) : body,
        headers: headers,
      );
    }
    return client.put(
      uri,
      body: useJsonEncode ? jsonEncode(body) : body,
      headers: headers,
    );
  }

  Future<http.Response> put(
    String path, {
    dynamic body,
    ProcessResponseMethod? processResponseMethod,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    String? authority,
    http.Client? client,
    bool headersReplace = false,
    bool queryParametersReplace = false,
    bool? useJsonEncode,
    bool? useSSL,
  }) async {
    return _method(
      path: path,
      body: body,
      requestMethod: _put,
      processResponseMethod: processResponseMethod,
      queryParameters: queryParameters,
      headers: headers,
      authority: authority,
      nameOfMethod: 'PUT',
      client: client,
      headersReplace: headersReplace,
      queryParametersReplace: queryParametersReplace,
      useSSL: useSSL,
      useJsonEncode: useJsonEncode ?? this.useJsonEncode,
    );
  }

  Future<http.Response> _delete(
    Uri uri,
    dynamic body,
    Map<String, String> headers,
    http.Client? client,
    bool useJsonEncode,
  ) {
    if (client == null) return http.delete(uri, headers: headers);
    return client.delete(uri, headers: headers);
  }

  Future<http.Response> delete(
    String path, {
    ProcessResponseMethod? processResponseMethod,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    String? authority,
    http.Client? client,
    bool headersReplace = false,
    bool queryParametersReplace = false,
    bool? useSSL,
  }) {
    return _method(
      path: path,
      body: null,
      requestMethod: _delete,
      processResponseMethod: processResponseMethod,
      queryParameters: queryParameters,
      headers: headers,
      authority: authority,
      nameOfMethod: 'DELETE',
      client: client,
      headersReplace: headersReplace,
      queryParametersReplace: queryParametersReplace,
      useSSL: useSSL,
      useJsonEncode: true,
    );
  }

  Future<http.Response> _head(
    Uri uri,
    dynamic body,
    Map<String, String> headers,
    http.Client? client,
    bool useJsonEncode,
  ) {
    if (client == null) return http.head(uri, headers: headers);
    return client.head(uri, headers: headers);
  }

  Future<http.Response> head(
    String path, {
    ProcessResponseMethod? processResponseMethod,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    String? authority,
    http.Client? client,
    bool headersReplace = false,
    bool queryParametersReplace = false,
    bool? useSSL,
  }) {
    return _method(
      path: path,
      body: null,
      requestMethod: _head,
      processResponseMethod: processResponseMethod,
      queryParameters: queryParameters,
      headers: headers,
      authority: authority,
      nameOfMethod: 'HEAD',
      client: client,
      headersReplace: headersReplace,
      queryParametersReplace: queryParametersReplace,
      useSSL: useSSL,
      useJsonEncode: true,
    );
  }

  Future<http.Response> _patch(
    Uri uri,
    dynamic body,
    Map<String, String> headers,
    http.Client? client,
    bool useJsonEncode,
  ) {
    if (client == null) {
      return http.patch(
        uri,
        body: useJsonEncode ? jsonEncode(body) : body,
        headers: headers,
      );
    }
    return client.patch(
      uri,
      body: useJsonEncode ? jsonEncode(body) : body,
      headers: headers,
    );
  }

  Future<http.Response> patch(
    String path, {
    dynamic body,
    ProcessResponseMethod? processResponseMethod,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    String? authority,
    http.Client? client,
    bool headersReplace = false,
    bool queryParametersReplace = false,
    bool? useJsonEncode,
    bool? useSSL,
  }) async {
    return _method(
      path: path,
      body: body,
      requestMethod: _patch,
      processResponseMethod: processResponseMethod,
      queryParameters: queryParameters,
      headers: headers,
      authority: authority,
      nameOfMethod: 'PATCH',
      client: client,
      headersReplace: headersReplace,
      queryParametersReplace: queryParametersReplace,
      useSSL: useSSL,
      useJsonEncode: useJsonEncode ?? this.useJsonEncode,
    );
  }

  static Future<void> _processResponseMethod(
    http.Response response,
  ) async {
    if (response.statusCode == 0 ||
        response.statusCode == 407 ||
        response.statusCode == 408) {
      throw NetworkError(
        'NetworkError: ${response.statusCode}.\n'
        'Response: ${response.toString()}',
      );
    } else if (response.statusCode != 200) {
      throw ServerError(
        'ServerError: ${response.statusCode}.\n'
        'Response: ${response.toString()}',
      );
    }
  }

  static Future<void> _processStreamedResponseMethod(
    http.StreamedResponse response,
  ) async {
    if (response.statusCode == 0 ||
        response.statusCode == 407 ||
        response.statusCode == 408) {
      throw NetworkError(
        'NetworkError: ${response.statusCode}.\n'
        'Response: ${response.toString()}',
      );
    } else if (response.statusCode != 200) {
      throw ServerError(
        'ServerError: ${response.statusCode}.\n'
        'Response: ${response.toString()}',
      );
    }
  }
}
