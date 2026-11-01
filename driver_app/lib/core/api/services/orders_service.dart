import '../api_client.dart';
import '../../../models/models.dart';

class OrdersService {
  OrdersService(this._client);

  final ApiClient _client;

  Future<DriverOrder?> getActiveOrder() async {
    final res = await _client.getJson('/orders/active/driver');
    final order = res['order'];
    if (order is! Map<String, dynamic>) return null;
    return DriverOrder.fromServerJson(order);
  }

  Future<DriverOrder> getOrder(String orderId) async {
    final res = await _client.getJson('/orders/$orderId');
    final order = res['order'];
    if (order is! Map<String, dynamic>) {
      throw StateError('Order payload missing');
    }
    return DriverOrder.fromServerJson(order);
  }

  Future<Map<String, dynamic>> acceptOrderPayload(String orderId) async {
    return {'orderId': orderId};
  }

  Future<Map<String, dynamic>> declineOrderPayload(String orderId) async {
    return {'orderId': orderId};
  }

  Future<Map<String, dynamic>> updateStatusPayload(
    String orderId,
    TripOrderStatus status,
  ) async {
    return {
      'orderId': orderId,
      'status': status.name,
    };
  }

  Future<List<TripHistoryItem>> fetchTripHistory({int limit = 50}) async {
    final res =
        await _client.getJson('/driver/trips', query: {'limit': '$limit'});
    final trips = res['trips'];
    if (trips is! List) return [];
    return trips
        .whereType<Map<String, dynamic>>()
        .map(TripHistoryItem.fromServerTrip)
        .toList();
  }
}
