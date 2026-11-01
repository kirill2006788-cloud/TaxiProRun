import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_config.dart';
import '../../../core/api/models/api_models.dart';
import '../../../core/api/repositories/settings_repository.dart';
import '../../../core/api/services/api_services.dart';
import '../../../core/config/feature_flags.dart';
import '../../../core/profile/profile_keys.dart';
import '../../../core/services/push_service.dart';
import '../../../models/service_type.dart';

/// Провайдер настроек приложения (логика 2048 + расширения TaxiPro).
class SettingsProvider extends ChangeNotifier {
  SettingsProvider({
    ApiServices? apiServices,
    ApiConfigStore? configStore,
  })  : _api = apiServices ?? ApiServices(),
        _config = configStore ?? ApiConfigStore.instance {
    _pushTokenSubscription = PushService.instance.onTokenRefresh.listen(
      (token) {
        if (_loaded && notificationsEnabled) {
          unawaited(_syncPushToken(enabled: true, remoteToken: token));
        }
      },
    );
  }

  final ApiServices _api;
  final ApiConfigStore _config;

  bool _loaded = false;
  bool _saving = false;
  AppSettingsDto _settings = const AppSettingsDto();
  String _devServerUrl = ApiConfig.envBaseUrl;
  bool _useMockApi = ApiConfig.useMockApi;
  bool _demoTripEnabled = false;
  ThemeMode _themeMode = ThemeMode.dark;
  StreamSubscription<String>? _pushTokenSubscription;

  bool get loaded => _loaded;
  bool get saving => _saving;
  AppSettingsDto get settings => _settings;
  String get devServerUrl => _devServerUrl;
  bool get useMockApi => _useMockApi;
  bool get demoTripEnabled => _demoTripEnabled;
  String get effectiveBaseUrl => _config.baseUrl;
  ThemeMode get themeMode => _themeMode;
  bool get isLightTheme => _themeMode == ThemeMode.light;

  bool get notificationsEnabled => _settings.notificationsEnabled;
  bool get tripUpdatesEnabled => _settings.tripUpdatesEnabled;
  bool get promoEnabled => _settings.promoEnabled;
  ServiceType get defaultServiceType => _settings.defaultServiceType;
  bool get defaultWithKids => _settings.defaultWithKids;
  bool get defaultWithPets => _settings.defaultWithPets;
  bool get defaultStopsEnabled => _settings.defaultStopsEnabled;
  bool get defaultAdvanceBooking => _settings.defaultAdvanceBooking;

  Future<void> load() async {
    final savedUrl = await MockSettingsRepository.loadDevServerUrl();
    final savedMock = await MockSettingsRepository.loadUseMockApi();
    final savedDemoTrip = await MockSettingsRepository.loadDemoTripEnabled();
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _devServerUrl = savedUrl;
      _config.setBaseUrl(savedUrl);
    }
    _useMockApi = kDebugMode && savedMock;
    _config.setUseMockApi(_useMockApi);
    _demoTripEnabled = FeatureFlags.enableDemoMode && savedDemoTrip;
    if (!_useMockApi && savedMock) {
      await MockSettingsRepository.saveUseMockApi(false);
    }
    if (!_demoTripEnabled && savedDemoTrip) {
      await MockSettingsRepository.saveDemoTripEnabled(false);
    }

    _settings = await _api.settings.loadLocalSettings();

    // Legacy key from 2048
    final prefs = await SharedPreferences.getInstance();
    final legacyNotifications =
        prefs.getBool(SettingsKeys.notificationsEnabled);
    if (legacyNotifications != null &&
        legacyNotifications != _settings.notificationsEnabled) {
      _settings = _settings.copyWith(notificationsEnabled: legacyNotifications);
    }

    final themeRaw = prefs.getString(ProfileKeys.themeMode);
    _themeMode = themeRaw == 'light' ? ThemeMode.light : ThemeMode.dark;

