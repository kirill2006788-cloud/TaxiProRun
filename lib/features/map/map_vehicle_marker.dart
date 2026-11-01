import 'dart:math' as math;

import 'package:flutter/material.dart';

class MapVehicleMarker extends StatelessWidget {
  const MapVehicleMarker({
    super.key,
    this.angle = 0,
    this.size = 40,
    this.isDriver = false,
  });

  final double angle;
  final double size;
  final bool isDriver;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isDriver)
            Container(
              width: size * 0.54,
              height: size * 0.78,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size * 0.22),
                color: Colors.transparent,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF16D469).withValues(alpha: 0.42),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          Transform.rotate(
            angle: angle,
            child: SizedBox(
              width: size * 0.58,
              height: size * 0.92,
              child: Image.asset(
                'assets/images/map/car_yellow_top.png',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

double mapVehicleAngleForRoute(
  List<({double lat, double lng})> route,
  double lat,
  double lng,
) {
  if (route.length < 2) return 0;

  var nearest = 0;
  var nearestDistance = double.infinity;
  for (var i = 0; i < route.length; i++) {
    final dLat = route[i].lat - lat;
    final dLng = route[i].lng - lng;
    final distance = dLat * dLat + dLng * dLng;
    if (distance < nearestDistance) {
      nearestDistance = distance;
      nearest = i;
    }
  }

  final from = route[nearest == route.length - 1 ? nearest - 1 : nearest];
  final to = route[nearest == route.length - 1 ? nearest : nearest + 1];
  final east =
      (to.lng - from.lng) * math.cos(((from.lat + to.lat) / 2) * math.pi / 180);
  final north = to.lat - from.lat;
  return math.atan2(east, north);
}

double mapVehicleAngleForIndex(int index) {
  const angles = [
    -0.42,
    0.28,
    -0.12,
    0.55,
    -0.70,
    0.14,
    0.38,
    -0.30,
    0.76,
    -0.52
  ];
  return angles[index % angles.length];
}
