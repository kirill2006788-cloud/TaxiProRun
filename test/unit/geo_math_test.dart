import 'package:flutter_test/flutter_test.dart';
import 'package:koroli_dorog/core/geo/geo_math.dart';

void main() {
  group('haversineKm', () {
    test('returns zero for identical points', () {
      expect(haversineKm(55.75, 37.62, 55.75, 37.62), 0);
    });

    test('Moscow center to Sheremetyevo is roughly 27 km', () {
      final km = haversineKm(55.7558, 37.6173, 55.9736, 37.4144);
      expect(km, inInclusiveRange(25, 30));
    });
  });

  group('roadDistanceKm', () {
    test('applies city road factor 1.35', () {
      final straight = haversineKm(55.7558, 37.6173, 55.9736, 37.4144);
      final road = roadDistanceKm(55.7558, 37.6173, 55.9736, 37.4144);
      expect(road, closeTo(straight * 1.35, 0.01));
    });
  });

  group('buildRoutePoints', () {
    test('returns polyline with five points', () {
      final points = buildRoutePoints(
        fromLat: 55.75,
        fromLng: 37.62,
        toLat: 55.97,
        toLng: 37.41,
      );
      expect(points, hasLength(5));
      expect(points.first.lat, 55.75);
      expect(points.last.lat, 55.97);
    });
  });
}
