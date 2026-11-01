import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../api_client.dart';
import '../api_config.dart';
import '../models/api_models.dart';

abstract class SettingsRepository {
  Future<AppSettingsDto> loadLocalSettings();
  Future<void> saveLocalSettings(AppSettingsDto settings);
  Future<AppSettingsDto?> fetchRemoteSettings({String? token});
  Future<void> saveRemoteSettings(AppSettingsDto settings, {String? token});
}

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl({SettingsRepository? delegate})
      : _delegate = delegate ?? MockSettingsRepository();

  final SettingsRepository _delegate;

  @override
  Future<AppSettingsDto> loadLocalSettings() => _delegate.loadLocalSettings();

  @override
  Future<void> saveLocalSettings(AppSettingsDto settings) =>
      _delegate.saveLocalSettings(settings);

  @override
  Future<AppSettingsDto?> fetchRemoteSettings({String? token}) =>
      _delegate.fetchRemoteSettings(token: token);

  @override
  Future<void> saveRemoteSettings(AppSettingsDto settings, {String? token}) =>
      _delegate.saveRemoteSettings(settings, token: token);
}

class MockSettingsRepository implements SettingsRepository {
  static const _settingsKey = 'app_settings_json';
  static const _serverUrlKey = 'dev_server_url';
  static const _useMockKey = 'use_mock_api';
  static const _demoTripKey = 'demo_trip_enabled';

  @override
  Future<AppSettingsDto> loadLocalSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw == null || raw.isEmpty) return const AppSettingsDto();
    try {
      return AppSettingsDto.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const AppSettingsDto();
    }
  }

  @override
  Future<void> saveLocalSettings(AppSettingsDto settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  @override
  Future<AppSettingsDto?> fetchRemoteSettings({String? token}) async {
    return loadLocalSettings();
  }

  @override
  Future<void> saveRemoteSettings(AppSettingsDto settings,
      {String? token}) async {
    await saveLocalSettings(settings);
  }

  static Future<String?> loadDevServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_serverUrlKey);
  }

  static Future<void> saveDevServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, url.trim());
  }

  static Future<bool> loadUseMockApi() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_useMockKey) ?? ApiConfig.useMockApi;
  }

  static Future<void> saveUseMockApi(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useMockKey, value);
  }

  static Future<bool> loadDemoTripEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_demoTripKey) ?? false;
  }

  static Future<void> saveDemoTripEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_demoTripKey, value);
  }
}

class RealSettingsRepository implements SettingsRepository {
  RealSettingsRepository(this._client);

  final ApiClient _client;
  final _local = MockSettingsRepository();

  @override
  Future<AppSettingsDto> loadLocalSettings() => _local.loadLocalSettings();

  @override
  Future<void> saveLocalSettings(AppSettingsDto settings) =>
      _local.saveLocalSettings(settings);

  @override
  Future<AppSettingsDto?> fetchRemoteSettings({String? token}) async {
    try {
      final res = await _client.get(ApiEndpoints.appSettings, token: token);
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      return AppSettingsDto.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveRemoteSettings(AppSettingsDto settings,
      {String? token}) async {
    await _local.saveLocalSettings(settings);
    await _client.put(
      ApiEndpoints.appSettings,
      body: settings.toJson(),
      token: token,
    );
  }
}

/// Ключи настроек (совместимы с 2048 где применимо).
abstract final class SettingsKeys {
  static const notificationsEnabled = 'notifications_enabled';
  static const tripUpdatesEnabled = 'trip_updates_enabled';
  static const promoEnabled = 'promo_enabled';
  static const defaultServiceType = 'default_service_type';
  static const defaultWithKids = 'default_with_kids';
  static const defaultWithPets = 'default_with_pets';
  static const defaultStopsEnabled = 'default_stops_enabled';
  static const defaultAdvanceBooking = 'default_advance_booking';
  static const devServerUrl = 'dev_server_url';
  static const useMockApi = 'use_mock_api';
  static const demoTripEnabled = 'demo_trip_enabled';
  static const themeMode = 'theme_mode';
}
