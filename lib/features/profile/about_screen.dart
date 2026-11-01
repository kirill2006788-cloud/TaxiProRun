import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const version = '1.0.0';
  static const buildNumber = '1';
  static const versionLabel = '$version ($buildNumber)';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('О приложении'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.gold.withValues(alpha: 0.35),
                    AppColors.purple.withValues(alpha: 0.45),
                  ],
                ),
                border:
                    Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
              ),
              child: const Icon(
                Icons.directions_car_filled_rounded,
                size: 40,
                color: AppColors.gold,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'КОРОЛИ ДОРОГ',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Такси и трезвый водитель',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 28),
          const _InfoRow(label: 'Версия', value: versionLabel),
          const _InfoRow(label: 'Сборка', value: buildNumber),
          const _InfoRow(label: 'Платформа', value: 'Flutter'),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.backgroundSecondary,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Поддержка',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  '+7 (906) 042-42-41',
                  style: TextStyle(color: AppColors.purple),
                ),
                const SizedBox(height: 4),
                Text(
                  'support@koroli-dorog.ru',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Text(
            '© 2026 КОРОЛИ ДОРОГ\nВсе права защищены',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
