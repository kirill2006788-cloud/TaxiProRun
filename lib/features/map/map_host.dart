import 'package:flutter/material.dart';

import '../../core/config/map_config.dart';
import 'map_camera_controller.dart';
import 'map_geo.dart';
import 'map_pin_mode.dart';
import 'premium_map_canvas.dart';
import 'yandex_mapkit_bridge.dart';

/// Единая точка входа карты для маршрута / активной поездки.
class MapHost extends StatelessWidget {
  const MapHost({
    super.key,
    this.routePoints = const [],
    this.driverLat,
    this.driverLng,
    this.showDriverMarker = false,
    this.showUserPin = false,
    this.nearbyVehicleCount = 0,
    this.nearbyVehicles = const [],
    this.demoCruise = false,
    this.showSetupHint = true,
    this.onMapCreated,
    this.borderRadius,
    this.pinMode = MapPinMode.none,
    this.onCameraMoving,
    this.onCameraIdle,
    this.cameraController,
    this.nightMode,
  });

  final List<MapPoint> routePoints;
  final double? driverLat;
  final double? driverLng;
  final bool showDriverMarker;
  final bool showUserPin;
  final int nearbyVehicleCount;
  final List<MapPoint> nearbyVehicles;
  final bool demoCruise;
  final bool showSetupHint;
  final VoidCallback? onMapCreated;
  final BorderRadius? borderRadius;
  final MapPinMode pinMode;
  final MapCameraMovingCallback? onCameraMoving;
  final MapCameraIdleCallback? onCameraIdle;
  final MapCameraController? cameraController;
  final bool? nightMode;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onMapCreated?.call();
    });

    final effectiveNightMode =
        nightMode ?? Theme.of(context).brightness == Brightness.dark;
    final map = MapConfig.isMapKitReady
        ? YandexMapKitBridge(
            routePoints: routePoints,
            driverLat: driverLat,
            driverLng: driverLng,
            showDriverMarker: showDriverMarker,
            showUserPin: showUserPin,
            nearbyVehicles: nearbyVehicles,
            demoCruise: demoCruise,
            showSetupHint: showSetupHint,
            pinMode: pinMode,
            onCameraMoving: onCameraMoving,
            onCameraIdle: onCameraIdle,
            cameraController: cameraController,
            nightMode: effectiveNightMode,
          )
        : PremiumMapCanvas(
            routePoints: routePoints,
            driverLat: driverLat,
            driverLng: driverLng,
            showDriverMarker: showDriverMarker,
            showUserPin: showUserPin,
            nearbyVehicles: nearbyVehicles,
            demoCruise: demoCruise,
            showSetupHint: showSetupHint,
            mapKitKeyPresent: MapConfig.isMapKitEnabled,
          );

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: map);
    }
    return map;
  }
}
