import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/action_buttons.dart';

/// Compact confirm sheet while picking destination on the map.
class DestinationMapSheet extends StatelessWidget {
  const DestinationMapSheet({
    super.key,
    required this.address,
    required this.onDone,
    required this.onBack,
    this.geocoding = false,
  });

  final String address;
  final VoidCallback onDone;
  final VoidCallback onBack;
  final bool geocoding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Material(
              color: p.bgElevated,
              shape: const CircleBorder(),
              child: IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
                tooltip: 'Назад к поиску',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Куда едем?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: p.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        DecoratedBox(
          decoration: BoxDecoration(
            color: p.bgElevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.gold),
                const SizedBox(width: 10),
                Expanded(
                  child: geocoding
                      ? Text(
                          'Определяем адрес…',
                          style: TextStyle(color: p.textSecondary),
                        )
                      : Text(
                          address.isEmpty ? 'Переместите карту' : address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: p.textPrimary,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        GoldActionButton(
          label: 'Готово',
          enabled: address.trim().isNotEmpty && !geocoding,
          onPressed: onDone,
        ),
      ],
    );
  }
}
