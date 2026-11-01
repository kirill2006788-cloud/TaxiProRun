import 'package:flutter/foundation.dart';

import '../core/api/api_config.dart';
import '../core/api/api_exception.dart';
import '../core/api/app_services.dart';
import '../core/api/services/settings_service.dart';
import '../core/auth/auth_store.dart';
import '../core/auth/phone_utils.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    required AuthStore store,
    required SettingsService settingsService,
  })  : _store = store,
        _settingsService = settingsService;

  final AuthStore _store;
  final SettingsService _settingsService;

  bool _initialized = false;
  bool _loading = false;
  String? _token;
  String? _phone;

  bool get initialized => _initialized;
  bool get loading => _loading;
  bool get isLoggedIn => _token != null && _token!.isNotEmpty;
  String? get token => _token;
  String? get phone => _phone;

  Future<void> bootstrap() async {
    _token = await _store.readToken();
    if (_token != null) {
      AppServices.instance.connectSocket(_token!);
    }
    _initialized = true;
    notifyListeners();
  }

  Future<int> requestOtp(String phoneInput) async {
    final normalized = normalizePhone(phoneInput);
    if (normalized.length != 11) {
      throw const FormatException('Введите корректный номер телефона');
    }
    _phone = normalized;
    if (ApiConfig.useMock) {
      return 300;
    }
    return _settingsService.requestOtp(normalized);
  }

  Future<void> verifyOtp({
    required String phoneInput,
    required String codeInput,
  }) async {
    _loading = true;
    notifyListeners();
    try {
      final normalizedPhone = normalizePhone(phoneInput);
      final code = normalizeOtpCode(codeInput);
      final token = ApiConfig.useMock
          ? 'mock_driver_token_$normalizedPhone'
          : await _settingsService.verifyOtp(phone: normalizedPhone, code: code);
      await _store.writeToken(token);
      _token = token;
      _phone = normalizedPhone;
      AppServices.instance.connectSocket(token);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    AppServices.instance.disconnectSocket();
    await _store.clear();
    _token = null;
    _phone = null;
    AppServices.instance.client.setAuthToken(null);
    notifyListeners();
  }

  String otpErrorMessage(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 429) {
        return 'Слишком часто. Подождите и попробуйте снова';
      }
      if (error.statusCode == 502) {
        return 'СМС сервис недоступен. Попробуйте позже';
      }
      if (error.message != null && error.message!.trim().isNotEmpty) {
        return error.message!;
      }
    }
    if (error is FormatException) return error.message;
    return 'Неверный код';
  }

  String requestOtpErrorMessage(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 429) {
        return 'Слишком часто. Подождите минуту';
      }
      if (error.statusCode == 502) {
        return 'СМС сервис недоступен. Попробуйте позже';
      }
      if (error.message != null && error.message!.trim().isNotEmpty) {
        return error.message!;
      }
    }
    if (error is FormatException) return error.message;
    return 'Не удалось отправить код';
  }
}
