/// UI mapping for passenger active-trip order statuses.
abstract final class OrderStatusUi {
  /// Progress step for stepper (0–3), or -1 when not in active trip flow.
  static int stepFor(String status) {
    return switch (status) {
      'accepted' => 0,
      'enroute' => 1,
      'arrived' => 2,
      'started' => 3,
      'completed' => 3,
      _ => -1,
    };
  }

  /// Russian label for trip status banner.
  static String labelFor(String status) {
    return switch (status) {
      'searching' => 'Ищем водителя…',
      'accepted' => 'Водитель принял заказ',
      'enroute' => 'Водитель едет к вам',
      'arrived' => 'Водитель на месте',
      'started' => 'Поездка началась',
      'completed' => 'Поездка завершена',
      'canceled' || 'cancelled' => 'Заказ отменён',
      _ => 'Статус: $status',
    };
  }

  /// History list label (trips screen).
  static String historyLabelFor(String status) {
    if (status == 'canceled' || status == 'cancelled') {
      return 'Отменён';
    }
    return switch (status) {
      'completed' => 'Завершена',
      'searching' => 'Поиск',
      'accepted' || 'enroute' || 'arrived' || 'started' => 'Активна',
      _ => status,
    };
  }
}
