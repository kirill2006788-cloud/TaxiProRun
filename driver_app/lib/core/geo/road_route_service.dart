import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../features/map/map_geo.dart';

/// The same route strategy as the passenger app: detailed road geometry first,
/// then the public road router, then a shaped local fallback.
class RoadRouteService {
  RoadRouteService({http.Client? client})
      : _client = client ?? http.Client(),
        _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;

  static const _routingKey = String.fromEnvironment('YANDEX_ROUTING_KEY');

  void dispose() {
    if (_ownsClient) _client.close();
  }

  Future<List<MapPoint>> resolve({
    required MapPoint from,
    required MapPoint to,
  }) async {
    if (_routingKey.isNotEmpty) {
      final yandex = await _fetchYandex(from: from, to: to);
      if (yandex != null && yandex.length >= 2) return yandex;
    }

    final osrm = await _fetchOsrm(from: from, to: to);
    if (osrm != null && osrm.length >= 2) return osrm;

    return _fallback(from: from, to: to);
  }

  Future<List<MapPoint>?> _fetchYandex({
    required MapPoint from,
    required MapPoint to,
  }) async {
    try {
      final uri = Uri.https('api.routing.yandex.net', '/v2/route', {
        'apikey': _routingKey,
        'waypoints': '${from.lat},${from.lng}|${to.lat},${to.lng}',
        'mode': 'driving',
      });
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      final routes = decoded['routes'];
      if (routes is! List || routes.isEmpty || routes.first is! Map) {
        return null;
      }
      return _geometry(routes.first as Map);
    } catch (_) {
      return null;
    }
  }

  Future<List<MapPoint>?> _fetchOsrm({
    required MapPoint from,
    required MapPoint to,
  }) async {
    try {
      final uri = Uri.https(
        'router.project-osrm.org',
        '/route/v1/driving/${from.lng},${from.lat};${to.lng},${to.lat}',
        {
          'overview': 'full',
          'geometries': 'geojson',
          'alternatives': 'false',
          'steps': 'false',
        },
      );
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['code']?.toString().toLowerCase() != 'ok') {
        return null;
      }
      final routes = decoded['routes'];
      if (routes is! List || routes.isEmpty || routes.first is! Map) {
        return null;
      }
      return _geometry(routes.first as Map);
    } catch (_) {
      return null;
    }
  }

  List<MapPoint> _geometry(Map route) {
    final points = <MapPoint>[];
    final geometry = route['geometry'];
    final coordinates = geometry is Map ? geometry['coordinates'] : null;
    if (coordinates is! List) return points;
    for (final coordinate in coordinates) {
      if (coordinate is! List || coordinate.length < 2) continue;
      final lng = _number(coordinate[0]);
      final lat = _number(coordinate[1]);
      if (lat != null && lng != null) points.add(mapPoint(lat, lng));
    }
    return points;
  }

  List<MapPoint> _fallback({required MapPoint from, required MapPoint to}) {
    final midLat = (from.lat + to.lat) / 2;
    final midLng = (from.lng + to.lng) / 2;
    final dx = to.lng - from.lng;
    final dy = to.lat - from.lat;
    final bendLat = midLat + dx * 0.08;
    final bendLng = midLng - dy * 0.08;
    return [
      from,
      mapPoint((from.lat + bendLat) / 2, (from.lng + bendLng) / 2),
      mapPoint(bendLat, bendLng),
      mapPoint((bendLat + to.lat) / 2, (bendLng + to.lng) / 2),
      to,
    ];
  }

  double? _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}
