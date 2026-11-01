/// Ключи SharedPreferences — совместимы с 2048.
abstract final class ProfileKeys {
  static const authToken = 'auth_token';
  static const displayName = 'profile_display_name';
  static const fullName = 'profile_full_name';
  static const phone = 'profile_phone';
  static const avatarBase64 = 'profile_avatar_b64';
  static const promoCode = 'promo_code';
  static const promoDiscount = 'promo_discount_percent';
  static const notificationsEnabled = 'notifications_enabled';
  static const addressHome = 'address_home';
  static const addressWork = 'address_work';
  static const addressFavorite = 'address_favorite';
  static const orderHistory = 'order_history';
  static const themeMode = 'theme_mode'; // 'dark' | 'light'
  static const onboardingCompleted = 'onboarding_completed';
  static const activeOrderId = 'active_order_id';
  static const clientVehicles = 'client_vehicles_json';
  static const selectedVehicleId = 'selected_vehicle_id';
}
