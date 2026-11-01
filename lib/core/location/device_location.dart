import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Результат получения GPS пассажира.
class DevicePosition {
  const DevicePosition({required this.lat, required this.lng});

  final double lat;
  final double lng;
}

/// Русские тексты для сценария геолокации пассажира.
abstract final class DeviceLocationCopy {
  static const permissionTitle = 'Доступ к геолокации';
  static const permissionBody =
      'Разрешите геолокацию, чтобы подставить адрес «Откуда» '
      'и показать ваше место на карте.';
  static const denied =
      'Без геолокации укажите адрес вручную.';
  static const permanentlyDenied =
      'Геолокация отключена. Включите её в настройках телефона: '
      'Настройки → КОРОЛИ ДОРОГ → Геолокация.';
  static const serviceDisabled =
      'Включите службы геолокации на устройстве.';
  static const failed =
      'Не удалось определить местоположение. Попробуйте ещё раз.';
}

/// Хелпер GPS для пассажирского приложения.
abstract final class DeviceLocation {
  /// Проверяет/запрашивает разрешение. Возвращает true, если доступ есть.
  static Future<bool> ensurePermission() async {
    var status = await Permission.locationWhenInUse.status;
    if (status.isGranted || status.isLimited) return true;

    status = await Permission.locationWhenInUse.request();
    return status.isGranted || status.isLimited;
  }

  /// Текущая позиция устройства. Null — нет разрешения / сервис выключен / ошибка.
  static Future<DevicePosition?> getCurrentPosition({
    Duration timeLimit = const Duration(seconds: 12),
  }) async {
    final permitted = await ensurePermission();
    if (!permitted) return null;

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeLimit,
        ),
      );
      return DevicePosition(lat: pos.latitude, lng: pos.longitude);
    } catch (_) {
      return null;
    }
  }

  /// Статус разрешения без запроса диалога.
  static Future<PermissionStatus> permissionStatus() =>
      Permission.locationWhenInUse.status;
}
