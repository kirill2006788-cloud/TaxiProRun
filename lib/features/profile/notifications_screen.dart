import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import 'providers/settings_provider.dart';

/// Экран уведомлений — синхронизирован с [SettingsProvider] (логика 2048).
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Уведомления'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          if (!settings.loaded) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text(
                'Управление push-уведомлениями и рассылками',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              _SwitchCard(
                title: 'Push-уведомления',
                subtitle:
                    settings.notificationsEnabled ? 'Включены' : 'Отключены',
                icon: Icons.notifications_active_outlined,
                value: settings.notificationsEnabled,
                onChanged: (value) async {
                  final before = settings.notificationsEnabled;
                  await settings.setNotificationsEnabled(value);
                  if (!context.mounted) return;
                  if (value && !settings.notificationsEnabled) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Разрешите уведомления в настройках телефона',
                        ),
                        action: SnackBarAction(
                          label: 'Настройки',
                          onPressed: openAppSettings,
                        ),
                      ),
                    );
                  } else if (value &&
                      settings.notificationsEnabled &&
                      before != value) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Push-токен отправлен на сервер')),
                    );
                  }
                },
              ),
              _SwitchCard(
                title: 'Обновления поездки',
                subtitle: 'Водитель принял заказ, прибыл, завершил',
                icon: Icons.local_taxi_outlined,
                value: settings.tripUpdatesEnabled,
                onChanged: settings.setTripUpdatesEnabled,
              ),
              _SwitchCard(
                title: 'Акции и предложения',
                subtitle: 'Скидки и спецтарифы',
                icon: Icons.local_offer_outlined,
                value: settings.promoEnabled,
                onChanged: settings.setPromoEnabled,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SwitchCard extends StatelessWidget {
  const _SwitchCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: SwitchListTile(
        secondary: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.purple.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon,
              color: value ? AppColors.purple : AppColors.textSecondary,
              size: 20),
        ),
        title: Text(title),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
