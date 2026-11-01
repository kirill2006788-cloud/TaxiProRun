import 'package:shared_preferences/shared_preferences.dart';

import '../profile/profile_keys.dart';

/// Persists active order id for cold-start restore.
abstract final class ActiveOrderStore {
  static Future<String?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(ProfileKeys.activeOrderId)?.trim();
    if (id == null || id.isEmpty) return null;
    return id;
  }

  static Future<void> save(String orderId) async {
    final trimmed = orderId.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ProfileKeys.activeOrderId, trimmed);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ProfileKeys.activeOrderId);
  }
}
