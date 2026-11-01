/// Конфигурация геопоиска и маршрутизации Яндекса.
///
/// Ключи через `--dart-define` или `scripts/run_with_keys.ps1` + `keys.local.env`.
abstract final class GeoConfig {
  /// HTTP Geocoder (адрес ↔ координаты).
  static const String yandexGeocoderKey = String.fromEnvironment(
    'YANDEX_GEOCODER_KEY',
    defaultValue: '',
  );

  /// API Геосаджеста (подсказки).
  static const String yandexGeosuggestKey = String.fromEnvironment(
    'YANDEX_GEOSUGGEST_KEY',
    defaultValue: '',
  );

  /// Общий ключ Routing (часто один на Route Details + Distance Matrix).
  static const String yandexRoutingKey = String.fromEnvironment(
    'YANDEX_ROUTING_KEY',
    defaultValue: '',
  );

  /// API Получения деталей маршрута.
  static const String yandexRouteDetailsKey = String.fromEnvironment(
    'YANDEX_ROUTE_DETAILS_KEY',
    defaultValue: '',
  );

  /// API Матрицы расстояний.
  static const String yandexDistanceMatrixKey = String.fromEnvironment(
    'YANDEX_DISTANCE_MATRIX_KEY',
    defaultValue: '',
  );

  static bool get hasYandexGeocoderKey => yandexGeocoderKey.isNotEmpty;

  static bool get hasYandexGeosuggestKey => yandexGeosuggestKey.isNotEmpty;

  static String get suggestApiKey =>
      yandexGeosuggestKey.isNotEmpty ? yandexGeosuggestKey : yandexGeocoderKey;

  static String get routeDetailsApiKey => yandexRouteDetailsKey.isNotEmpty
      ? yandexRouteDetailsKey
      : yandexRoutingKey;

  static String get distanceMatrixApiKey => yandexDistanceMatrixKey.isNotEmpty
      ? yandexDistanceMatrixKey
      : yandexRoutingKey;

  static bool get hasRouteDetailsKey => routeDetailsApiKey.isNotEmpty;

  static bool get hasDistanceMatrixKey => distanceMatrixApiKey.isNotEmpty;

  static bool get hasAnyRoutingKey =>
      hasRouteDetailsKey || hasDistanceMatrixKey;

  static const int minQueryLength = 2;
  static const Duration debounce = Duration(milliseconds: 300);
  static const int maxResults = 12;
  static const String moscowLl = '37.618423,55.751244';
  static const String moscowSpn = '0.55,0.35';
}
