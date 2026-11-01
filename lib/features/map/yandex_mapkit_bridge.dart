import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:yandex_maps_mapkit/mapkit.dart';
import 'package:yandex_maps_mapkit/mapkit_factory.dart' as mapkit_factory;
import 'package:yandex_maps_mapkit/ui_view.dart' as yandex_view;
import 'package:yandex_maps_mapkit/yandex_map.dart';

import '../../core/config/map_config.dart';
import 'map_camera_controller.dart';
import 'map_geo.dart';
import 'map_pin_mode.dart';
import 'map_vehicle_marker.dart';
import 'premium_map_canvas.dart';

typedef MapCameraIdleCallback = void Function(double lat, double lng);
typedef MapCameraMovingCallback = void Function();

/// Live [YandexMap] when MapKit is ready; soft-falls back to [PremiumMapCanvas].
class YandexMapKitBridge extends StatefulWidget {
  const YandexMapKitBridge({
    super.key,
    this.routePoints = const [],
    this.driverLat,
    this.driverLng,
    this.showDriverMarker = false,
    this.showUserPin = false,
    this.nearbyVehicles = const [],
    this.demoCruise = false,
    this.showSetupHint = true,
    this.pinMode = MapPinMode.none,
    this.onCameraMoving,
    this.onCameraIdle,
    this.cameraController,
    this.nightMode = true,
  });

  final List<MapPoint> routePoints;
  final double? driverLat;
  final double? driverLng;
  final bool showDriverMarker;
  final bool showUserPin;
  final List<MapPoint> nearbyVehicles;
  final bool demoCruise;
  final bool showSetupHint;
  final MapPinMode pinMode;
  final MapCameraMovingCallback? onCameraMoving;
  final MapCameraIdleCallback? onCameraIdle;
  final MapCameraController? cameraController;
  final bool nightMode;

  @override
  State<YandexMapKitBridge> createState() => _YandexMapKitBridgeState();
}

