import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

/// Единый AppBar с кнопкой «назад».
PreferredSizeWidget driverAppBar(
  BuildContext context, {
  required String title,
  List<Widget>? actions,
}) {
  return AppBar(
    title: Text(title),
    leading: IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: 'Назад',
      onPressed: () => context.pop(),
    ),
    actions: actions,
  );
}

/// Баннер «регистрация на проверке».
class RegistrationPendingBanner extends StatelessWidget {
  const RegistrationPendingBanner({super.key, this.onTapDocs});

  final VoidCallback? onTapDocs;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: t.isDark ? 0.12 : 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: t.isDark ? 0.45 : 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.hourglass_top_rounded, color: AppColors.warning),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Регистрация на проверке',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Документы проверяются модератором. Выход на линию будет доступен после верификации.',
            style: TextStyle(color: t.textSecondary, height: 1.35),
          ),
          if (onTapDocs != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: onTapDocs,
              child: const Text('Загрузить документы'),
            ),
          ],
        ],
      ),
    );
  }
}
