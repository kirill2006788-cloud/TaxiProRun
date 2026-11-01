import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_provider.dart';
import '../../shared/maps_navigation.dart';
import '../../shared/widgets.dart';
import '../info/info_screens.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final settings = settingsProvider.settings;
    final isLight = settingsProvider.isLightTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const SectionTitle('Оформление'),
          SectionCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: SettingsTile(
              icon: isLight
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              title: 'Светлая тема',
              subtitle:
                  isLight ? 'Светлый интерфейс' : 'Тёмный интерфейс',
              trailing: Switch(
                value: isLight,
                onChanged: settingsProvider.setLightTheme,
              ),
            ),
          ),
          const SectionTitle('Уведомления и навигация'),
          SectionCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              children: [
                SettingsTile(
                  icon: Icons.notifications_outlined,
                  title: 'Уведомления о заказах',
                  subtitle: settings.notificationsEnabled
                      ? 'Включены: звук и push'
                      : 'Выключены',
                  trailing: Switch(
                    value: settings.notificationsEnabled,
                    onChanged: (value) =>
                        context.read<SettingsProvider>().setNotifications(value),
                  ),
                ),
                const Divider(),
                SettingsTile(
                  icon: Icons.navigation_outlined,
                  title: 'Навигация',
                  subtitle: navAppLabel(settings.navApp),
                  onTap: () => _showNavPicker(context, settings.navApp),
                ),
              ],
            ),
          ),
          const SectionTitle('Информация'),
          SectionCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              children: [
                SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Политика конфиденциальности',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => LegalDocumentScreen.privacy(),
                      ),
                    );
                  },
                ),
                const Divider(),
                SettingsTile(
                  icon: Icons.description_outlined,
                  title: 'Пользовательское соглашение водителя',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => LegalDocumentScreen.agreement(),
                      ),
                    );
                  },
                ),
                const Divider(),
                SettingsTile(
                  icon: Icons.support_agent_rounded,
                  title: 'Поддержка',
                  onTap: () => context.push(AppRoutes.support),
                ),
                const Divider(),
                SettingsTile(
                  icon: Icons.info_outline_rounded,
                  title: 'О приложении',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AboutScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          SectionCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: SettingsTile(
              icon: Icons.logout_rounded,
              title: 'Выход',
              destructive: true,
              trailing: const SizedBox.shrink(),
              onTap: () => _confirmLogout(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showNavPicker(BuildContext context, NavApp current) async {
    final t = context.tokens;
    final selected = await showModalBottomSheet<NavApp>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Навигация',
                  style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.check_circle,
                  color: current == NavApp.yandex
                      ? AppColors.purple
                      : Colors.transparent,
                ),
                title: const Text('Яндекс Навигатор'),
                onTap: () => Navigator.pop(ctx, NavApp.yandex),
              ),
              ListTile(
                leading: Icon(
                  Icons.check_circle,
                  color: current == NavApp.google
                      ? AppColors.purple
                      : Colors.transparent,
                ),
                title: const Text('Google Maps'),
                onTap: () => Navigator.pop(ctx, NavApp.google),
              ),
              ListTile(
                leading: Icon(
                  Icons.check_circle,
                  color: current == NavApp.dgis
                      ? AppColors.purple
                      : Colors.transparent,
                ),
                title: const Text('2ГИС'),
                onTap: () => Navigator.pop(ctx, NavApp.dgis),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (selected != null && context.mounted) {
      context.read<SettingsProvider>().setNavApp(selected);
    }
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Выйти из аккаунта?'),
          content: const Text(
            'Вы выйдете из аккаунта и вернётесь на экран входа.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Выйти',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        );
      },
    );
    if (ok == true && context.mounted) {
      final auth = context.read<AuthProvider>();
      final settings = context.read<SettingsProvider>();
      await auth.logout();
      await settings.logout();
    }
  }
}