    _loaded = true;
    PushService.instance.setEnabled(notificationsEnabled);
    notifyListeners();
    if (notificationsEnabled) {
      unawaited(PushService.instance.requestPermission());
      unawaited(_syncPushToken(enabled: true));
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    // Theme changes are visual state: repaint immediately and persist in the
    // background instead of making the UI wait for SharedPreferences I/O.
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      ProfileKeys.themeMode,
      mode == ThemeMode.light ? 'light' : 'dark',
    );
  }

  Future<void> setLightTheme(bool value) =>
      setThemeMode(value ? ThemeMode.light : ThemeMode.dark);

  Future<void> setNotificationsEnabled(bool value) async {
    if (value) {
      final granted = await PushService.instance.requestPermission();
      if (!granted) return;
    }

    _settings = _settings.copyWith(notificationsEnabled: value);
    PushService.instance.setEnabled(value);
    notifyListeners();
    await _persist();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(SettingsKeys.notificationsEnabled, value);
    await prefs.setBool(ProfileKeys.notificationsEnabled, value);
    await _syncPushToken(enabled: value);
  }

  Future<void> _syncPushToken({
    required bool enabled,
    String? remoteToken,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString(ProfileKeys.authToken);
      final phone = prefs.getString(ProfileKeys.phone) ?? '';
      var clientId = phone.replaceAll(RegExp(r'\D'), '');
      if (clientId.length == 11 && clientId.startsWith('8')) {
        clientId = '7${clientId.substring(1)}';
      }
      if (clientId.length == 10) clientId = '7$clientId';
      if (clientId.isEmpty) return;

      final token = enabled
          ? remoteToken ?? await PushService.instance.getTokenForApi()
          : '';
      if (enabled && (token == null || token.isEmpty)) return;
      await _api.user.syncPushToken(
        clientId: clientId,
        token: token ?? '',
        enabled: enabled,
        authToken: authToken,
      );
    } catch (error) {
      debugPrint('Push token sync failed: $error');
    }
  }

  Future<void> setTripUpdatesEnabled(bool value) async {
    _settings = _settings.copyWith(tripUpdatesEnabled: value);
    notifyListeners();
    await _persist();
  }

  Future<void> setPromoEnabled(bool value) async {
    _settings = _settings.copyWith(promoEnabled: value);
    notifyListeners();
    await _persist();
  }

  Future<void> setDefaultServiceType(ServiceType value) async {
    _settings = _settings.copyWith(defaultServiceType: value);
    notifyListeners();
    await _persist();
  }

  Future<void> setDefaultWithKids(bool value) async {
    _settings = _settings.copyWith(defaultWithKids: value);
    notifyListeners();
    await _persist();
  }

  Future<void> setDefaultWithPets(bool value) async {
    _settings = _settings.copyWith(defaultWithPets: value);
    notifyListeners();
    await _persist();
  }

  Future<void> setDefaultStopsEnabled(bool value) async {
    _settings = _settings.copyWith(defaultStopsEnabled: value);
    notifyListeners();
    await _persist();
  }

  Future<void> setDefaultAdvanceBooking(bool value) async {
    _settings = _settings.copyWith(defaultAdvanceBooking: value);
    notifyListeners();
    await _persist();
  }

  Future<void> setDevServerUrl(String url) async {
    final trimmed = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (trimmed.isEmpty) return;
    _devServerUrl = trimmed;
    _config.setBaseUrl(trimmed);
    await MockSettingsRepository.saveDevServerUrl(trimmed);
    notifyListeners();
  }

  Future<void> setUseMockApi(bool value) async {
    if (!kDebugMode) return;
    _useMockApi = value;
    _config.setUseMockApi(value);
    await MockSettingsRepository.saveUseMockApi(value);
    notifyListeners();
  }

  Future<void> setDemoTripEnabled(bool value) async {
    if (!FeatureFlags.enableDemoMode) return;
    _demoTripEnabled = value;
    await MockSettingsRepository.saveDemoTripEnabled(value);
    notifyListeners();
  }

  Future<void> resetDevServerUrl() async {
    _devServerUrl = ApiConfig.defaultBaseUrl;
    _config.setBaseUrl(ApiConfig.defaultBaseUrl);
    await MockSettingsRepository.saveDevServerUrl(ApiConfig.defaultBaseUrl);
    notifyListeners();
  }

  Future<void> _persist() async {
    _saving = true;
    notifyListeners();
    try {
      await _api.settings.saveLocalSettings(_settings);
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pushTokenSubscription?.cancel();
    super.dispose();
  }
}
