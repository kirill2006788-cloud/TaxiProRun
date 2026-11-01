import '../../../models/models.dart';
import '../api_exception.dart';
import '../services/orders_service.dart';
import '../socket_service.dart';
import '../trip_status_machine.dart';
import 'repositories.dart';

class ApiOrdersRepository implements OrdersRepository {
  ApiOrdersRepository(this._service, this._socket);

  final OrdersService _service;
  final SocketService _socket;

  @override
  Future<List<DriverOrder>> fetchPendingOffers() async {
    return [];
  }

  @override
  Future<DriverOrder?> fetchActiveOrder() => _service.getActiveOrder();

  @override
  Future<DriverOrder> accept(String orderId) async {
    final ack = await _socket.emitOrderAccept(orderId);
    if (ack['ok'] != true) {
      final code = ack['error']?.toString() ?? 'ORDER_TAKEN';
      throw ApiException(
        statusCode: 409,
        code: code,
        message: ack['message']?.toString() ??
            apiErrorMessage(ApiException(statusCode: 409, code: code)),
      );
    }
    final orderMap = ack['order'];
    if (orderMap is Map) {
      return DriverOrder.fromServerJson(orderMap.cast<String, dynamic>());
    }
    return _service.getOrder(orderId);
  }

  @override
  Future<void> skip(String orderId, {String? reason}) async {
    final ack = await _socket.emitOrderDecline(orderId, reason: reason);
    if (ack['ok'] != true) {
      final code = ack['error']?.toString();
      throw ApiException(
        statusCode: 400,
        code: code,
        message: ack['message']?.toString() ?? 'Не удалось отклонить заказ',
      );
    }
  }

  @override
  Future<DriverOrder> advanceStatus(
    String orderId,
    TripOrderStatus nextStatus,
  ) async {
    final current = await _service.getOrder(orderId);
    if (!TripStatusMachine.canTransition(current.status, nextStatus)) {
      throw StateError('Недопустимый переход статуса');
    }
    final ack = await _socket.emitOrderUpdate(
      orderId: orderId,
      status: nextStatus.name,
    );
    if (ack['ok'] != true) {
      throw ApiException(
        statusCode: 400,
        code: ack['error']?.toString(),
        message: ack['message']?.toString() ?? 'Не удалось обновить статус',
      );
    }
    final orderMap = ack['order'];
    if (orderMap is Map) {
      return DriverOrder.fromServerJson(orderMap.cast<String, dynamic>());
    }
    return _service.getOrder(orderId);
  }

  @override
  Future<List<TripHistoryItem>> fetchHistory() async {
    return _service.fetchTripHistory();
  }
}
