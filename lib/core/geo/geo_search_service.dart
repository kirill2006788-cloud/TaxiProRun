import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../api/api_client.dart';
import '../api/api_config.dart';
import '../api/models/api_models.dart';
import 'geo_config.dart';
import 'geo_math.dart';
import 'moscow_sample_addresses.dart';

/// Слой подсказок адресов и геокодирования.
///
/// Порядок:
/// 1. Сервер `GET/POST /api/geo/suggest` и `/api/geocode/suggest` (404 → дальше)
/// 2. Yandex Suggest (+ Geocoder при необходимости), если задан [GeoConfig.yandexGeocoderKey]
/// 3. Локальные примеры только в явном debug/mock-режиме
class GeoSearchService {
  GeoSearchService({
    ApiClient? apiClient,
    http.Client? httpClient,
    ApiConfigStore? configStore,
  })  : _api = apiClient ?? ApiClient(configStore: configStore),
        _http = httpClient ?? http.Client(),
        _config = configStore ?? ApiConfigStore.instance,
        _ownsHttp = httpClient == null;

  final ApiClient _api;
  final http.Client _http;
  final ApiConfigStore _config;
  final bool _ownsHttp;
  double? _centerLat;
  double? _centerLng;

  void setSearchCenter({required double lat, required double lng}) {
    _centerLat = lat;
    _centerLng = lng;
  }

  /// Поиск подсказок по строке запроса.
  Future<List<AddressSuggestionDto>> suggest(String query) async {
    final q = query.trim();
    if (q.length < GeoConfig.minQueryLength) return [];

    if (GeoConfig.hasYandexGeosuggestKey) {
      try {
        final yandex = await _suggestFromYandex(q);
        final ranked = _rankByDistance(_deduplicate(yandex));
        if (ranked.isNotEmpty) return _limit(ranked);
      } catch (e, st) {
        debugPrint('GeoSearchService Yandex suggest failed: $e\n$st');
      }
    }

    if (!_config.useMockApi) {
      try {
        final server = await _suggestFromServer(q).timeout(
          const Duration(seconds: 4),
          onTimeout: () => <AddressSuggestionDto>[],
        );
        final ranked = _rankByDistance(_deduplicate(server));
        if (ranked.isNotEmpty) return _limit(ranked);
      } catch (e, st) {
        debugPrint('GeoSearchService server suggest failed: $e\n$st');
      }
    }

    if (GeoConfig.hasYandexGeocoderKey) {
      try {
        final fromGeocoder = await _geocodeYandex(q);
        if (fromGeocoder != null) return _rankByDistance([fromGeocoder]);
      } catch (e, st) {
        debugPrint(
            'GeoSearchService Yandex suggest geocode fallback failed: $e\n$st');
      }
    }

    if (kDebugMode && _config.useMockApi) {
      return _limit(_rankByDistance(_suggestFromMock(q)));
    }
    return [];
  }

  /// Геокодирование одной строки (сервер → Yandex → mock match).
  Future<AddressSuggestionDto?> geocode(String query) async {
    final q = query.trim();
    if (q.isEmpty) return null;

    if (GeoConfig.hasYandexGeocoderKey) {
      try {
        final item = await _geocodeYandex(q);
        if (item != null) return item;
      } catch (e, st) {
        debugPrint('GeoSearchService Yandex geocode failed: $e\n$st');
      }
    }

    if (!_config.useMockApi) {
      try {
        final fromServer = await _suggestFromServer(q).timeout(
          const Duration(seconds: 4),
          onTimeout: () => <AddressSuggestionDto>[],
        );
        for (final item in fromServer) {
          if (item.hasCoordinates) return item;
        }
      } catch (e, st) {
        debugPrint('GeoSearchService server geocode failed: $e\n$st');
      }
    }

    if (kDebugMode && _config.useMockApi) {
      final mock = _suggestFromMock(q);
      return mock.isEmpty ? null : mock.first;
    }
    return null;
  }

  Future<List<AddressSuggestionDto>> _suggestFromServer(String query) async {
    final body = {'q': query, 'query': query, 'text': query};
    final queryParams = {
      'q': query,
      'query': query,
      'text': query,
    };

    for (final path in [ApiEndpoints.geoSuggest, ApiEndpoints.geocodeSuggest]) {
      for (final usePost in [false, true]) {
        try {
          final res = usePost
              ? await _api.post(path, body: body)
              : await _api.get(path, query: queryParams);
          if (res.statusCode == 404 || res.statusCode == 405) continue;
          if (res.statusCode < 200 || res.statusCode >= 300) continue;
          final parsed = _parseSuggestionPayload(res.body);
          if (parsed.isNotEmpty) return parsed;
        } catch (e) {
          debugPrint('GeoSearchService server $path failed: $e');
        }
      }
    }
    return [];
  }

