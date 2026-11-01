import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/models.dart';
import '../api_config.dart';
import 'repositories.dart';

NavApp _parseNavApp(String? raw) {
  for (final app in NavApp.values) {
    if (app.name == raw) return app;
  }
  return NavApp.yandex;
}

class MockSettingsRepository implements SettingsRepository {
  DriverSettings _cached = const DriverSettings();

  @override
  Future<DriverSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final themeRaw = prefs.getString(ApiConfig.themeModeKey);
    _cached = DriverSettings(
      notificationsEnabled: prefs.getBool(ApiConfig.notificationsKey) ?? true,
      navApp: _parseNavApp(prefs.getString(ApiConfig.navAppKey)),
      isOnline: prefs.getBool(ApiConfig.onlineKey) ?? false,
      serverUrl: prefs.getString(ApiConfig.serverUrlKey) ?? ApiConfig.defaultBaseUrl,
      useMockApi: prefs.getBool(ApiConfig.useMockKey) ?? false,
      orderAcceptTimeoutSec: prefs.getInt('driver_order_accept_timeout_sec_v1') ?? 15,
      themeMode: themeRaw == 'light' ? 'light' : 'dark',
    );
    ApiConfig.setBaseUrl(_cached.serverUrl);
    ApiConfig.setUseMock(_cached.useMockApi);
    return _cached;
  }

  @override
  Future<void> save(DriverSettings settings) async {
    _cached = settings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(ApiConfig.notificationsKey, settings.notificationsEnabled);
    await prefs.setString(ApiConfig.navAppKey, settings.navApp.name);
    await prefs.setBool(ApiConfig.onlineKey, settings.isOnline);
    await prefs.setString(ApiConfig.serverUrlKey, settings.serverUrl);
    await prefs.setBool(ApiConfig.useMockKey, settings.useMockApi);
    await prefs.setInt('driver_order_accept_timeout_sec_v1', settings.orderAcceptTimeoutSec);
    await prefs.setString(ApiConfig.themeModeKey, settings.themeMode);
    ApiConfig.setBaseUrl(settings.serverUrl);
    ApiConfig.setUseMock(settings.useMockApi);
  }

  @override
  Future<void> syncOnlineStatus(bool online) async {
    // Mock: только локальная персистенция (паттерн 2048 driver_online_v1).
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(ApiConfig.onlineKey, online);
    _cached = _cached.copyWith(isOnline: online);
  }
}
