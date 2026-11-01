import 'package:flutter/material.dart';

import '../../map/map_geo.dart';
import '../../map/map_host.dart';

/// Карта маршрута заказа — делегирует в [MapHost].
class NavMapPlaceholder extends StatelessWidget {
  const NavMapPlaceholder({
    super.key,
    this.routePoints = const [],
    this.etaMinutes,
  });

  final List<MapPoint> routePoints;
  final int? etaMinutes;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        MapHost(
          routePoints: routePoints,
          demoCruise: false,
          showSetupHint: false,
        ),
        if (etaMinutes != null)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: (isDark ? const Color(0xFF1A1A1E) : Colors.white)
                    .withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF2E2E34)
                      : const Color(0xFFDDE2EC),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Text(
                  'До точки · ~$etaMinutes мин',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFFB0B0B8)
                        : const Color(0xFF5A6172),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