  Future<List<AddressSuggestionDto>> _suggestFromYandex(String query) async {
    final center = _searchCenterLl;
    final uri = Uri.https('suggest-maps.yandex.ru', '/v1/suggest', {
      'apikey': GeoConfig.suggestApiKey,
      'text': query,
      'lang': 'ru',
      'results': '${GeoConfig.maxResults}',
      'highlight': '0',
      'print_address': '1',
      'org_address_kind': 'house',
      'attrs': 'uri',
      'countries': 'ru',
      'strict_bounds': '1',
      'types': 'biz,geo,street,house,locality,metro,district',
      'll': center,
      'ull': center,
      'spn': _searchSpan,
    });

    final res = await _http.get(uri).timeout(ApiConfig.connectTimeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(
        'Yandex Suggest недоступен',
        statusCode: res.statusCode,
        body: res.body,
      );
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map) return [];
    final results = decoded['results'];
    if (results is! List) return [];

    final parsed = await Future.wait(
      results.whereType<Map>().map(
            (raw) => _parseYandexSuggestion(raw.cast<String, dynamic>()),
          ),
    );
    return parsed.whereType<AddressSuggestionDto>().toList(growable: false);
  }

  Future<AddressSuggestionDto?> _parseYandexSuggestion(
    Map<String, dynamic> map,
  ) async {
    final title = _yandexText(map['title']) ??
        map['address']?.toString() ??
        map['text']?.toString() ??
        '';
    if (title.isEmpty) return null;
    final subtitle =
        _yandexText(map['subtitle']) ?? _yandexText(map['description']) ?? '';
    var lat = _toDouble(map['lat'] ?? map['latitude']);
    var lng = _toDouble(map['lng'] ?? map['longitude'] ?? map['lon']);

    final pos = map['position'] ?? map['pos'];
    if ((lat == null || lng == null) && pos is Map) {
      lat ??= _toDouble(pos['lat'] ?? pos['latitude']);
      lng ??= _toDouble(pos['lon'] ?? pos['lng'] ?? pos['longitude']);
    }
    if ((lat == null || lng == null) && pos is String) {
      final parts = pos.split(',');
      if (parts.length >= 2) {
        // Suggest часто отдаёт "lon,lat"
        lng ??= double.tryParse(parts[0].trim());
        lat ??= double.tryParse(parts[1].trim());
      }
    }

    if (lat == null || lng == null) {
      final uriTag = map['uri']?.toString() ??
          (map['attrs'] is Map
              ? (map['attrs'] as Map)['uri']?.toString()
              : null);
      if (uriTag != null && uriTag.isNotEmpty) {
        final geo = await _geocodeYandex(title, uri: uriTag);
        lat ??= geo?.lat;
        lng ??= geo?.lng;
      }
    }

    final subtitleText = subtitle.isEmpty
        ? (map['tags'] is List &&
                (map['tags'] as List).any((t) => t.toString().contains('biz'))
            ? 'Организация'
            : 'Россия')
        : subtitle;

    return AddressSuggestionDto(
      title: title,
      subtitle: subtitleText,
      lat: lat,
      lng: lng,
    );
  }

  Future<AddressSuggestionDto?> _geocodeYandex(
    String query, {
    String? uri,
  }) async {
    final coordinateQuery =
        RegExp(r'^\s*-?\d+(?:\.\d+)?\s*,\s*-?\d+(?:\.\d+)?\s*$')
            .hasMatch(query);
    final params = <String, String>{
      'apikey': GeoConfig.yandexGeocoderKey,
      'format': 'json',
      'lang': 'ru_RU',
      'results': '1',
      'geocode': uri?.isNotEmpty == true ? uri! : query,
      if (!coordinateQuery) 'll': _searchCenterLl,
      if (!coordinateQuery) 'spn': _searchSpan,
      if (!coordinateQuery) 'rspn': '1',
    };

    final requestUri = Uri.https('geocode-maps.yandex.ru', '/1.x/', params);
    final res = await _http.get(requestUri).timeout(ApiConfig.connectTimeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(
        'Yandex Geocoder недоступен',
        statusCode: res.statusCode,
        body: res.body,
      );
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map) return null;
    final response = decoded['response'];
    if (response is! Map) return null;
    final collection = response['GeoObjectCollection'];
    if (collection is! Map) return null;
    final members = collection['featureMember'];
    if (members is! List || members.isEmpty) return null;
    final first = members.first;
    if (first is! Map) return null;
    final geoObject = first['GeoObject'];
    if (geoObject is! Map) return null;

    final name = geoObject['name']?.toString() ?? query;
    final description = geoObject['description']?.toString() ?? '';
    final point = geoObject['Point'];
    double? lat;
    double? lng;
    if (point is Map) {
      final pos = point['pos']?.toString() ?? '';
      final parts = pos.split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        lng = double.tryParse(parts[0]);
        lat = double.tryParse(parts[1]);
      }
    }

