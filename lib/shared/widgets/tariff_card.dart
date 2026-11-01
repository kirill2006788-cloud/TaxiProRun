import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/tariff.dart';

class TariffCard extends StatelessWidget {
  const TariffCard({
    super.key,
    required this.tariff,
    required this.isSelected,
    required this.onTap,
  });

  final Tariff tariff;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sober = tariff.isSoberDriver;
    final accent = sober ? AppColors.purple : AppColors.gold;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: sober
                ? AppColors.purple.withValues(alpha: isSelected ? 0.14 : 0.08)
                : AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? accent : AppColors.border,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected && sober
                ? [
                    BoxShadow(
                      color: AppColors.purple.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              _TariffIcon(tariff: tariff),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tariff.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: sober && isSelected
                                  ? AppColors.purple
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (sober)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.purple.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.purple.withValues(alpha: 0.45),
                              ),
                            ),
                            child: const Text(
                              'Трезвый',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.purple,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (tariff.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        tariff.description!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (tariff.maxPassengers != null) ...[
                          Icon(Icons.person_outline, size: 16, color: AppColors.textSecondary),
                          Text(
                            ' ${tariff.maxPassengers}',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                          const SizedBox(width: 12),
                        ],
                        if (tariff.maxBags != null) ...[
                          Icon(Icons.luggage_outlined, size: 16, color: AppColors.textSecondary),
                          Text(
                            ' ${tariff.maxBags}',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    tariff.clientRateLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: tariff.isSoberDriver ? AppColors.purple : AppColors.gold,
                    ),
                  ),
                  if (tariff.driverRateLabel != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Водителю: ${tariff.driverRateLabel}',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TariffIcon extends StatelessWidget {
  const _TariffIcon({required this.tariff});

  final Tariff tariff;

  @override
  Widget build(BuildContext context) {
    if (tariff.isSoberDriver) {
      return Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.purple.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.purple.withValues(alpha: 0.4)),
        ),
        child: const Icon(Icons.key, color: AppColors.purple, size: 28),
      );
    }

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Icon(
        _iconForTariff(tariff.icon),
        color: AppColors.textSecondary,
        size: 28,
      ),
    );
  }

  IconData _iconForTariff(String icon) => switch (icon) {
        'economy' || 'standard' || 'comfort' || 'comfort_plus' => Icons.directions_car_filled_outlined,
        'compact_van' || 'minivan' || 'gazelle' => Icons.airport_shuttle_outlined,
        'bus' => Icons.directions_bus_outlined,
        _ => Icons.local_taxi_outlined,
      };
}
