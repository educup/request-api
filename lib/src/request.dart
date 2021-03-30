import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:math';

import 'package:http/http.dart' as http;

import 'definitions.dart';
import 'utils.dart';

class Request {
  static late String _apiUrl;
  static late Map<String, String> _defaultHeaders;
  static late Map<String, String> _defaultQueryParameters;
  static late ProcessResponseMethod _processResponseMethod;
  static late ProcessStreamedResponseMethod _processStreamedResponseMethod;
  static bool _initialized = false;
  static bool _useSSL = true;
  static bool _debug = false;

  static bool checkInitialization() {
    if (!_initialized) {
      throw new Exception('Request is not initialized.');
    }
    return _initialized;
  }

  static void init(
    String authority,
    Map<String, String> headers,
    Map<String, String> queryParameters,
    ProcessResponseMethod processResponseMethod,
    ProcessStreamedResponseMethod processStreamedResponseMethod, {
    bool useSSL = true,
    bool debug = false,
  }) {
    _apiUrl = authority;
    _defaultHeaders = {};
    _defaultHeaders.addAll(headers);
    _defaultQueryParameters = {};
    _defaultQueryParameters.addAll(queryParameters);
    _processResponseMethod = processResponseMethod;
    _processStreamedResponseMethod = processStreamedResponseMethod;
    _useSSL = useSSL;
    _debug = debug;
    _initialized = true;
  }

  static Future<String> sendFile(
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
    );
  }

  static Future<String> sendFiles(
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
  }) async {
    checkInitialization();
    var _queryParameters = Map<String, String>();
    if (!queryParametersReplace)
      _queryParameters.addAll(_defaultQueryParameters);
    _queryParameters.addAll(queryParameters ?? {});
    var uri = _useSSL
        ? Uri.https(authority ?? _apiUrl, path, _queryParameters)
        : Uri.http(authority ?? _apiUrl, path, _queryParameters);
    var request = http.MultipartRequest(method.name, uri);
    if (!headersReplace) request.headers.addAll(_defaultHeaders);
    request.headers.addAll(headers ?? {});
    var length = min(filePaths.length, fields.length);
    for (var i = 0; i < length; ++i) {
      var file = await http.MultipartFile.fromPath(fields[i], filePaths[i]);
      request.files.add(file);
    }
    var response = await request.send();
    var body = utf8.decode(await response.stream.toBytes());
    if (_debug) {
      printResponse(method.name, path, response.statusCode, body);
    }
    if (processStreamedResponseMethod != null) {
      await processStreamedResponseMethod(response);
    } else {
      await _processStreamedResponseMethod(response);
    }
    return body;
  }

  static Future<http.Response> _method({
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
  }) async {
    checkInitialization();
    var _queryParameters = Map<String, String>();
    if (!queryParametersReplace)
      _queryParameters.addAll(_defaultQueryParameters);
    _queryParameters.addAll(queryParameters ?? {});
    var uri = _useSSL
        ? Uri.https(authority ?? _apiUrl, path, _queryParameters)
        : Uri.http(authority ?? _apiUrl, path, _queryParameters);
    if (_debug) {
      dev.log(
        'Request $nameOfMethod: $uri\n\t\t'
        '${body != null ? 'Body: $body' : ''}',
      );
    }
    var _headers = Map<String, String>();
    if (!headersReplace) _headers.addAll(_defaultHeaders);
    _headers.addAll(headers ?? {});
    var response = await requestMethod(uri, body, _headers, client);
    if (_debug) {
      printResponse(nameOfMethod, path, response.statusCode, response.body);
    }
    if (processResponseMethod != null) {
      await processResponseMethod(response);
    } else {
      await _processResponseMethod(response);
    }
    return response;
  }

  static Future<http.Response> _get(
    Uri uri,
    dynamic body,
    Map<String, String> headers,
    http.Client? client,
  ) {
    if (client == null) return http.get(uri, headers: headers);
    return client.get(uri, headers: headers);
  }

  static Future<http.Response> get(
    String path, {
    ProcessResponseMethod? processResponseMethod,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    String? authority,
    http.Client? client,
    bool headersReplace = false,
    bool queryParametersReplace = false,
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
    );
  }

  static Future<http.Response> _post(
    Uri uri,
    dynamic body,
    Map<String, String> headers,
    http.Client? client,
  ) {
    if (client == null)
      return http.post(uri, body: jsonEncode(body), headers: headers);
    return client.post(uri, body: jsonEncode(body), headers: headers);
  }

  static Future<http.Response> post(
    String path, {
    body,
    ProcessResponseMethod? processResponseMethod,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    String? authority,
    http.Client? client,
    bool headersReplace = false,
    bool queryParametersReplace = false,
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
    );
  }

  static Future<http.Response> _put(
    Uri uri,
    dynamic body,
    Map<String, String> headers,
    http.Client? client,
  ) {
    if (client == null)
      return http.put(uri, body: jsonEncode(body), headers: headers);
    return client.put(uri, body: jsonEncode(body), headers: headers);
  }

  static Future<http.Response> put(
    String path, {
    body,
    ProcessResponseMethod? processResponseMethod,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    String? authority,
    http.Client? client,
    bool headersReplace = false,
    bool queryParametersReplace = false,
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
    );
  }

  static Future<http.Response> _delete(
    Uri uri,
    dynamic body,
    Map<String, String> headers,
    http.Client? client,
  ) {
    if (client == null) return http.delete(uri, headers: headers);
    return client.delete(uri, headers: headers);
  }

  static Future<http.Response> delete(
    String path, {
    ProcessResponseMethod? processResponseMethod,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    String? authority,
    http.Client? client,
    bool headersReplace = false,
    bool queryParametersReplace = false,
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
    );
  }

  static Future<http.Response> _head(
    Uri uri,
    dynamic body,
    Map<String, String> headers,
    http.Client? client,
  ) {
    if (client == null) return http.head(uri, headers: headers);
    return client.head(uri, headers: headers);
  }

  static Future<http.Response> head(
    String path, {
    ProcessResponseMethod? processResponseMethod,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    String? authority,
    http.Client? client,
    bool headersReplace = false,
    bool queryParametersReplace = false,
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
    );
  }

  static Future<http.Response> _patch(
    Uri uri,
    dynamic body,
    Map<String, String> headers,
    http.Client? client,
  ) {
    if (client == null)
      return http.patch(uri, body: jsonEncode(body), headers: headers);
    return client.patch(uri, body: jsonEncode(body), headers: headers);
  }

  static Future<http.Response> patch(
    String path, {
    body,
    ProcessResponseMethod? processResponseMethod,
    Map<String, String>? queryParameters,
    Map<String, String>? headers,
    String? authority,
    http.Client? client,
    bool headersReplace = false,
    bool queryParametersReplace = false,
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
    );
  }
}
