import 'package:flutter_test/flutter_test.dart';
import 'package:koroli_dorog/core/pricing/fare_calculator.dart';
import 'package:koroli_dorog/data/tariffs.dart';

void main() {
  group('FareCalculator.compute', () {
    test('economy 10 km without options', () {
      final quote = FareCalculator.compute(
        const FareQuoteInput(clientRatePerKm: 37, distanceKm: 10),
      );
      expect(quote.base, 111);
      expect(quote.distance, 370);
      expect(quote.options, 0);
      expect(quote.total, 481);
    });

    test('adds surcharges and discount', () {
      final quote = FareCalculator.compute(
        const FareQuoteInput(
          clientRatePerKm: 37,
          distanceKm: 10,
          stopsCount: 1,
          withKids: true,
          withPets: true,
          airConditioning: true,
          discountPercent: 10,
        ),
      );
      expect(quote.options, greaterThan(200));
      expect(quote.discount, greaterThan(0));
      expect(quote.total, lessThan(quote.base + quote.distance + quote.options));
    });
  });

  group('FareCalculator.fromTariff', () {
    test('standard matches Kleo client rate', () {
      final tariff = Tariffs.byId('standard')!;
      final quote = FareCalculator.fromTariff(
        tariff: tariff,
        distanceKm: 5,
      );
      expect(quote.base, 129); // 43 * 3
      expect(quote.distance, 215); // 43 * 5
      expect(quote.total, 344);
    });
  });

  group('inferDriverRatePerKm', () {
    test('uses 33/43 ratio for unknown tariffs', () {
      expect(inferDriverRatePerKm(65), 50);
      expect(inferDriverRatePerKm(47), 36);
      expect(inferDriverRatePerKm(120), 92);
    });

    test('sober driver Kleo rates', () {
      final tariff = Tariffs.byId('sober_driver')!;
      expect(tariff.clientRatePerKm, 120);
      expect(tariff.driverRatePerKm, 92);
      final quote = FareCalculator.fromTariff(tariff: tariff, distanceKm: 10);
      expect(quote.base, 360);
      expect(quote.distance, 1200);
      expect(quote.total, 1560);
    });
  });
}
