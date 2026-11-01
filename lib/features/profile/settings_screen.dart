import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_config.dart';
import '../../core/config/feature_flags.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/service_type.dart';
import 'about_screen.dart';
import 'providers/settings_provider.dart';
import 'widgets/profile_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _serverUrlController;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _serverUrlController = TextEditingController(text: settings.devServerUrl);
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
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
              const ProfileSectionLabel('Интерфейс'),
              const SizedBox(height: 8),
              _SettingsCard(
                children: [
                  _SwitchTile(
                    title: 'Светлая тема',
                    subtitle: settings.isLightTheme
                        ? 'Дневной режим — светлый фон'
                        : 'Ночной режим — тёмный фон',
                    icon: settings.isLightTheme
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_outlined,
                    value: settings.isLightTheme,
                    onChanged: (value) => settings.setLightTheme(value),
                    showDivider: false,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const ProfileSectionLabel('Уведомления'),
              const SizedBox(height: 8),
              _SettingsCard(
                children: [
                  _SwitchTile(
                    title: 'Push-уведомления',
                    subtitle: settings.notificationsEnabled
                        ? 'Включены'
                        : 'Отключены',
                    icon: Icons.notifications_outlined,
                    value: settings.notificationsEnabled,
                    onChanged: (value) async {
                      final before = settings.notificationsEnabled;
                      await settings.setNotificationsEnabled(value);
                      if (value &&
                          !settings.notificationsEnabled &&
                          context.mounted) {
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
                          before != value &&
                          context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Push-токен отправлен на сервер')),
                        );
                      }
                    },
                  ),
                  _SwitchTile(
                    title: 'Обновления поездки',
                    subtitle: 'Водитель принял, прибыл, завершил',
                    icon: Icons.local_taxi_outlined,
                    value: settings.tripUpdatesEnabled,
                    onChanged: settings.setTripUpdatesEnabled,
                  ),
                  _SwitchTile(
                    title: 'Акции и предложения',
                    subtitle: 'Скидки и спецтарифы',
                    icon: Icons.local_offer_outlined,
                    value: settings.promoEnabled,
                    onChanged: settings.setPromoEnabled,
                    showDivider: false,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const ProfileSectionLabel('Заказ по умолчанию'),
              const SizedBox(height: 8),
              _SettingsCard(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Тип услуги',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ServiceType.values.map((type) {
                          final selected = settings.defaultServiceType == type;
                          return ChoiceChip(
                            avatar: Icon(
                              type.icon,
                              size: 18,
                              color: selected
                                  ? AppColors.purple
                                  : AppColors.textSecondary,
                            ),
                            label: Text(type.label),
                            selected: selected,
                            onSelected: (_) =>
                                settings.setDefaultServiceType(type),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      _SwitchTileInline(
                        title: 'С детьми',
                        value: settings.defaultWithKids,
                        onChanged: settings.setDefaultWithKids,
                      ),
                      _SwitchTileInline(
                        title: 'С животными',
                        value: settings.defaultWithPets,
                        onChanged: settings.setDefaultWithPets,
                      ),
                      _SwitchTileInline(
                        title: 'Остановки по умолчанию',
                        subtitle: 'Предлагать промежуточные точки',
                        value: settings.defaultStopsEnabled,
                        onChanged: settings.setDefaultStopsEnabled,
                      ),
                      _SwitchTileInline(
                        title: 'Предварительный заказ',
                        subtitle: 'Открывать выбор даты сразу',
                        value: settings.defaultAdvanceBooking,
                        onChanged: settings.setDefaultAdvanceBooking,
                      ),
                    ],
                  ),
                ),
              ),
              if (FeatureFlags.enableDemoMode) ...[
                const SizedBox(height: 24),
                const ProfileSectionLabel('Демо'),
                const SizedBox(height: 8),
                _SettingsCard(
                  children: [
                    _SwitchTile(
                      title: 'Демо поездка',
                      subtitle: settings.demoTripEnabled
                          ? 'Следующий заказ пройдет по сценарию без сервера'
                          : 'Обычные заказы идут через реальный сервер',
                      icon: Icons.play_circle_outline_rounded,
                      value: settings.demoTripEnabled,
                      onChanged: settings.setDemoTripEnabled,
                      showDivider: false,
                    ),
                  ],
                ),
              ],
              if (kDebugMode) ...[
                const SizedBox(height: 24),
                const ProfileSectionLabel('Разработка'),
                const SizedBox(height: 8),
                _SettingsCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Mock API'),
                          subtitle: Text(
                            settings.useMockApi
                                ? 'Локальные заглушки'
                                : 'Реальный сервер',
                          ),
                          value: settings.useMockApi,
                          onChanged: settings.setUseMockApi,
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _serverUrlController,
                          decoration: const InputDecoration(
                            labelText: 'URL сервера',
                            hintText: ApiConfig.defaultBaseUrl,
                            prefixIcon: Icon(Icons.dns_outlined),
                          ),
                          onSubmitted: settings.setDevServerUrl,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  settings.setDevServerUrl(
                                      _serverUrlController.text);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Сервер: ${settings.effectiveBaseUrl}',
                                      ),
                                    ),
                                  );
                                },
                                child: const Text('Сохранить URL'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Сбросить',
                              onPressed: () {
                                settings.resetDevServerUrl();
                                _serverUrlController.text =
                                    settings.devServerUrl;
                              },
                              icon: const Icon(Icons.restore),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Текущий: ${settings.effectiveBaseUrl}',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              const ProfileSectionLabel('О приложении'),
              const SizedBox(height: 8),
              _SettingsCard(
                children: [
                  _LinkTile(
                    icon: Icons.info_outline_rounded,
                    title: 'О приложении',
                    subtitle: 'Версия ${AboutScreen.versionLabel}',
                    onTap: () => context.push(AppRoutes.about),
                  ),
                  _LinkTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Политика конфиденциальности',
                    onTap: () => context.push(AppRoutes.privacyPolicy),
                    showDivider: true,
                  ),
                  _LinkTile(
                    icon: Icons.description_outlined,
                    title: 'Пользовательское соглашение',
                    onTap: () => context.push(AppRoutes.terms),
                    showDivider: false,
                  ),
                ],
              ),
              if (settings.saving) ...[
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'Сохранение…',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({this.children, this.child})
      : assert(children != null || child != null);

  final List<Widget>? children;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: child ?? Column(children: children!),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.showDivider = true,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SwitchListTile(
          secondary: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.purple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.purple, size: 20),
          ),
          title: Text(title),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
          value: value,
          onChanged: onChanged,
        ),
        if (showDivider)
          Divider(height: 1, indent: 68, color: AppColors.divider),
      ],
    );
  }
}

class _SwitchTileInline extends StatelessWidget {
  const _SwitchTileInline({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: subtitle != null
          ? Text(subtitle!, style: const TextStyle(fontSize: 12))
          : null,
      value: value,
      onChanged: onChanged,
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.purple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.purple, size: 20),
          ),
          title: Text(title),
          subtitle: subtitle != null
              ? Text(subtitle!, style: const TextStyle(fontSize: 12))
              : null,
          trailing:
              Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          onTap: onTap,
        ),
        if (showDivider)
          Divider(height: 1, indent: 68, color: AppColors.divider),
      ],
    );
  }
}