class _YandexMapKitBridgeState extends State<YandexMapKitBridge>
    with WidgetsBindingObserver {
  bool _useFallback = false;
  MapWindow? _mapWindow;
  String? _drawnStaticSignature;
  String? _fittedRouteSignature;
  _BridgeCameraListener? _cameraListener;
  PlacemarkMapObject? _driverPlacemark;
  MapPoint? _displayedDriverPoint;
  MapPoint? _lastDriverTarget;
  DateTime? _lastDriverTargetAt;
  Timer? _driverAnimationTimer;
  bool _ignoreNextIdle = false;
  bool _userMovedCamera = false;

  late final void Function(double lat, double lng, {double zoom}) _moveHandler =
      _handleControllerMove;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.cameraController?.attach(_moveHandler);
  }

  @override
  void dispose() {
    widget.cameraController?.detach(_moveHandler);
    WidgetsBinding.instance.removeObserver(this);
    _driverAnimationTimer?.cancel();
    _detachCameraListener();
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
    } catch (_) {
      // Soft-fail: lifecycle hooks must not crash the app.
    }
  }

  @override
  void didUpdateWidget(covariant YandexMapKitBridge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cameraController != widget.cameraController) {
      oldWidget.cameraController?.detach(_moveHandler);
      widget.cameraController?.attach(_moveHandler);
    }
    if (!_useFallback && _mapWindow != null) {
      try {
        _mapWindow!.map.nightModeEnabled = widget.nightMode;
      } catch (_) {}
      final routeSignature = _routeSignature();
      final routeChanged = routeSignature != _fittedRouteSignature;
      _syncMapObjects(_mapWindow!);
      if (routeChanged &&
          !_userMovedCamera &&
          widget.pinMode == MapPinMode.none) {
        _ignoreNextIdle = true;
        _moveCamera(_mapWindow!);
        _fittedRouteSignature = routeSignature;
      }
    }
  }

  void _handleControllerMove(double lat, double lng, {double zoom = 16}) {
    final window = _mapWindow;
    if (window == null) return;
    _userMovedCamera = false;
    _fittedRouteSignature = _routeSignature();
    _ignoreNextIdle = true;
    try {
      window.map.move(
        CameraPosition(
          Point(latitude: lat, longitude: lng),
          zoom: zoom,
          azimuth: 0,
          tilt: 0,
        ),
      );
    } catch (_) {}
  }

  void _detachCameraListener() {
    final window = _mapWindow;
    final listener = _cameraListener;
    if (window != null && listener != null) {
      try {
        window.map.removeCameraListener(listener);
      } catch (_) {}
    }
    _cameraListener = null;
  }

  void _onMapCreated(MapWindow mapWindow) {
    try {
      _mapWindow = mapWindow;
      mapkit_factory.mapkit.onStart();
      try {
        mapWindow.map.nightModeEnabled = widget.nightMode;
      } catch (_) {}
      _attachCameraListener(mapWindow);
      _ignoreNextIdle = true;
      _moveCamera(mapWindow);
      _fittedRouteSignature = _routeSignature();
      _syncMapObjects(mapWindow);
    } catch (_) {
      if (mounted) {
        setState(() => _useFallback = true);
      }
    }
  }

  void _attachCameraListener(MapWindow mapWindow) {
    _detachCameraListener();
    final listener = _BridgeCameraListener((position, reason, finished) {
      if (reason != CameraUpdateReason.Gestures) {
        if (finished) _ignoreNextIdle = false;
        return;
      }
      if (!finished) {
        _userMovedCamera = true;
        widget.onCameraMoving?.call();
        return;
      }
      if (_ignoreNextIdle) {
        _ignoreNextIdle = false;
        return;
      }
      final target = position.target;
      widget.onCameraIdle?.call(target.latitude, target.longitude);
    });
    _cameraListener = listener;
    mapWindow.map.addCameraListener(listener);
  }

  void _moveCamera(MapWindow mapWindow) {
    final points = widget.routePoints;
    final lat = points.isNotEmpty
        ? points.map((p) => p.lat).reduce((a, b) => a + b) / points.length
        : MapConfig.defaultLatitude;
    final lng = points.isNotEmpty
        ? points.map((p) => p.lng).reduce((a, b) => a + b) / points.length
        : MapConfig.defaultLongitude;
    final zoom =
        points.length >= 2 ? _zoomForPoints(points) : MapConfig.defaultZoom;

    mapWindow.map.move(
      CameraPosition(
        Point(latitude: lat, longitude: lng),
        zoom: zoom,
        azimuth: 0,
        tilt: 0,
      ),
    );
  }

  double _zoomForPoints(List<MapPoint> points) {
    if (points.length < 2) return MapConfig.defaultZoom;
    final lats = points.map((p) => p.lat);
    final lngs = points.map((p) => p.lng);
    final span = [
      lats.reduce((a, b) => a > b ? a : b) -
          lats.reduce((a, b) => a < b ? a : b),
      lngs.reduce((a, b) => a > b ? a : b) -
          lngs.reduce((a, b) => a < b ? a : b),
    ].reduce((a, b) => a > b ? a : b);
    if (span > 8) return 5.5;
    if (span > 4) return 6.3;
    if (span > 2) return 7.3;
    if (span > 1) return 8.4;
    if (span > 0.45) return 9.7;
    if (span > 0.18) return 10.9;
    if (span > 0.08) return 12.1;
    return 13.4;
  }

  String _staticSignature() {
    final buf = StringBuffer();
    for (final p in widget.routePoints) {
      buf.write('${p.lat},${p.lng};');
    }
    for (final p in widget.nearbyVehicles) {
      buf.write('v${p.lat},${p.lng};');
    }
    buf.write(
      '|${widget.showDriverMarker}|'
      '${widget.driverLat != null && widget.driverLng != null}|'
      '${widget.showUserPin}|${widget.pinMode}',
    );
    return buf.toString();
  }

  String _routeSignature() {
    final buf = StringBuffer('${widget.pinMode}|');
    for (final p in widget.routePoints) {
      buf.write('${p.lat.toStringAsFixed(6)},${p.lng.toStringAsFixed(6)};');
    }
    return buf.toString();
  }

  void _syncMapObjects(MapWindow mapWindow) {
    final signature = _staticSignature();
    if (signature != _drawnStaticSignature) {
      _drawnStaticSignature = signature;
      _rebuildStaticObjects(mapWindow);
    }
    _syncDriverPosition();
  }

  void _rebuildStaticObjects(MapWindow mapWindow) {
    final objects = mapWindow.map.mapObjects;
    objects.clear();
    _driverPlacemark = null;

    final route = widget.routePoints;
    final pinMode = widget.pinMode;

    if (route.length >= 2 && pinMode == MapPinMode.none) {
      final geometry = Polyline(
        route
            .map((p) => Point(latitude: p.lat, longitude: p.lng))
            .toList(growable: false),
      );
      final line = objects.addPolylineWithGeometry(geometry);
      line.style = const LineStyle(
        strokeWidth: 3.4,
        outlineWidth: 1.1,
        outlineColor: Color(0xFF1A1A1E),
      );
      line.setStrokeColor(const Color(0xFF16D469));
    }

    if (route.isNotEmpty) {
      if (pinMode == MapPinMode.pickup) {
        if (route.length >= 2) {
          objects.addPlacemarkWithPoint(
            Point(latitude: route.last.lat, longitude: route.last.lng),
          );
        }
      } else if (pinMode == MapPinMode.destination) {
        objects.addPlacemarkWithPoint(
          Point(latitude: route.first.lat, longitude: route.first.lng),
        );
      } else {
        if (!widget.showDriverMarker) {
          objects.addPlacemarkWithPoint(
            Point(latitude: route.first.lat, longitude: route.first.lng),
          );
        }
        if (route.length >= 2) {
          objects.addPlacemarkWithPoint(
            Point(latitude: route.last.lat, longitude: route.last.lng),
          );
        }
      }
    }

    final dLat = widget.driverLat;
    final dLng = widget.driverLng;
    if (widget.showDriverMarker && dLat != null && dLng != null) {
      final target = (lat: dLat, lng: dLng);
      final initial = _displayedDriverPoint ?? target;
      final placemark = objects.addPlacemarkWithView(
        Point(latitude: initial.lat, longitude: initial.lng),
        yandex_view.ViewProvider(
          id: 'active-driver',
          builder: () => const MapVehicleMarker(
            size: 42,
            isDriver: true,
          ),
        ),
      );
      placemark.opacity = 1;
      placemark.setIconStyle(
        const IconStyle(rotationType: RotationType.Rotate),
      );
      placemark.direction = _directionDegrees(initial);
      _driverPlacemark = placemark;
      _displayedDriverPoint = initial;
    }

    for (var i = 0; i < widget.nearbyVehicles.length; i++) {
      final vehicle = widget.nearbyVehicles[i];
      final placemark = objects.addPlacemarkWithView(
        Point(latitude: vehicle.lat, longitude: vehicle.lng),
        yandex_view.ViewProvider(
          id: 'nearby-car-$i-${vehicle.lat}-${vehicle.lng}',
          builder: () => MapVehicleMarker(
            angle: mapVehicleAngleForIndex(i),
            size: 38,
          ),
        ),
      );
      placemark.opacity = 0.98;
      placemark.direction = 0;
    }
  }

  void _syncDriverPosition() {
    final dLat = widget.driverLat;
    final dLng = widget.driverLng;
    final placemark = _driverPlacemark;
    if (!widget.showDriverMarker ||
        dLat == null ||
        dLng == null ||
        placemark == null) {
      _driverAnimationTimer?.cancel();
      _lastDriverTarget = null;
      _lastDriverTargetAt = null;
      _displayedDriverPoint = null;
      return;
    }

    final target = (lat: dLat, lng: dLng);
    final previousTarget = _lastDriverTarget;
    final displayed = _displayedDriverPoint;
    if (previousTarget != null &&
        displayed != null &&
        (previousTarget.lat - target.lat).abs() < 0.0000001 &&
        (previousTarget.lng - target.lng).abs() < 0.0000001 &&
        (displayed.lat - target.lat).abs() < 0.0000001 &&
        (displayed.lng - target.lng).abs() < 0.0000001) {
      return;
    }

    final now = DateTime.now();
    final elapsed = _lastDriverTargetAt == null
        ? const Duration(milliseconds: 900)
        : now.difference(_lastDriverTargetAt!);
    _lastDriverTarget = target;
    _lastDriverTargetAt = now;

    final start = _displayedDriverPoint;
    if (start == null) {
      _setDriverGeometry(target);
      return;
    }

    final durationMs = (elapsed.inMilliseconds * 0.82).round().clamp(650, 3600);
    _animateDriver(
      from: start,
      to: target,
      duration: Duration(milliseconds: durationMs),
    );
  }

  void _animateDriver({
    required MapPoint from,
    required MapPoint to,
    required Duration duration,
  }) {
    _driverAnimationTimer?.cancel();
    final startedAt = DateTime.now();
    _driverAnimationTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      (timer) {
        if (!mounted || _driverPlacemark == null) {
          timer.cancel();
          return;
        }
        final elapsed = DateTime.now().difference(startedAt).inMicroseconds;
        final total = duration.inMicroseconds;
        final raw = total <= 0 ? 1.0 : (elapsed / total).clamp(0.0, 1.0);
        final eased = raw * raw * (3 - 2 * raw);
        final point = _interpolateOnRoute(from, to, eased);
        _setDriverGeometry(point);
        if (raw >= 1) timer.cancel();
      },
    );
  }

  void _setDriverGeometry(MapPoint point) {
    final placemark = _driverPlacemark;
    if (placemark == null) return;
    try {
      placemark.geometry = Point(latitude: point.lat, longitude: point.lng);
      placemark.direction = _directionDegrees(point);
      _displayedDriverPoint = point;
    } catch (_) {
      _driverAnimationTimer?.cancel();
    }
  }

  double _directionDegrees(MapPoint point) {
    final degrees = mapVehicleAngleForRoute(
          widget.routePoints,
          point.lat,
          point.lng,
        ) *
        180 /
        math.pi;
    return (degrees + 360) % 360;
  }

  MapPoint _interpolateOnRoute(MapPoint from, MapPoint to, double t) {
    final route = widget.routePoints;
    if (route.length < 2) return _lerpPoint(from, to, t);

    final fromProgress = _projectedRouteProgress(route, from);
    final toProgress = _projectedRouteProgress(route, to);
    if (fromProgress == null || toProgress == null) {
      return _lerpPoint(from, to, t);
    }
    return _pointAtRouteProgress(
      route,
      fromProgress + (toProgress - fromProgress) * t,
    );
  }

  double? _projectedRouteProgress(List<MapPoint> route, MapPoint point) {
    if (route.length < 2) return null;
    final lengths = <double>[];
    var total = 0.0;
    for (var i = 0; i < route.length - 1; i++) {
      final length = _segmentLength(route[i], route[i + 1]);
      lengths.add(length);
      total += length;
    }
    if (total <= 0) return null;

    var bestDistance = double.infinity;
    var bestAlong = 0.0;
    var accumulated = 0.0;
    for (var i = 0; i < lengths.length; i++) {
      final a = route[i];
      final b = route[i + 1];
      final dx = b.lng - a.lng;
      final dy = b.lat - a.lat;
      final lengthSquared = dx * dx + dy * dy;
      final fraction = lengthSquared <= 0
          ? 0.0
          : (((point.lng - a.lng) * dx + (point.lat - a.lat) * dy) /
                  lengthSquared)
              .clamp(0.0, 1.0);
      final projected = (
        lat: a.lat + (b.lat - a.lat) * fraction,
        lng: a.lng + (b.lng - a.lng) * fraction,
      );
      final distance = _segmentLength(projected, point);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestAlong = accumulated + lengths[i] * fraction;
      }
      accumulated += lengths[i];
    }
    return bestAlong / total;
  }

  MapPoint _pointAtRouteProgress(List<MapPoint> route, double progress) {
    final normalized = progress.clamp(0.0, 1.0);
    var total = 0.0;
    final lengths = <double>[];
    for (var i = 0; i < route.length - 1; i++) {
      final length = _segmentLength(route[i], route[i + 1]);
      lengths.add(length);
      total += length;
    }
    if (total <= 0) return route.first;

    final target = total * normalized;
    var accumulated = 0.0;
    for (var i = 0; i < lengths.length; i++) {
      final next = accumulated + lengths[i];
      if (target <= next || i == lengths.length - 1) {
        final local = lengths[i] <= 0
            ? 0.0
            : ((target - accumulated) / lengths[i]).clamp(0.0, 1.0);
        return _lerpPoint(route[i], route[i + 1], local);
      }
      accumulated = next;
    }
    return route.last;
  }

  MapPoint _lerpPoint(MapPoint a, MapPoint b, double t) => (
        lat: a.lat + (b.lat - a.lat) * t,
        lng: a.lng + (b.lng - a.lng) * t,
      );

  double _segmentLength(MapPoint a, MapPoint b) {
    final midLat = (a.lat + b.lat) * math.pi / 360;
    final dx = (b.lng - a.lng) * math.cos(midLat);
    final dy = b.lat - a.lat;
    return math.sqrt(dx * dx + dy * dy);
  }

  Widget _fallbackCanvas() {
    return PremiumMapCanvas(
      routePoints: widget.routePoints,
      driverLat: widget.driverLat,
      driverLng: widget.driverLng,
      showDriverMarker: widget.showDriverMarker,
      showUserPin: widget.showUserPin,
      nearbyVehicles: widget.nearbyVehicles,
      demoCruise: widget.demoCruise,
      showSetupHint: widget.showSetupHint,
      mapKitKeyPresent: true,
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

class _BridgeCameraListener implements MapCameraListener {
  _BridgeCameraListener(this._onChanged);

  final void Function(
    CameraPosition position,
    CameraUpdateReason reason,
    bool finished,
  ) _onChanged;

  @override
  void onCameraPositionChanged(
    Map map,
    CameraPosition cameraPosition,
    CameraUpdateReason cameraUpdateReason,
    bool finished,
  ) {
    _onChanged(cameraPosition, cameraUpdateReason, finished);
  }
}
