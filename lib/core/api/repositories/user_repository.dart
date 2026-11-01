import 'dart:convert';

import '../../services/push_service.dart';
import '../api_client.dart';
import '../api_config.dart';
import '../models/api_models.dart';

abstract class UserRepository {
  Future<ClientProfileDto> fetchProfile({String? token});
  Future<ClientProfileDto> updateProfile({
    required String clientId,
    required String fullName,
    required String phone,
    String? referralCode,
    String? addressHome,
    String? addressWork,
    String? addressFavorite,
    String? avatarBase64,
    String? token,
  });
  Future<void> syncPushToken({
    required String clientId,
    required String token,
    required bool enabled,
    String? authToken,
  });
  Future<int> requestOtp(String phone);
  Future<String> verifyOtp({required String phone, required String code});
  Future<int> activatePromo({
    required String clientId,
    required String code,
    String? token,
  });
}

class UserRepositoryImpl implements UserRepository {
  UserRepositoryImpl({UserRepository? delegate})
      : _delegate = delegate ?? MockUserRepository();

  final UserRepository _delegate;

  @override
  Future<ClientProfileDto> fetchProfile({String? token}) =>
      _delegate.fetchProfile(token: token);

  @override
  Future<ClientProfileDto> updateProfile({
    required String clientId,
    required String fullName,
    required String phone,
    String? referralCode,
    String? addressHome,
    String? addressWork,
    String? addressFavorite,
    String? avatarBase64,
    String? token,
  }) =>
      _delegate.updateProfile(
        clientId: clientId,
        fullName: fullName,
        phone: phone,
        referralCode: referralCode,
        addressHome: addressHome,
        addressWork: addressWork,
        addressFavorite: addressFavorite,
        avatarBase64: avatarBase64,
        token: token,
      );

  @override
  Future<void> syncPushToken({
    required String clientId,
    required String token,
    required bool enabled,
    String? authToken,
  }) =>
      _delegate.syncPushToken(
        clientId: clientId,
        token: token,
        enabled: enabled,
        authToken: authToken,
      );

  @override
  Future<int> requestOtp(String phone) => _delegate.requestOtp(phone);

  @override
  Future<String> verifyOtp({required String phone, required String code}) =>
      _delegate.verifyOtp(phone: phone, code: code);

  @override
  Future<int> activatePromo({
    required String clientId,
    required String code,
    String? token,
  }) =>
      _delegate.activatePromo(clientId: clientId, code: code, token: token);
}

class MockUserRepository implements UserRepository {
  @override
  Future<ClientProfileDto> fetchProfile({String? token}) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return const ClientProfileDto(
      clientId: '+79991234567',
      fullName: 'Анна Смирнова',
      phone: '+7 (999) 123-45-67',
      bonusAvailable: 350,
      referralCount: 2,
      referralCode: 'KD2026',
    );
  }

  @override
  Future<ClientProfileDto> updateProfile({
    required String clientId,
    required String fullName,
    required String phone,
    String? referralCode,
    String? addressHome,
    String? addressWork,
    String? addressFavorite,
    String? avatarBase64,
    String? token,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return ClientProfileDto(
      clientId: clientId,
      fullName: fullName,
      phone: phone,
      bonusAvailable: 350,
      referralCount: 2,
      referralCode: 'KD2026',
      usedReferralCode: referralCode,
      addressHome: addressHome,
      addressWork: addressWork,
      addressFavorite: addressFavorite,
      avatarBase64: avatarBase64,
    );
  }

  @override
  Future<void> syncPushToken({
    required String clientId,
    required String token,
    required bool enabled,
    String? authToken,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }

  @override
  Future<int> requestOtp(String phone) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return 300;
  }

  @override
  Future<String> verifyOtp(
      {required String phone, required String code}) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return 'mock-jwt-token';
  }

  @override
  Future<int> activatePromo({
    required String clientId,
    required String code,
    String? token,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final normalized = code.trim().toUpperCase();
    if (normalized == 'KOROLI' || normalized == 'KD2026') return 10;
    if (normalized == 'WELCOME') return 15;
    throw ApiException('Промокод не найден');
  }
}

