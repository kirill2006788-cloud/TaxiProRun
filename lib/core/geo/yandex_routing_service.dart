import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../features/map/map_geo.dart';
import '../api/api_client.dart';
import '../api/api_config.dart';
import 'geo_config.dart';
import 'geo_math.dart';

/// Результат маршрута Яндекса (Route Details / Distance Matrix).
class YandexRouteResult {
  const YandexRouteResult({
    required this.distanceKm,
    required this.durationSec,
    this.points = const [],
    this.source = 'fallback',
  });

  final double distanceKm;
  final int durationSec;
  final List<MapPoint> points;
  final String source; // route | osrm | matrix | fallback

  int get distanceMeters => (distanceKm * 1000).round();
}

/// HTTP-клиент Yandex Router + Distance Matrix.
///
/// Ключи: `YANDEX_ROUTE_DETAILS_KEY` / `YANDEX_DISTANCE_MATRIX_KEY`
/// (часто один и тот же ключ Routing в кабинете → `YANDEX_ROUTING_KEY`).
class YandexRoutingService {
  YandexRoutingService({http.Client? httpClient})
      : _http = httpClient ?? http.Client(),
        _ownsHttp = httpClient == null;

  final http.Client _http;
  final bool _ownsHttp;

  void dispose() {
    if (_ownsHttp) _http.close();
  }

  /// Считает A→B: сначала Route Details (линия + км + ETA), иначе Matrix, иначе haversine.
  Future<YandexRouteResult> resolveRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    if (GeoConfig.hasRouteDetailsKey) {
      try {
        final route = await fetchRouteDetails(
          fromLat: fromLat,
          fromLng: fromLng,
          toLat: toLat,
          toLng: toLng,
        );
        if (route != null) return route;
      } catch (e, st) {
        debugPrint('Yandex Route Details failed: $e\n$st');
      }
    }

    try {
      final road = await fetchOsrmRoute(
        fromLat: fromLat,
        fromLng: fromLng,
        toLat: toLat,
        toLng: toLng,
      );
      if (road != null) return road;
    } catch (e, st) {
      debugPrint('OSRM route failed: $e\n$st');
    }

    if (GeoConfig.hasDistanceMatrixKey) {
      try {
        final matrix = await fetchDistanceMatrix(
          fromLat: fromLat,
          fromLng: fromLng,
          toLat: toLat,
          toLng: toLng,
        );
        if (matrix != null) return matrix;
      } catch (e, st) {
        debugPrint('Yandex Distance Matrix failed: $e\n$st');
      }
    }

