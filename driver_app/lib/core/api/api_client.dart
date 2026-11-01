import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'api_exception.dart';
import '../network/connectivity_monitor.dart';

/// HTTP-клиент с Bearer-токеном водителя и retry при сетевых сбоях.
class ApiClient {
  ApiClient({
    http.Client? httpClient,
    this.maxRetries = 3,
  }) : _http = httpClient ?? http.Client();

  final http.Client _http;
  final int maxRetries;
  String? _authToken;

  String? get authToken => _authToken;

  void setAuthToken(String? token) {
    _authToken = token?.trim().isEmpty == true ? null : token?.trim();
  }

  Map<String, String> _headers({bool json = true}) {
    final headers = <String, String>{};
    if (json) headers['Content-Type'] = 'application/json';
    final token = _authToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
  }) async {
    final uri =
        Uri.parse(ApiConfig.resolveUrl(path)).replace(queryParameters: query);
    final res = await _withRetry(
      () => _http
          .get(uri, headers: _headers())
          .timeout(const Duration(seconds: 20)),
    );
    return _decodeResponse(res);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse(ApiConfig.resolveUrl(path));
    final res = await _withRetry(
      () => _http
          .post(
            uri,
            headers: _headers(),
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20)),
      retry: false,
    );
    return _decodeResponse(res);
  }

  Future<http.Response> _withRetry(Future<http.Response> Function() request,
      {bool retry = true}) async {
    final attempts = retry ? maxRetries.clamp(1, 5) : 1;
    Object? lastError;
    for (var i = 0; i < attempts; i++) {
      try {
        final response = await request();
        ConnectivityMonitor.instance.reportServerAvailable();
        return response;
      } on SocketException catch (e) {
        lastError = e;
      } on TimeoutException catch (e) {
        lastError = e;
      } on http.ClientException catch (e) {
        lastError = e;
      } on HandshakeException catch (e) {
        lastError = e;
      }
      if (i < attempts - 1) {
        await Future<void>.delayed(Duration(milliseconds: 350 * (1 << i)));
      }
    }
    ConnectivityMonitor.instance.reportServerUnavailable();
    Error.throwWithStackTrace(
      lastError ?? TimeoutException('Network retry exhausted'),
      StackTrace.current,
    );
  }

  Map<String, dynamic> _decodeResponse(http.Response res) {
    Map<String, dynamic> map = {};
    if (res.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          map = decoded;
        } else if (decoded is Map) {
          map = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return map;
    }
    final message = map['message'];
    final error = map['error'];
    throw ApiException(
      statusCode: res.statusCode,
      body: res.body,
      message: message is String ? message : null,
      code: error is String ? error : null,
    );
  }

  void dispose() => _http.close();
}
