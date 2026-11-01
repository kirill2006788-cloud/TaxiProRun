import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_config.dart';

/// Хранение JWT водителя (ключ `auth_token`, как в 2048 prosto_taxi_driver).
class AuthStore {
  Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(ApiConfig.authTokenKey);
    if (token == null || token.trim().isEmpty) return null;
    return token.trim();
  }

  Future<void> writeToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ApiConfig.authTokenKey, token.trim());
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ApiConfig.authTokenKey);
  }
}
