import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Плитка mock-загрузки фото (имитация выбора из галереи).
class PhotoUploadTile extends StatelessWidget {
  const PhotoUploadTile({
    super.key,
    required this.label,
    required this.icon,
    required this.uploaded,
    required this.onPick,
  });

  final String label;
  final IconData icon;
  final bool uploaded;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPick,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 110,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: t.elevated,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: uploaded ? AppColors.success : t.border,
              width: uploaded ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                uploaded ? Icons.check_circle_rounded : icon,
                color: uploaded ? AppColors.success : AppColors.gold,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: uploaded ? t.textPrimary : t.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
              ),
              if (!uploaded)
                Text(
                  'Из галереи',
                  style: TextStyle(color: t.textMuted, fontSize: 10),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
