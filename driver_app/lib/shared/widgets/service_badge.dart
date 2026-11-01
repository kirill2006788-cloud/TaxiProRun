import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/models.dart';

class ServiceTypeBadge extends StatelessWidget {
  const ServiceTypeBadge({
    super.key,
    required this.serviceType,
    this.compact = false,
  });

  final DriverServiceType serviceType;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (icon, color, bg) = _style(serviceType);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 14 : 16, color: color),
          const SizedBox(width: 4),
          Text(
            serviceType.label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: compact ? 11 : 12,
            ),
          ),
        ],
      ),
    );
  }

  (IconData, Color, Color) _style(DriverServiceType type) {
    return switch (type) {
      DriverServiceType.soberDriver => (
          Icons.no_drinks_rounded,
          AppColors.gold,
          AppColors.gold.withValues(alpha: 0.15),
        ),
      DriverServiceType.personalDriver => (
          Icons.person_pin_circle_rounded,
          AppColors.purple,
          AppColors.purple.withValues(alpha: 0.2),
        ),
      DriverServiceType.carTransfer => (
          Icons.directions_car_filled_outlined,
          const Color(0xFF60A5FA),
          const Color(0x3360A5FA),
        ),
      DriverServiceType.taxi => (
          Icons.local_taxi_rounded,
          AppColors.gold,
          AppColors.gold.withValues(alpha: 0.12),
        ),
    };
  }
}