    final km = roadDistanceKm(fromLat, fromLng, toLat, toLng).clamp(1.0, 500.0);
    final sec = (km / 28 * 3600).round().clamp(60, 86400);
    return YandexRouteResult(
      distanceKm: km,
      durationSec: sec,
      points: buildRoutePoints(
        fromLat: fromLat,
        fromLng: fromLng,
        toLat: toLat,
        toLng: toLng,
      ),
      source: 'fallback',
    );
  }

  Future<YandexRouteResult?> fetchRouteDetails({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    final key = GeoConfig.routeDetailsApiKey;
    if (key.isEmpty) return null;

    final uri = Uri.https('api.routing.yandex.net', '/v2/route', {
      'apikey': key,
      'waypoints': '$fromLat,$fromLng|$toLat,$toLng',
      'mode': 'driving',
    });

    final res = await _http.get(uri).timeout(ApiConfig.connectTimeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(
        'Yandex Route Details недоступен',
        statusCode: res.statusCode,
        body: res.body,
      );
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map) return null;
    final routes = decoded['routes'];
    if (routes is! List || routes.isEmpty) return null;
    final first = routes.first;
    if (first is! Map) return null;

    var meters = _toDouble(first['distanceMeters']) ??
        _toDouble(first['distance']) ??
        _sumLegsMeters(first);
    var seconds = _toInt(first['durationSeconds']) ??
        _toInt(first['duration']) ??
        _sumLegsSeconds(first);

    // Иногда метры/секунды только в legs.
    meters ??= _sumLegsMeters(first);
    seconds ??= _sumLegsSeconds(first);

    final points = _parseGeometry(first);
    if (meters == null || meters <= 0) return null;

    return YandexRouteResult(
      distanceKm: (meters / 1000).clamp(0.1, 500.0),
      durationSec:
          (seconds ?? (meters / 1000 / 28 * 3600).round()).clamp(60, 86400),
      points: points.isNotEmpty
          ? points
          : buildRoutePoints(
              fromLat: fromLat,
              fromLng: fromLng,
              toLat: toLat,
              toLng: toLng,
            ),
      source: 'route',
    );
  }

  Future<YandexRouteResult?> fetchOsrmRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    final uri = Uri.https(
      'router.project-osrm.org',
      '/route/v1/driving/$fromLng,$fromLat;$toLng,$toLat',
      {
        'overview': 'full',
        'geometries': 'geojson',
        'alternatives': 'false',
        'steps': 'false',
      },
    );

    final res = await _http.get(uri).timeout(ApiConfig.connectTimeout);
    if (res.statusCode < 200 || res.statusCode >= 300) return null;

    final decoded = jsonDecode(res.body);
    if (decoded is! Map) return null;
    if (decoded['code']?.toString().toLowerCase() != 'ok') return null;
    final routes = decoded['routes'];
    if (routes is! List || routes.isEmpty) return null;
    final first = routes.first;
    if (first is! Map) return null;

    final meters = _toDouble(first['distance']);
    if (meters == null || meters <= 0) return null;
    final seconds = _toInt(first['duration']);
    final points = <MapPoint>[];
    final geometry = first['geometry'];
    final coords = geometry is Map ? geometry['coordinates'] : null;
    if (coords is List) {
      for (final c in coords) {
        if (c is List && c.length >= 2) {
          final lng = _toDouble(c[0]);
          final lat = _toDouble(c[1]);
          if (lat != null && lng != null) points.add(mapPoint(lat, lng));
        }
      }
    }

    return YandexRouteResult(
      distanceKm: (meters / 1000).clamp(0.1, 500.0),
      durationSec:
          (seconds ?? (meters / 1000 / 28 * 3600).round()).clamp(60, 86400),
      points: points.length >= 2
          ? points
          : buildRoutePoints(
              fromLat: fromLat,
              fromLng: fromLng,
              toLat: toLat,
              toLng: toLng,
            ),
      source: 'osrm',
    );
  }

  Future<YandexRouteResult?> fetchDistanceMatrix({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    final key = GeoConfig.distanceMatrixApiKey;
    if (key.isEmpty) return null;

    final uri = Uri.https('api.routing.yandex.net', '/v2/distancematrix', {
      'apikey': key,
      'origins': '$fromLat,$fromLng',
      'destinations': '$toLat,$toLng',
      'mode': 'driving',
    });

    final res = await _http.get(uri).timeout(ApiConfig.connectTimeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(
        'Yandex Distance Matrix недоступен',
        statusCode: res.statusCode,
        body: res.body,
      );
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map) return null;
    final rows = decoded['rows'];
    if (rows is! List || rows.isEmpty) return null;
    final row0 = rows.first;
    if (row0 is! Map) return null;
    final elements = row0['elements'];
    if (elements is! List || elements.isEmpty) return null;
    final el = elements.first;
    if (el is! Map) return null;

    final status = el['status']?.toString().toLowerCase();
    if (status != null && status.isNotEmpty && status != 'ok') return null;

    final dist = el['distance'];
    final dur = el['duration'];
    final meters = dist is Map
        ? _toDouble(dist['value'])
        : _toDouble(dist) ?? _toDouble(el['distance_meters']);
    final seconds = dur is Map
        ? _toInt(dur['value'])
        : _toInt(dur) ?? _toInt(el['duration_seconds']);

    if (meters == null || meters <= 0) return null;

    return YandexRouteResult(
      distanceKm: (meters / 1000).clamp(0.1, 500.0),
      durationSec:
          (seconds ?? (meters / 1000 / 28 * 3600).round()).clamp(60, 86400),
      points: buildRoutePoints(
        fromLat: fromLat,
        fromLng: fromLng,
        toLat: toLat,
        toLng: toLng,
      ),
      source: 'matrix',
    );
  }

  double? _sumLegsMeters(Map route) {
    final legs = route['legs'];
    if (legs is! List) return null;
    var sum = 0.0;
    for (final leg in legs) {
      if (leg is! Map) continue;
      final d = _toDouble(leg['length']?['value']) ??
          _toDouble(leg['distance']?['value']) ??
          _toDouble(leg['distanceMeters']) ??
          _toDouble(leg['length']);
      if (d != null) sum += d;
    }
    return sum > 0 ? sum : null;
  }

  int? _sumLegsSeconds(Map route) {
    final legs = route['legs'];
    if (legs is! List) return null;
    var sum = 0;
    for (final leg in legs) {
      if (leg is! Map) continue;
      final d = _toInt(leg['duration']?['value']) ??
          _toInt(leg['durationSeconds']) ??
          _toInt(leg['time']);
      if (d != null) sum += d;
    }
    return sum > 0 ? sum : null;
  }

  List<MapPoint> _parseGeometry(Map route) {
    final points = <MapPoint>[];

    void addLatLng(dynamic lat, dynamic lng) {
      final a = _toDouble(lat);
      final b = _toDouble(lng);
      if (a != null && b != null) points.add(mapPoint(a, b));
    }

    final geometry = route['geometry'];
    if (geometry is Map) {
      final coords = geometry['coordinates'];
      if (coords is List) {
        for (final c in coords) {
          if (c is List && c.length >= 2) {
            // GeoJSON: [lon, lat]
            addLatLng(c[1], c[0]);
          }
        }
      }
    }

    if (points.isEmpty) {
      final legs = route['legs'];
      if (legs is List) {
        for (final leg in legs) {
          if (leg is! Map) continue;
          final steps = leg['steps'];
          if (steps is! List) continue;
          for (final step in steps) {
            if (step is! Map) continue;
            final polyline = step['polyline'] ?? step['geometry'];
            if (polyline is Map) {
              final coords = polyline['points'] ?? polyline['coordinates'];
              if (coords is List) {
                for (final c in coords) {
                  if (c is List && c.length >= 2) {
                    addLatLng(c[1], c[0]);
                  } else if (c is Map) {
                    addLatLng(c['lat'] ?? c['latitude'], c['lon'] ?? c['lng']);
                  }
                }
              }
            }
          }
        }
      }
    }

    return points;
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v.toString());
  }
}
