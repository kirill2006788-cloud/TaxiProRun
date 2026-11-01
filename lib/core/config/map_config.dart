/// Конфигурация Yandex MapKit.
///
/// API-ключ:
/// ```bash
/// flutter run --dart-define=MAPKIT_API_KEY=ваш_ключ
/// ```
///
/// Включение пакета (после раскомментирования в pubspec):
/// ```bash
/// flutter run --dart-define=MAPKIT_API_KEY=ключ --dart-define=USE_YANDEX_MAPKIT=true
/// ```
///
/// Подсказки адресов: docs/GEO_SEARCH_SETUP.md
/// Карта: docs/YANDEX_MAPS_SETUP.md
class MapConfig {
  MapConfig._();

  /// Ключ Yandex MapKit Mobile SDK.
  /// Пустая строка — премиум-заглушка, MapKit не инициализируется.
  static const String apiKey = String.fromEnvironment(
    'MAPKIT_API_KEY',
    defaultValue: '',
  );

  /// Feature-flag: собирать с реальным пакетом `yandex_maps_mapkit`.
  /// Без зависимости в pubspec оставляйте `false` — analyze не ломается.
  static const bool useMapKitPackage = bool.fromEnvironment(
    'USE_YANDEX_MAPKIT',
    defaultValue: false,
  );

  /// Ключ задан (можно готовить drop-in на YandexMap).
  static bool get isMapKitEnabled => apiKey.isNotEmpty;

  /// Ключ + флаг пакета: пора вызывать initMapkit и рендер YandexMap.
  static bool get isMapKitReady => isMapKitEnabled && useMapKitPackage;

  /// Начальная позиция камеры (Москва, центр).
  static const double defaultLatitude = 55.751244;
  static const double defaultLongitude = 37.618423;
  static const double defaultZoom = 12.0;
}
