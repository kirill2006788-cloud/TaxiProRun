import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/service_type.dart';
import '../../../shared/widgets/action_buttons.dart';
import 'destination_search_sheet.dart';

/// Compact home sheet: search + saved / recent only.
class GoHomeSheet extends StatelessWidget {
  const GoHomeSheet({
    super.key,
    required this.recentDestinations,
    required this.onWhereTo,
    required this.onSelectRecent,
    this.savedPlaces = const [],
    this.onSelectSaved,
    this.serviceType = ServiceType.taxi,
    this.onServiceChanged,
    this.onConfirmPickup,
    this.pickupAddress,
  });

  final List<String> recentDestinations;
  final List<SavedPlaceItem> savedPlaces;
  final VoidCallback onWhereTo;
  final ValueChanged<String> onSelectRecent;
  final ValueChanged<String>? onSelectSaved;
  final ServiceType serviceType;
  final ValueChanged<ServiceType>? onServiceChanged;
  final VoidCallback? onConfirmPickup;
  final String? pickupAddress;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final editingPickup = onConfirmPickup != null;
    final saved = savedPlaces.take(3).toList(growable: false);

    if (editingPickup) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Точка подачи',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: p.textPrimary,
            ),
          ),
          if ((pickupAddress ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              pickupAddress!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: p.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          GoldActionButton(
            label: 'Готово',
            onPressed: onConfirmPickup,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: p.bgElevated,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onWhereTo,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: p.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.search_rounded,
                      color: AppColors.gold,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Куда едем?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (saved.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: saved.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final place = saved[index];
                return ActionChip(
                  avatar: Icon(place.icon, size: 17, color: AppColors.gold),
                  label: Text(place.label),
                  onPressed: () =>
                      (onSelectSaved ?? onSelectRecent)(place.address),
                );
              },
            ),
          ),
        ],
        if (recentDestinations.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            'Недавние',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: p.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          ...recentDestinations.take(3).map(
                (address) => InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onSelectRecent(address),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 19,
                          color: p.textMuted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: p.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ],
    );
  }
}
