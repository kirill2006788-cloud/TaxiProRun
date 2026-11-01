import 'package:shared_preferences/shared_preferences.dart';

import '../profile/profile_keys.dart';

/// Хранение JWT (ключ `auth_token`, совместим с 2048).
class AuthStore {
  Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(ProfileKeys.authToken);
    if (token == null || token.trim().isEmpty) return null;
    return token.trim();
  }

  Future<void> writeToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ProfileKeys.authToken, token.trim());
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ProfileKeys.authToken);
  }
}
