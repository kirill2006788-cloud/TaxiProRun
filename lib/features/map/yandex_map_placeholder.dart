import 'package:flutter/material.dart';

import '../../core/config/map_config.dart';
import 'map_geo.dart';
import 'map_host.dart';

/// Обратная совместимость: тонкая обёртка над [MapHost].
///
/// Новые экраны используйте [MapHost] напрямую.
@Deprecated('Use MapHost')
class YandexMapPlaceholder extends StatelessWidget {
  const YandexMapPlaceholder({
    super.key,
    this.onMapCreated,
    this.routePoints = const [],
    this.showUserLocation = true,
  });

  final VoidCallback? onMapCreated;
  final List<(double, double)> routePoints;
  final bool showUserLocation;

  @override
  Widget build(BuildContext context) {
    final points = routePoints.isEmpty
        ? kDefaultMockRoute
        : mapPointsFromTuples(routePoints);
    return MapHost(
      routePoints: points,
      showUserPin: showUserLocation,
      showSetupHint: !MapConfig.isMapKitReady,
      onMapCreated: onMapCreated,
    );
  }
}

/// @nodoc — оставлено для импортов `mockRoutePoints`.
const mockRoutePoints = <(double, double)>[
  (MapConfig.defaultLatitude, MapConfig.defaultLongitude),
  (55.765, 37.605),
  (55.820, 37.520),
  (55.973, 37.414),
];