    return AddressSuggestionDto(
      title: name,
      subtitle: description.isEmpty ? 'Россия' : description,
      lat: lat,
      lng: lng,
    );
  }

  List<AddressSuggestionDto> _suggestFromMock(String query) {
    final lower = query.toLowerCase();
    final tokens =
        lower.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

    final scored = <(int, AddressSuggestionDto)>[];
    for (final item in moscowSampleAddresses) {
      final hay = '${item.title} ${item.subtitle}'.toLowerCase();
      if (!tokens.every((t) => hay.contains(t))) continue;
      var score = 0;
      if (item.title.toLowerCase().startsWith(lower)) score += 20;
      if (hay.contains(lower)) score += 10;
      score += tokens.fold<int>(0, (s, t) => s + (hay.contains(t) ? 2 : 0));
      scored.add((score, item));
    }
    scored.sort((a, b) => b.$1.compareTo(a.$1));
    return scored.map((e) => e.$2).toList();
  }

  List<AddressSuggestionDto> _parseSuggestionPayload(String body) {
    final decoded = jsonDecode(body);
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((e) => AddressSuggestionDto.fromJson(e.cast<String, dynamic>()))
          .where((e) => e.title.isNotEmpty)
          .toList();
    }
    if (decoded is! Map) return [];
    final map = decoded.cast<String, dynamic>();
    final items =
        map['items'] ?? map['suggestions'] ?? map['results'] ?? map['data'];
    if (items is! List) return [];
    return items
        .whereType<Map>()
        .map((e) => AddressSuggestionDto.fromJson(e.cast<String, dynamic>()))
        .where((e) => e.title.isNotEmpty)
        .toList();
  }

  String? _yandexText(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.trim().isEmpty ? null : value.trim();
    if (value is Map) {
      final text = value['text']?.toString() ?? value['value']?.toString();
      if (text != null && text.trim().isNotEmpty) return text.trim();
    }
    return null;
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.replaceAll(',', '.'));
    return null;
  }

  List<AddressSuggestionDto> _limit(List<AddressSuggestionDto> items) {
    if (items.length <= GeoConfig.maxResults) return items;
    return items.take(GeoConfig.maxResults).toList();
  }

  List<AddressSuggestionDto> _rankByDistance(List<AddressSuggestionDto> items) {
    final lat = _centerLat;
    final lng = _centerLng;
    if (lat == null || lng == null) {
      return items.where(_isInsideRussia).toList(growable: false);
    }

    final ranked = items.map((item) {
      final d = item.hasCoordinates
          ? haversineKm(lat, lng, item.lat!, item.lng!)
          : double.infinity;
      return (d, item);
    }).toList()
      ..sort((a, b) => a.$1.compareTo(b.$1));

    return ranked.where((entry) {
      if (!_isInsideRussia(entry.$2)) return false;
      return !entry.$1.isFinite || entry.$1 <= 80;
    }).map((entry) {
      final d = entry.$1;
      final item = entry.$2;
      if (!d.isFinite) return item;
      final distance = d < 1
          ? '${(d * 1000).round()} м'
          : '${d.toStringAsFixed(d < 10 ? 1 : 0)} км';
      final subtitle = item.subtitle.trim();
      return AddressSuggestionDto(
        title: item.title,
        subtitle: subtitle.isEmpty ? distance : '$distance · $subtitle',
        lat: item.lat,
        lng: item.lng,
      );
    }).toList();
  }

  String get _searchCenterLl {
    final lat = _centerLat;
    final lng = _centerLng;
    if (lat == null || lng == null) return GeoConfig.moscowLl;
    return '${lng.toStringAsFixed(6)},${lat.toStringAsFixed(6)}';
  }

  String get _searchSpan =>
      _centerLat == null ? GeoConfig.moscowSpn : '0.80,0.55';

  bool _isInsideRussia(AddressSuggestionDto item) {
    if (!item.hasCoordinates) return true;
    final lat = item.lat!;
    final lng = item.lng!;
    return lat >= 41 && lat <= 82 && lng >= 19 && lng <= 180;
  }

  List<AddressSuggestionDto> _deduplicate(
    Iterable<AddressSuggestionDto> items,
  ) {
    final result = <AddressSuggestionDto>[];
    final seen = <String>{};
    for (final item in items) {
      final key = [
        item.title.trim().toLowerCase(),
        item.lat?.toStringAsFixed(5) ?? '',
        item.lng?.toStringAsFixed(5) ?? '',
      ].join('|');
      if (seen.add(key)) result.add(item);
    }
    return result;
  }

  void dispose() {
    if (_ownsHttp) _http.close();
  }
}
