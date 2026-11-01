import 'dart:math' as math;

import '../../features/map/map_geo.dart';

/// Haversine distance in km (great-circle).
double haversineKm(double lat1, double lng1, double lat2, double lng2) {
  const r = 6371.0;
  final dLat = _rad(lat2 - lat1);
  final dLng = _rad(lng2 - lng1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) *
          math.cos(_rad(lat2)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return r * c;
}

/// Road distance ≈ straight-line × city factor (no routing key).
double roadDistanceKm(double lat1, double lng1, double lat2, double lng2) {
  return haversineKm(lat1, lng1, lat2, lng2) * 1.35;
}

/// Fallback when coords unknown (legacy demo).
const double kFallbackRouteDistanceKm = 12.0;

/// Build a simple polyline A → midpoints → B for MapHost.
List<MapPoint> buildRoutePoints({
  required double fromLat,
  required double fromLng,
  required double toLat,
  required double toLng,
}) {
  final midLat = (fromLat + toLat) / 2;
  final midLng = (fromLng + toLng) / 2;
  // Slight curve so the line isn't a flat segment.
  final dx = toLng - fromLng;
  final dy = toLat - fromLat;
  final bendLat = midLat + dx * 0.08;
  final bendLng = midLng - dy * 0.08;
  return [
    mapPoint(fromLat, fromLng),
    mapPoint((fromLat + bendLat) / 2, (fromLng + bendLng) / 2),
    mapPoint(bendLat, bendLng),
    mapPoint((bendLat + toLat) / 2, (bendLng + toLng) / 2),
    mapPoint(toLat, toLng),
  ];
}

List<MapPoint> routePointsForBooking({
  double? fromLat,
  double? fromLng,
  double? toLat,
  double? toLng,
}) {
  if (fromLat == null ||
      fromLng == null ||
      toLat == null ||
      toLng == null) {
    return kDefaultMockRoute;
  }
  return buildRoutePoints(
    fromLat: fromLat,
    fromLng: fromLng,
    toLat: toLat,
    toLng: toLng,
  );
}

double _rad(double deg) => deg * math.pi / 180;
