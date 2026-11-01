import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/service_type.dart';

/// Селектор типа услуги: Такси / Трезвый водитель (+ подрежимы 2048).
class ServiceTypeSelector extends StatelessWidget {
  const ServiceTypeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.showSoberSubmodes = true,
    this.compact = false,
  });

  final ServiceType selected;
  final ValueChanged<ServiceType> onChanged;
  final bool showSoberSubmodes;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: ServiceType.primary.map((type) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: type == ServiceType.primary.first ? 8 : 0,
                  left: type == ServiceType.primary.last ? 8 : 0,
                ),
                child: _ServiceTypeCard(
                  type: type,
                  selected: selected.isTaxi
                      ? type.isTaxi
                      : type == ServiceType.soberDriver && selected.isSoberMode,
                  onTap: () => onChanged(
                    type.isTaxi ? ServiceType.taxi : ServiceType.soberDriver,
                  ),
                  compact: compact,
                ),
              ),
            );
          }).toList(),
        ),
        if (showSoberSubmodes && selected.isSoberMode) ...[
          const SizedBox(height: 10),
          Row(
            children: ServiceType.soberModes.map((type) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _SoberSubmodeChip(
                    type: type,
                    selected: selected == type,
                    onTap: () => onChanged(type),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class _ServiceTypeCard extends StatelessWidget {
  const _ServiceTypeCard({
    required this.type,
    required this.selected,
    required this.onTap,
    required this.compact,
  });

  final ServiceType type;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: compact ? 64 : 78,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.purple.withValues(alpha: 0.16)
                : context.palette.bgElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AppColors.gold.withValues(alpha: 0.9)
                  : context.palette.border.withValues(
                      alpha: context.isDarkTheme ? 0.5 : 0.85,
                    ),
              width: selected ? 1.5 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.12),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                type.icon,
                size: compact ? 22 : 24,
                color: selected ? AppColors.gold : context.palette.textSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                type.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? context.palette.textPrimary
                      : context.palette.textSecondary,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoberSubmodeChip extends StatelessWidget {
  const _SoberSubmodeChip({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final ServiceType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.gold.withValues(alpha: 0.15)
          : AppColors.backgroundSecondary,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.gold : AppColors.border,
            ),
          ),
          child: Text(
            type.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.gold : AppColors.textMuted,
              height: 1.15,
            ),
          ),
        ),
      ),
    );
  }
}
