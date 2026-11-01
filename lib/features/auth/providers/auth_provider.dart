import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/models/api_models.dart';
import '../../../core/api/repositories/user_repository.dart';
import '../../../core/api/services/api_services.dart';
import '../../../core/auth/phone_utils.dart';
import '../../../core/profile/profile_keys.dart';

enum AuthStatus {
  initializing,
  unauthenticated,
  needsName,
  authenticated,
}

/// SMS-авторизация пассажира (паттерн 2048).
class AuthProvider extends ChangeNotifier {
  AuthProvider({ApiConfigStore? configStore})
      : _config = configStore ?? ApiConfigStore.instance {
    _userService = UserService(
      repository: RealUserRepository(ApiClient(configStore: _config)),
    );
  }

  final ApiConfigStore _config;
  late final UserService _userService;

  AuthStatus _status = AuthStatus.initializing;
  String? _token;
  String? _phone;
  String? _error;
  bool _busy = false;
  bool _onboardingCompleted = false;
  int _resendSecondsRemaining = 0;
  int _otpTtlSec = 300;
  Timer? _resendTimer;

  bool get loaded => _status != AuthStatus.initializing;
  bool get initialized => loaded;
  bool get busy => _busy;
  bool get isLoggedIn => isAuthenticated;
  bool get isAuthenticated =>
      _status == AuthStatus.authenticated || _status == AuthStatus.needsName;
  bool get needsName => _status == AuthStatus.needsName;
  bool get onboardingCompleted => _onboardingCompleted;
  String? get token => _token;
  String? get phone => _phone;
  String? get error => _error;
  String? get errorMessage => _error;
  int get otpTtlSec => _otpTtlSec;
  bool get canResendCode => _resendSecondsRemaining <= 0 && !_busy;
  int get resendSecondsRemaining => _resendSecondsRemaining;

  /// Загрузка сохранённой сессии при старте приложения.
  Future<void> load() => initialize();

  Future<void> initialize() async {
    _status = AuthStatus.initializing;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    _onboardingCompleted = prefs.getBool(ProfileKeys.onboardingCompleted) ?? false;

    final savedToken = prefs.getString(ProfileKeys.authToken);
    if (savedToken == null || savedToken.trim().isEmpty) {
      _token = null;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    _token = savedToken.trim();
    _phone = prefs.getString(ProfileKeys.phone);

    try {
      final profile = await _userService.fetchProfile(token: savedToken);
      await _persistProfile(profile);
      _status = _needsProfileName(profile)
          ? AuthStatus.needsName
          : AuthStatus.authenticated;
    } catch (_) {
      _status = AuthStatus.authenticated;
    }

    notifyListeners();
  }

  Future<int> requestOtp(String phoneInput) async {
    if (!isValidRussianPhone(phoneInput)) {
      _error = 'Введите номер в формате +7 (XXX) XXX-XX-XX';
      notifyListeners();
      throw ArgumentError(_error);
    }

    _busy = true;
    _error = null;
    notifyListeners();

    try {
      final normalized = normalizePhone(phoneInput);
      _otpTtlSec = await _userService.requestOtp(normalized);
      _phone = normalized;
      _startResendTimer(60);
      return _otpTtlSec;
    } catch (e) {
      _error = _mapError(e, fallback: 'Не удалось отправить код');
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> verifyOtp(String codeInput) async {
    final phone = _phone;
    if (phone == null || phone.isEmpty) {
      _error = 'Сначала укажите номер телефона';
      notifyListeners();
      throw StateError(_error!);
    }

    final code = normalizeOtpCode(codeInput);
    if (code.length < 4) {
      _error = 'Введите код из SMS (4–6 цифр)';
      notifyListeners();
      throw ArgumentError(_error);
    }

    _busy = true;
    _error = null;
    notifyListeners();

    try {
      final jwt = await _userService.verifyOtp(phone: phone, code: code);
      await _persistSession(jwt, formatPhoneForDisplay(phone));

      ClientProfileDto? profile;
      try {
        profile = await _userService.fetchProfile(token: jwt);
        await _persistProfile(profile);
      } catch (_) {}

      _status = _needsProfileName(profile)
          ? AuthStatus.needsName
          : AuthStatus.authenticated;
      _stopResendTimer();
    } catch (e) {
      _error = _mapError(e, fallback: 'Неверный код');
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> saveName(String nameInput) async {
    final name = nameInput.trim();
    if (name.length < 2) {
      _error = 'Введите имя (минимум 2 символа)';
      notifyListeners();
      return false;
    }

    final token = _token;
    final phone = _phone;
    if (token == null || phone == null) {
      _error = 'Сессия истекла. Войдите снова';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }

    _busy = true;
    _error = null;
    notifyListeners();

    try {
      final profile = await _userService.updateProfile(
        clientId: phone,
        fullName: name,
        phone: formatPhoneForDisplay(phone),
        token: token,
      );
      await _persistProfile(profile, displayName: name);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _error = _mapError(e, fallback: 'Не удалось сохранить имя');
      notifyListeners();
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> completeOnboarding() async {
    _onboardingCompleted = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(ProfileKeys.onboardingCompleted, true);
    notifyListeners();
  }

  Future<void> logout() async {
    _stopResendTimer();
    _token = null;
    _phone = null;
    _error = null;
    _status = AuthStatus.unauthenticated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ProfileKeys.authToken);
    notifyListeners();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopResendTimer();
    super.dispose();
  }

  Future<void> _persistSession(String token, String phoneDisplay) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ProfileKeys.authToken, token);
    await prefs.setString(ProfileKeys.phone, phoneDisplay);
  }

  bool _needsProfileName(ClientProfileDto? profile) {
    if (profile == null) return true;
    final name = profile.fullName?.trim();
    return name == null || name.isEmpty;
  }

  Future<void> _persistProfile(
    ClientProfileDto profile, {
    String? displayName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final name = displayName ?? profile.fullName?.trim();
    if (name != null && name.isNotEmpty) {
      await prefs.setString(ProfileKeys.displayName, name);
      await prefs.setString(ProfileKeys.fullName, name);
    }
    if (profile.phone != null && profile.phone!.trim().isNotEmpty) {
      await prefs.setString(ProfileKeys.phone, profile.phone!.trim());
    }
  }

  void _startResendTimer(int seconds) {
    _stopResendTimer();
    _resendSecondsRemaining = seconds;
    notifyListeners();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSecondsRemaining <= 1) {
        _resendSecondsRemaining = 0;
        timer.cancel();
      } else {
        _resendSecondsRemaining--;
      }
      notifyListeners();
    });
  }

  void _stopResendTimer() {
    _resendTimer?.cancel();
    _resendTimer = null;
    _resendSecondsRemaining = 0;
  }

  String _mapError(Object error, {required String fallback}) {
    if (error is ApiException) {
      if (error.statusCode != null && error.statusCode! >= 500) {
        return 'Ошибка сервера. Попробуйте позже';
      }
      final body = error.body?.toLowerCase() ?? '';
      if (body.contains('invalid') || body.contains('otp')) {
        return 'Неверный код';
      }
      return error.message.isNotEmpty ? error.message : fallback;
    }
    if (error is SocketException || error is TimeoutException) {
      return 'Нет связи с сервером. Проверьте интернет';
    }
    if (error is HttpException) {
      return 'Ошибка сети. Попробуйте позже';
    }
    return fallback;
  }
}
