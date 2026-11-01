/// Конфигурация API — VPS backend ([apiPrefix] добавляется в [resolveUrl]).
abstract final class ApiConfig {
  /// Базовый URL сервера (переопределяется через --dart-define=API_BASE_URL=...).
  /// Хост без `/api` — префикс задаётся в [apiPrefix].
  static const String defaultBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://161.104.19.23',
  );

  static const String apiPrefix = '/api';
  static const String authTokenKey = 'auth_token';
  static const String registrationStatusKey = 'driver_registration_status';
  static const String serverUrlKey = 'driver_server_url_v1';
  static const String useMockKey = 'driver_use_mock_api_v1';
  static const String onlineKey = 'driver_online_v1';
  static const String notificationsKey = 'driver_notifications_v1';
  static const String themeModeKey = 'driver_theme_mode_v1';
  static const String navAppKey = 'driver_nav_app_v1';

  static String _baseUrl = defaultBaseUrl
      .trim()
      .replaceAll(RegExp(r'/+$'), '')
      .replaceFirst(RegExp(r'/api$'), '');
  static bool _useMock = false;

  static String get baseUrl => _baseUrl;
  static bool get useMock => _useMock;

  static void setBaseUrl(String url) {
    final trimmed = url
        .trim()
        .replaceAll(RegExp(r'/+$'), '')
        .replaceFirst(RegExp(r'/api$'), '');
    _baseUrl = trimmed.isEmpty ? defaultBaseUrl : trimmed;
  }

  static void setUseMock(bool value) {
    _useMock = value;
  }

  static String resolveUrl(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return '$baseUrl$apiPrefix$normalized';
  }
}
