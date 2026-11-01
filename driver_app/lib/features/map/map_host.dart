import 'package:flutter/material.dart';

import '../../core/config/map_config.dart';
import 'map_geo.dart';
import 'premium_nav_map_canvas.dart';
import 'yandex_mapkit_bridge.dart';

/// Единый хост карты водителя.
///
/// Без ключа / без флага — [PremiumNavMapCanvas].
/// С `MapConfig.isMapKitReady` — [YandexMapKitBridge] (soft-fallback на canvas).
class MapHost extends StatelessWidget {
  const MapHost({
    super.key,
    this.routePoints = const [],
    this.driverLat,
    this.driverLng,
    this.recenterToken = 0,
    this.progress,
    this.demoCruise = false,
    this.showSetupHint = true,
    this.nightMode,
    this.onMapCreated,
  });

  final List<MapPoint> routePoints;
  final double? driverLat;
  final double? driverLng;
  final int recenterToken;
  final double? progress;
  final bool demoCruise;
  final bool showSetupHint;
  final bool? nightMode;
  final VoidCallback? onMapCreated;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => onMapCreated?.call());

    final effectiveNightMode =
        nightMode ?? Theme.of(context).brightness == Brightness.dark;

    if (MapConfig.isMapKitReady) {
      return YandexMapKitBridge(
        routePoints: routePoints,
        driverLat: driverLat,
        driverLng: driverLng,
        recenterToken: recenterToken,
        progress: progress,
        demoCruise: demoCruise,
        showSetupHint: showSetupHint,
        nightMode: effectiveNightMode,
      );
    }

    return PremiumNavMapCanvas(
      routePoints: routePoints,
      progress: progress,
      demoCruise: demoCruise,
      showSetupHint: showSetupHint || !MapConfig.isMapKitEnabled,
    );
  }
}
