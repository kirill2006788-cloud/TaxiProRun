import '../api_client.dart';

/// Настройки и статус водителя — REST + WebSocket driver:status.
class SettingsService {
  SettingsService(this._client);

  final ApiClient _client;

  /// WebSocket driver:status { status: online|offline|busy }
  Map<String, dynamic> driverStatusPayload(String status) => {'status': status};

  /// POST /api/auth/otp/request
  Future<int> requestOtp(String phone) async {
    final res = await _client.postJson('/auth/otp/request', body: {'phone': phone});
    final ttl = res['ttlSec'];
    return (ttl is num) ? ttl.toInt() : 300;
  }

  /// POST /api/auth/otp/verify (role: driver)
  Future<String> verifyOtp({required String phone, required String code}) async {
    final res = await _client.postJson('/auth/otp/verify', body: {
      'phone': phone,
      'code': code,
      'role': 'driver',
    });
    for (final key in ['token', 'accessToken', 'access_token', 'jwt']) {
      final value = res[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    throw StateError('No token in auth response');
  }
}
