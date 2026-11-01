import '../../../data/mock_data.dart';
import '../../../models/models.dart';
import '../trip_status_machine.dart';
import 'repositories.dart';

class MockOrdersRepository implements OrdersRepository {
  MockOrdersRepository() {
    _pending = [];
    _history = MockData.history();
  }

  late List<DriverOrder> _pending;
  DriverOrder? _active;
  late List<TripHistoryItem> _history;

  @override
  Future<List<DriverOrder>> fetchPendingOffers() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _pending
        .where((o) => o.status == TripOrderStatus.searching)
        .toList(growable: false);
  }

  @override
  Future<DriverOrder?> fetchActiveOrder() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    return _active;
  }

  @override
  Future<DriverOrder> accept(String orderId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final index = _pending.indexWhere((o) => o.id == orderId);
    if (index < 0 || _active != null) {
      throw StateError('Order unavailable');
    }
    final accepted = _pending[index].copyWith(status: TripOrderStatus.accepted);
    _pending[index] = accepted;
    _active = accepted;
    return accepted;
  }

  @override
  Future<void> skip(String orderId, {String? reason}) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final index = _pending.indexWhere((o) => o.id == orderId);
    if (index < 0) return;
    _pending[index] = _pending[index].copyWith(status: TripOrderStatus.skipped);
  }

  @override
  Future<DriverOrder> advanceStatus(
    String orderId,
    TripOrderStatus nextStatus,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final active = _active;
    if (active == null || active.id != orderId) {
      throw StateError('No active order');
    }
    if (!TripStatusMachine.canTransition(active.status, nextStatus)) {
      throw StateError('Invalid transition ${active.status} -> $nextStatus');
    }
    final updated = active.copyWith(status: nextStatus);
    _active = TripStatusMachine.isActive(nextStatus) ? updated : null;

    if (nextStatus == TripOrderStatus.completed) {
      _history.insert(
        0,
        TripHistoryItem(
          id: 'hist-$orderId',
          completedAt: DateTime.now(),
          pickup: active.pickup,
          dropoff: active.dropoff,
          earningsRub: (active.priceFinal ?? active.price).round(),
          clientRating: 5,
          clientName: active.passengerName,
          tariff: active.tariff,
          serviceType: active.serviceType,
        ),
      );
      final idx = _pending.indexWhere((o) => o.id == orderId);
      if (idx >= 0) {
        _pending[idx] = updated;
      }
    } else {
      _active = updated;
    }
    return updated;
  }

  @override
  Future<List<TripHistoryItem>> fetchHistory() async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return List.unmodifiable(_history);
  }

  void restoreMockQueue() {
    _pending = [];
    _active = null;
  }
}
