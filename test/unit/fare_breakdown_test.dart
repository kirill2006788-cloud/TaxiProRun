import 'package:flutter_test/flutter_test.dart';
import 'package:koroli_dorog/core/geo/geo_math.dart';
import 'package:koroli_dorog/data/tariffs.dart';
import 'package:koroli_dorog/models/booking.dart';
import 'package:koroli_dorog/shared/widgets/fare_breakdown_sheet.dart';

void main() {
  group('FareBreakdown.distanceKmFor', () {
    test('uses stored route distance when set', () {
      const booking = Booking(routeDistanceKm: 18.5);
      expect(FareBreakdown.distanceKmFor(booking), 18.5);
    });

    test('clamps stored distance to valid range', () {
      const booking = Booking(routeDistanceKm: 999);
      expect(FareBreakdown.distanceKmFor(booking), 500.0);
    });

    test('computes road distance from coordinates', () {
      const booking = Booking(
        fromLat: 55.7558,
        fromLng: 37.6173,
        toLat: 55.9736,
        toLng: 37.4144,
      );
      final km = FareBreakdown.distanceKmFor(booking);
      final expected = roadDistanceKm(55.7558, 37.6173, 55.9736, 37.4144)
          .clamp(1.0, 500.0);
      expect(km, closeTo(expected, 0.01));
      expect(km, greaterThan(20));
    });

    test('falls back when coords missing', () {
      const booking = Booking(fromAddress: 'A', toAddress: 'B');
      expect(
        FareBreakdown.distanceKmFor(booking),
        kFallbackRouteDistanceKm,
      );
    });
  });

  group('FareBreakdown.fromBooking', () {
    test('calculates economy fare without options', () {
      final booking = Booking(
        fromAddress: 'Откуда',
        toAddress: 'Куда',
        selectedTariff: Tariffs.byId('economy'),
        routeDistanceKm: 10,
      );

      final fare = FareBreakdown.fromBooking(booking);

      expect(fare.base, 111); // 37 * 3
      expect(fare.distance, 370); // 37 * 10
      expect(fare.options, 0);
      expect(fare.discount, 0);
      expect(fare.total, 481);
      expect(fare.distanceKm, 10);
    });

    test('adds kids, pets, stops and promo discount', () {
      final booking = Booking(
        fromAddress: 'Откуда',
        toAddress: 'Куда',
        selectedTariff: Tariffs.byId('economy'),
        routeDistanceKm: 10,
        withKids: true,
        withPets: true,
        airConditioning: true,
        stops: const ['Stop A'],
      );

      final fare = FareBreakdown.fromBooking(booking, discountPercent: 10);

      expect(fare.options, greaterThan(200)); // stop fee + 80 + 100 + 50
      expect(fare.discountPercent, 10);
      expect(fare.discount, greaterThan(0));
      expect(fare.total, lessThan(fare.base + fare.distance + fare.options));
    });
  });
}
