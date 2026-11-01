import '../../../models/models.dart';

abstract class OrdersRepository {
  Future<List<DriverOrder>> fetchPendingOffers();
  Future<DriverOrder?> fetchActiveOrder();
  Future<DriverOrder> accept(String orderId);
  Future<void> skip(String orderId, {String? reason});
  Future<DriverOrder> advanceStatus(String orderId, TripOrderStatus nextStatus);
  Future<List<TripHistoryItem>> fetchHistory();
}

abstract class DriverProfileRepository {
  Future<DriverProfile> loadProfile();
  Future<DriverProfile> loadFullProfile();
  Future<DriverProfile> saveProfile(DriverProfile profile);
  Future<DriverProfile> saveProfilePayload(Map<String, dynamic> body);
}

abstract class SettingsRepository {
  Future<DriverSettings> load();
  Future<void> save(DriverSettings settings);
  Future<void> syncOnlineStatus(bool online);
}
