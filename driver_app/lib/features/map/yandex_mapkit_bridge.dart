import 'package:flutter/material.dart';
import 'package:yandex_maps_mapkit/mapkit.dart';
import 'package:yandex_maps_mapkit/mapkit_factory.dart' as mapkit_factory;
import 'package:yandex_maps_mapkit/yandex_map.dart';

import '../../core/config/map_config.dart';
import 'map_geo.dart';
import 'premium_nav_map_canvas.dart';

/// Live [YandexMap] for the driver app; soft-falls back to [PremiumNavMapCanvas].
class YandexMapKitBridge extends StatefulWidget {
  const YandexMapKitBridge({
    super.key,
    this.routePoints = const [],
    this.driverLat,
    this.driverLng,
    this.recenterToken = 0,
    this.progress,
    this.demoCruise = false,
    this.showSetupHint = true,
    this.nightMode = true,
  });

  final List<MapPoint> routePoints;
  final double? driverLat;
  final double? driverLng;
  final int recenterToken;
  final double? progress;
  final bool demoCruise;
  final bool showSetupHint;
  final bool nightMode;

  @override
  State<YandexMapKitBridge> createState() => _YandexMapKitBridgeState();
}

class _YandexMapKitBridgeState extends State<YandexMapKitBridge>
    with WidgetsBindingObserver {
  bool _useFallback = false;
  MapWindow? _mapWindow;
  String? _drawnSignature;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    try {
      if (state == AppLifecycleState.resumed) {
        mapkit_factory.mapkit.onStart();
      } else if (state == AppLifecycleState.paused) {
        mapkit_factory.mapkit.onStop();
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant YandexMapKitBridge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_useFallback && _mapWindow != null) {
      if (oldWidget.nightMode != widget.nightMode) {
        try {
          _mapWindow!.map.nightModeEnabled = widget.nightMode;
        } catch (_) {}
      }
      if (oldWidget.recenterToken != widget.recenterToken) {
        _moveCamera(_mapWindow!, focusDriver: true);
      }
      _syncMapObjects(_mapWindow!);
    }
  }

  void _onMapCreated(MapWindow mapWindow) {
    try {
      _mapWindow = mapWindow;
      mapkit_factory.mapkit.onStart();
      mapWindow.map.nightModeEnabled = widget.nightMode;
      _moveCamera(mapWindow);
      _syncMapObjects(mapWindow);
    } catch (_) {
      if (mounted) {
        setState(() => _useFallback = true);
      }
    }
  }

  void _moveCamera(MapWindow mapWindow, {bool focusDriver = false}) {
    final points = widget.routePoints;
    final driverLat = widget.driverLat;
    final driverLng = widget.driverLng;
    final lat = focusDriver && driverLat != null
        ? driverLat
        : points.isNotEmpty
            ? points.map((p) => p.lat).reduce((a, b) => a + b) / points.length
            : MapConfig.defaultLatitude;
    final lng = focusDriver && driverLng != null
        ? driverLng
        : points.isNotEmpty
            ? points.map((p) => p.lng).reduce((a, b) => a + b) / points.length
            : MapConfig.defaultLongitude;
    final zoom = focusDriver
        ? 15.0
        : points.length >= 2
            ? 12.0
            : MapConfig.defaultZoom;

    mapWindow.map.move(
      CameraPosition(
        Point(latitude: lat, longitude: lng),
        zoom: zoom,
        azimuth: 0,
        tilt: 0,
      ),
    );
  }

  String _signature() {
    final buf = StringBuffer();
    for (final p in widget.routePoints) {
      buf.write('${p.lat},${p.lng};');
    }
    buf.write('|${widget.progress}|${widget.driverLat},${widget.driverLng}');
    return buf.toString();
  }

  void _syncMapObjects(MapWindow mapWindow) {
    final signature = _signature();
    if (signature == _drawnSignature) return;
    _drawnSignature = signature;

    final objects = mapWindow.map.mapObjects;
    objects.clear();

    final route = widget.routePoints;
    if (route.length >= 2) {
      final geometry = Polyline(
        route
            .map((p) => Point(latitude: p.lat, longitude: p.lng))
            .toList(growable: false),
      );
      final line = objects.addPolylineWithGeometry(geometry);
      line.style = const LineStyle(
        strokeWidth: 4.4,
        outlineWidth: 2.0,
        outlineColor: Color(0xFF1A1A1E),
      );
      line.setStrokeColor(const Color(0xFFE8B84A));
    }

    if (route.isNotEmpty) {
      objects.addPlacemarkWithPoint(
        Point(latitude: route.first.lat, longitude: route.first.lng),
      );
      if (route.length >= 2) {
        objects.addPlacemarkWithPoint(
          Point(latitude: route.last.lat, longitude: route.last.lng),
        );
      }
    }

    if (widget.driverLat != null && widget.driverLng != null) {
      objects.addPlacemarkWithPoint(
        Point(latitude: widget.driverLat!, longitude: widget.driverLng!),
      );
    }

    // Optional progress pin along the route (approx by index).
    final progress = widget.progress;
    if (progress != null && route.length >= 2) {
      final t = progress.clamp(0.0, 1.0);
      final idx = (t * (route.length - 1)).floor().clamp(0, route.length - 2);
      final localT = (t * (route.length - 1)) - idx;
      final a = route[idx];
      final b = route[idx + 1];
      final lat = a.lat + (b.lat - a.lat) * localT;
      final lng = a.lng + (b.lng - a.lng) * localT;
      objects.addPlacemarkWithPoint(Point(latitude: lat, longitude: lng));
    }
  }

  Widget _fallbackCanvas() {
    return PremiumNavMapCanvas(
      routePoints: widget.routePoints,
      progress: widget.progress,
      demoCruise: widget.demoCruise,
      showSetupHint: widget.showSetupHint,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_useFallback) {
      return _fallbackCanvas();
    }

    try {
      return YandexMap(onMapCreated: _onMapCreated);
    } catch (_) {
      _useFallback = true;
      return _fallbackCanvas();
    }
  }
}
