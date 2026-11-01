import '../../models/models.dart';

/// Машина состояний поездки — порт логики из backend_vps/orders.service.ts.
abstract final class TripStatusMachine {
  static const Map<TripOrderStatus, List<TripOrderStatus>> allowedTransitions = {
    TripOrderStatus.searching: [TripOrderStatus.accepted],
    TripOrderStatus.accepted: [TripOrderStatus.enroute, TripOrderStatus.canceled],
    TripOrderStatus.enroute: [TripOrderStatus.arrived, TripOrderStatus.canceled],
    TripOrderStatus.arrived: [TripOrderStatus.started, TripOrderStatus.canceled],
    TripOrderStatus.started: [TripOrderStatus.completed, TripOrderStatus.canceled],
    TripOrderStatus.completed: [],
    TripOrderStatus.canceled: [],
  };

  static bool canTransition(TripOrderStatus from, TripOrderStatus to) {
    return allowedTransitions[from]?.contains(to) ?? false;
  }

  static TripOrderStatus? nextDriverAction(TripOrderStatus current) {
    return switch (current) {
      TripOrderStatus.accepted => TripOrderStatus.enroute,
      TripOrderStatus.enroute => TripOrderStatus.arrived,
      TripOrderStatus.arrived => TripOrderStatus.started,
      TripOrderStatus.started => TripOrderStatus.completed,
      _ => null,
    };
  }

  static String actionLabel(TripOrderStatus current) {
    return switch (current) {
      TripOrderStatus.accepted => 'В путь',
      TripOrderStatus.enroute => 'Прибыл',
      TripOrderStatus.arrived => 'Начать поездку',
      TripOrderStatus.started => 'Завершить',
      _ => 'Далее',
    };
  }

  static String statusLabel(TripOrderStatus status) {
    return switch (status) {
      TripOrderStatus.searching => 'Поиск водителя',
      TripOrderStatus.accepted => 'Принят',
      TripOrderStatus.enroute => 'Едете к клиенту',
      TripOrderStatus.arrived => 'Вы на месте',
      TripOrderStatus.started => 'Поездка начата',
      TripOrderStatus.completed => 'Завершён',
      TripOrderStatus.canceled => 'Отменён',
      TripOrderStatus.skipped => 'Пропущен',
    };
  }

  static bool isActive(TripOrderStatus status) {
    return status == TripOrderStatus.accepted ||
        status == TripOrderStatus.enroute ||
        status == TripOrderStatus.arrived ||
        status == TripOrderStatus.started;
  }
}
