import '../api_client.dart';
import '../../../models/models.dart';

/// HTTP-сервис профиля водителя — эндпоинты /api/driver/* из 2048.
class DriverProfileService {
  DriverProfileService(this._client);

  final ApiClient _client;

  /// GET /api/driver/profile?lite=1
  Future<DriverProfile> getProfile({bool lite = true}) async {
    final res = await _client.getJson(
      '/driver/profile',
      query: lite ? {'lite': '1'} : {'lite': '0', 'photos': '1'},
    );
    final profile = res['profile'];
    if (profile is! Map<String, dynamic>) {
      throw StateError('Profile payload missing');
    }
    return DriverProfile.fromServerJson(profile);
  }

  /// POST /api/driver/profile
  Future<DriverProfile> saveProfile(Map<String, dynamic> body) async {
    final res = await _client.postJson('/driver/profile', body: body);
    final profile = res['profile'];
    if (profile is! Map<String, dynamic>) {
      throw StateError('Profile payload missing');
    }
    return DriverProfile.fromServerJson(profile);
  }

  /// POST /api/driver/profile — произвольный payload (KYC-регистрация).
  Future<DriverProfile> submitRegistration(Map<String, dynamic> body) =>
      saveProfile(body);

  /// GET /api/driver/trips?limit=50
  Future<List<TripHistoryItem>> getTrips({int limit = 50}) async {
    final res =
        await _client.getJson('/driver/trips', query: {'limit': '$limit'});
    final trips = res['trips'];
    if (trips is! List) return [];
    return trips
        .whereType<Map<String, dynamic>>()
        .map(TripHistoryItem.fromServerTrip)
        .toList();
  }

  /// POST /api/driver/push-token
  Future<void> savePushToken(
      {required String token, String platform = 'android'}) async {
    await _client.postJson('/driver/push-token', body: {
      'token': token,
      'platform': platform,
    });
  }
}
