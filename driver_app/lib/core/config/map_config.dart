/// Конфигурация Yandex MapKit (приложение водителя).
///
/// ```bash
/// flutter run --dart-define=MAPKIT_API_KEY=ключ --dart-define=USE_YANDEX_MAPKIT=true
/// ```
class MapConfig {
  MapConfig._();

  static const String apiKey = String.fromEnvironment(
    'MAPKIT_API_KEY',
    defaultValue: '',
  );

  static const bool useMapKitPackage = bool.fromEnvironment(
    'USE_YANDEX_MAPKIT',
    defaultValue: false,
  );

  static bool get isMapKitEnabled => apiKey.isNotEmpty;
  static bool get isMapKitReady => isMapKitEnabled && useMapKitPackage;

  static const double defaultLatitude = 55.751244;
  static const double defaultLongitude = 37.618423;
  static const double defaultZoom = 14.0;
}
