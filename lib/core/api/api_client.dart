import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';
import '../network/connectivity_monitor.dart';

/// HTTP-клиент с базовым URL из [ApiConfigStore] и retry при сетевых сбоях.
class ApiClient {
  ApiClient({
    http.Client? httpClient,
    ApiConfigStore? configStore,
    this.maxRetries = 3,
  })  : _http = httpClient ?? http.Client(),
        _config = configStore ?? ApiConfigStore.instance;

  final http.Client _http;
  final ApiConfigStore _config;

  /// Число попыток при сетевых ошибках / таймауте (включая первую).
  final int maxRetries;

  String get baseUrl => _config.baseUrl;

  Uri uri(String path, [Map<String, String>? query]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: query);
  }

  Map<String, String> _headers({String? token, Map<String, String>? extra}) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      ...?extra,
    };
  }

  Future<http.Response> get(
    String path, {
    Map<String, String>? query,
    String? token,
    Duration? timeout,
  }) {
    return _withRetry(
      () => _http
          .get(uri(path, query), headers: _headers(token: token))
          .timeout(timeout ?? ApiConfig.connectTimeout),
    );
  }

  Future<http.Response> post(
    String path, {
    Map<String, dynamic>? body,
    String? token,
    Duration? timeout,
  }) {
    return _withRetry(
      () => _http
          .post(
            uri(path),
            headers: _headers(token: token),
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(timeout ?? ApiConfig.connectTimeout),
      retry: false,
    );
  }

  Future<http.Response> put(
    String path, {
    Map<String, dynamic>? body,
    String? token,
    Duration? timeout,
  }) {
    return _withRetry(
      () => _http
          .put(
            uri(path),
            headers: _headers(token: token),
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(timeout ?? ApiConfig.connectTimeout),
    );
  }

  Future<http.Response> _withRetry(
    Future<http.Response> Function() request, {
    bool retry = true,
  }) async {
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
        final ms = 350 * (1 << i); // 350, 700, 1400…
        await Future<void>.delayed(Duration(milliseconds: ms));
      }
    }
    ConnectivityMonitor.instance.reportServerUnavailable();
    Error.throwWithStackTrace(
      lastError ?? TimeoutException('Network retry exhausted'),
      StackTrace.current,
    );
  }

  void dispose() => _http.close();
}

/// Хранилище runtime-конфигурации API (URL, mock/real).
class ApiConfigStore extends ChangeNotifier {
  ApiConfigStore._();

  static final ApiConfigStore instance = ApiConfigStore._();

  String _baseUrl = ApiConfig.envBaseUrl;
  bool _useMockApi = ApiConfig.useMockApi;

  String get baseUrl => _baseUrl;
  bool get useMockApi => _useMockApi;

  Future<void> load() async {
    // Runtime override загружается через SettingsProvider.
  }

  void setBaseUrl(String url) {
    final trimmed = url
        .trim()
        .replaceAll(RegExp(r'/+$'), '')
        .replaceFirst(RegExp(r'/api$'), '');
    if (trimmed.isEmpty || trimmed == _baseUrl) return;
    _baseUrl = trimmed;
    notifyListeners();
  }

  void setUseMockApi(bool value) {
    if (_useMockApi == value) return;
    _useMockApi = value;
    notifyListeners();
  }
}

/// Ошибка API с кодом статуса.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.body});

  final String message;
  final int? statusCode;
  final String? body;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
