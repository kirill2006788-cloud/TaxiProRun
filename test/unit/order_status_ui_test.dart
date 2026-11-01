import 'package:flutter_test/flutter_test.dart';
import 'package:koroli_dorog/core/order/order_status_ui.dart';

void main() {
  group('OrderStatusUi.stepFor', () {
    test('maps trip phases to stepper index', () {
      expect(OrderStatusUi.stepFor('accepted'), 0);
      expect(OrderStatusUi.stepFor('enroute'), 1);
      expect(OrderStatusUi.stepFor('arrived'), 2);
      expect(OrderStatusUi.stepFor('started'), 3);
      expect(OrderStatusUi.stepFor('completed'), 3);
      expect(OrderStatusUi.stepFor('searching'), -1);
      expect(OrderStatusUi.stepFor('canceled'), -1);
    });
  });

  group('OrderStatusUi.labelFor', () {
    test('returns Russian labels for all trip phases', () {
      const cases = {
        'searching': 'Ищем водителя…',
        'accepted': 'Водитель принял заказ',
        'enroute': 'Водитель едет к вам',
        'arrived': 'Водитель на месте',
        'started': 'Поездка началась',
        'completed': 'Поездка завершена',
        'canceled': 'Заказ отменён',
        'cancelled': 'Заказ отменён',
      };

      for (final entry in cases.entries) {
        expect(OrderStatusUi.labelFor(entry.key), entry.value);
      }
    });
  });

  group('OrderStatusUi.historyLabelFor', () {
    test('maps history list statuses', () {
      expect(OrderStatusUi.historyLabelFor('completed'), 'Завершена');
      expect(OrderStatusUi.historyLabelFor('searching'), 'Поиск');
      expect(OrderStatusUi.historyLabelFor('enroute'), 'Активна');
      expect(OrderStatusUi.historyLabelFor('canceled'), 'Отменён');
    });
  });
}