class RealUserRepository implements UserRepository {
  RealUserRepository(this._client);

  final ApiClient _client;

  @override
  Future<ClientProfileDto> fetchProfile({String? token}) async {
    final res = await _client.get(ApiEndpoints.clientProfile, token: token);
    if (res.statusCode != 200) {
      throw ApiException('Профиль недоступен',
          statusCode: res.statusCode, body: res.body);
    }
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    if (map['ok'] != true) {
      throw ApiException('Профиль недоступен', body: res.body);
    }
    return ClientProfileDto.fromJson(map);
  }

  @override
  Future<ClientProfileDto> updateProfile({
    required String clientId,
    required String fullName,
    required String phone,
    String? referralCode,
    String? addressHome,
    String? addressWork,
    String? addressFavorite,
    String? avatarBase64,
    String? token,
  }) async {
    final body = <String, dynamic>{
      'clientId': clientId,
      'fullName': fullName.trim(),
      'phone': phone.trim(),
      if (referralCode != null && referralCode.isNotEmpty)
        'referralCode': referralCode,
      if (addressHome != null) 'addressHome': addressHome.trim(),
      if (addressWork != null) 'addressWork': addressWork.trim(),
      if (addressFavorite != null) 'addressFavorite': addressFavorite.trim(),
      if (avatarBase64 != null) 'avatarBase64': avatarBase64,
    };
    final res = await _client.post(
      ApiEndpoints.clientProfile,
      body: body,
      token: token,
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException('Не удалось сохранить профиль',
          statusCode: res.statusCode, body: res.body);
    }
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    return ClientProfileDto.fromJson(map);
  }

  @override
  Future<void> syncPushToken({
    required String clientId,
    required String token,
    required bool enabled,
    String? authToken,
  }) async {
    await _client.post(
      ApiEndpoints.clientPushToken,
      body: {
        'clientId': clientId,
        'token': enabled ? token : '',
        'platform': PushService.instance.platformLabel,
      },
      token: authToken,
    );
  }

  @override
  Future<int> requestOtp(String phone) async {
    final res = await _client.post(
      ApiEndpoints.authOtpRequest,
      body: {'phone': _normalizePhone(phone)},
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException('Не удалось отправить код',
          statusCode: res.statusCode, body: res.body);
    }
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final ttl = map['ttlSec'];
    return ttl is num ? ttl.toInt() : 300;
  }

  @override
  Future<String> verifyOtp(
      {required String phone, required String code}) async {
    final res = await _client.post(
      ApiEndpoints.authOtpVerify,
      body: {
        'phone': _normalizePhone(phone),
        'code': code.replaceAll(RegExp(r'\D'), ''),
        'role': 'client',
      },
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException('Неверный код',
          statusCode: res.statusCode, body: res.body);
    }
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    for (final key in ['token', 'accessToken', 'access_token', 'jwt']) {
      final value = map[key];
      if (value is String && value.isNotEmpty) return value;
    }
    throw ApiException('No token in response');
  }

  @override
  Future<int> activatePromo({
    required String clientId,
    required String code,
    String? token,
  }) async {
    final res = await _client.post(
      ApiEndpoints.clientPromoActivate,
      body: {'clientId': clientId, 'code': code.trim()},
      token: token,
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException('Промокод недействителен',
          statusCode: res.statusCode, body: res.body);
    }
    final map = jsonDecode(res.body) as Map<String, dynamic>;
    final rawDiscount = map['discount'];
    return (rawDiscount is num
            ? rawDiscount.toInt()
            : int.tryParse(rawDiscount?.toString() ?? '') ?? 0)
        .clamp(0, 100);
  }

  String _normalizePhone(String input) {
    var digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11 && digits.startsWith('8')) {
      digits = '7${digits.substring(1)}';
    }
    if (digits.length == 10) digits = '7$digits';
    return digits;
  }
}
