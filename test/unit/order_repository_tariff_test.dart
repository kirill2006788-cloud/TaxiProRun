import 'package:flutter_test/flutter_test.dart';
import 'package:koroli_dorog/core/api/repositories/order_repository.dart';
import 'package:koroli_dorog/data/tariffs.dart';
import 'package:koroli_dorog/models/service_type.dart';

void main() {
  group('MockOrderRepository.localTariffs', () {
    test('includes sober_driver for sober mode', () {
      final list = MockOrderRepository.localTariffs(
        serviceType: ServiceType.soberDriver,
      );
      expect(list.any((t) => t.id == 'sober_driver'), isTrue);
      expect(list.any((t) => t.id == 'economy'), isFalse);
    });

    test('excludes sober_driver for taxi mode', () {
      final list = MockOrderRepository.localTariffs(
        serviceType: ServiceType.taxi,
      );
      expect(list.any((t) => t.id == 'sober_driver'), isFalse);
      expect(list.any((t) => t.id == 'economy'), isTrue);
    });

    test('sober_driver rates match catalog', () {
      final sober = Tariffs.byId('sober_driver')!;
      final dto = MockOrderRepository.localTariffs(
        serviceType: ServiceType.soberDriver,
      ).firstWhere((t) => t.id == 'sober_driver');
      expect(dto.clientRatePerKm, sober.clientRatePerKm);
      expect(dto.driverRatePerKm, sober.driverRatePerKm);
    });
  });
}
