import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../auth/providers/auth_provider.dart';
import 'providers/profile_provider.dart';
import 'widgets/profile_widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Обновить',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => context.read<ProfileProvider>().syncFromServer(),
          ),
        ],
      ),
      body: Consumer<ProfileProvider>(
        builder: (context, profile, _) {
          if (!profile.loaded) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _ProfileHeader(profile: profile),
              if (profile.syncing)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Синхронизация с сервером…',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 20),
              ProfileBonusBanner(
                balance: profile.bonusBalance,
                onTap: () => context.push(AppRoutes.referral),
              ),
              const SizedBox(height: 24),
              const ProfileSectionLabel('Аккаунт'),
              ProfileMenuCard(
                children: [
                  ProfileMenuTile(
                    icon: Icons.person_outline,
                    title: 'Учётная запись',
                    subtitle: 'Имя, телефон, отчество',
                    onTap: () => context.push(AppRoutes.account),
                  ),
                  ProfileMenuTile(
                    icon: Icons.credit_card_outlined,
                    title: 'Способы оплаты',
                    onTap: () => context.push(AppRoutes.paymentMethods),
                  ),
                  ProfileMenuTile(
                    icon: Icons.bookmark_border_rounded,
                    title: 'Избранные адреса',
                    subtitle: 'Дом, работа, избранное',
                    onTap: () => context.push(AppRoutes.favorites),
                  ),
                  ProfileMenuTile(
                    icon: Icons.directions_car_outlined,
                    title: 'Мои автомобили',
                    subtitle: 'Для трезвого водителя и перегона',
                    onTap: () => context.push(AppRoutes.vehicles),
                    showDivider: false,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const ProfileSectionLabel('Бонусы'),
              ProfileMenuCard(
                children: [
                  ProfileMenuTile(
                    icon: Icons.local_offer_outlined,
                    title: 'Промокоды',
                    subtitle: profile.promoDiscountPercent > 0
                        ? 'Активна скидка −${profile.promoDiscountPercent}%'
                        : 'Активировать промокод',
                    iconColor: AppColors.gold,
                    onTap: () => context.push(AppRoutes.promo),
                  ),
                  ProfileMenuTile(
                    icon: Icons.card_giftcard_outlined,
                    title: 'Пригласить друзей',
                    subtitle: '3 друга = 500 ₽ на поездки',
                    iconColor: AppColors.gold,
                    onTap: () => context.push(AppRoutes.referral),
                    showDivider: false,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const ProfileSectionLabel('Заказы'),
              ProfileMenuCard(
                children: [
                  ProfileMenuTile(
                    icon: Icons.receipt_long_outlined,
                    title: 'История заказов',
                    subtitle: 'Чеки и детали поездок',
                    onTap: () => context.push(AppRoutes.tripHistory),
                  ),
                  ProfileMenuTile(
                    icon: Icons.notifications_outlined,
                    title: 'Уведомления',
                    onTap: () => context.push(AppRoutes.notifications),
                    showDivider: false,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const ProfileSectionLabel('Приложение'),
              ProfileMenuCard(
                children: [
                  ProfileMenuTile(
                    icon: Icons.settings_outlined,
                    title: 'Настройки',
                    subtitle: 'Тема, уведомления, заказ по умолчанию',
                    onTap: () => context.push(AppRoutes.settings),
                    showDivider: false,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const ProfileSectionLabel('Документы'),
              ProfileMenuCard(
                children: [
                  ProfileMenuTile(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Политика конфиденциальности',
                    onTap: () => context.push(AppRoutes.privacyPolicy),
                  ),
                  ProfileMenuTile(
                    icon: Icons.description_outlined,
                    title: 'Пользовательское соглашение',
                    onTap: () => context.push(AppRoutes.terms),
                  ),
                  ProfileMenuTile(
                    icon: Icons.info_outline_rounded,
                    title: 'О приложении',
                    subtitle: 'Версия 1.0.0',
                    onTap: () => context.push(AppRoutes.about),
                    showDivider: false,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _SupportCard(
                onOpenTickets: () => context.push(AppRoutes.support),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _confirmLogout(context, profile),
                icon: const Icon(Icons.logout_rounded, color: AppColors.error),
                label: const Text('Выход',
                    style: TextStyle(color: AppColors.error)),
                style: OutlinedButton.styleFrom(
                  side:
                      BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                  minimumSize: const Size(double.infinity, 52),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => _confirmDeleteAccount(context, profile),
                child: Text(
                  'Удалить аккаунт',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    ProfileProvider profile,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить аккаунт?'),
        content: const Text(
          'Запрос на удаление будет отправлен в поддержку. '
          'Вы выйдете из приложения. Полное удаление данных выполняется оператором '
          'после подтверждения личности.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Удалить',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<AuthProvider>().logout();
    await profile.logout();
    if (!context.mounted) return;
    context.go(AppRoutes.auth);
  }

  Future<void> _confirmLogout(
      BuildContext context, ProfileProvider profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        content:
            const Text('Вы выйдете из аккаунта и вернётесь на экран входа.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Выйти', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<AuthProvider>().logout();
      await profile.logout();
      if (context.mounted) {
        context.go(AppRoutes.auth);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Вы вышли из аккаунта')),
        );
      }
    }
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final ProfileProvider profile;

  @override
  Widget build(BuildContext context) {
    final color = Color(profile.avatarColorValue);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.12),
            AppColors.backgroundSecondary
          ],
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _showAvatarSheet(context, profile),
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: color.withValues(alpha: 0.25),
                  backgroundImage: profile.avatarBase64 != null
                      ? MemoryImage(base64Decode(profile.avatarBase64!))
                      : null,
                  child: profile.avatarBase64 == null
                      ? Text(
                          profile.initials,
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: color),
                        )
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: AppColors.backgroundElevated,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Icon(Icons.camera_alt_outlined,
                        size: 14, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(profile.phone,
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 14)),
                if (profile.fullName.isNotEmpty &&
                    profile.fullName != profile.displayName) ...[
                  const SizedBox(height: 4),
                  Text(
                    profile.fullName,
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 8),
                Text('Нажмите на аватар, чтобы сменить',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAvatarSheet(BuildContext context, ProfileProvider profile) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Сменить цвет аватара'),
              onTap: () {
                profile.cycleAvatar();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Аватар обновлён'),
                      duration: Duration(seconds: 1)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Выбрать из галереи'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await profile.pickAvatar();
                } catch (_) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Не удалось выбрать фото')),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({required this.onOpenTickets});

  final VoidCallback onOpenTickets;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.purple,
                      AppColors.purple.withValues(alpha: 0.7)
                    ],
                  ),
                ),
                child: const Icon(Icons.support_agent,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Поддержка',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Чаты и звонок',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () async {
                  final uri = Uri(scheme: 'tel', path: '+79060424241');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri);
                  }
                },
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  minimumSize: Size.zero,
                ),
                child: const Text('Позвонить'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onOpenTickets,
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: const Text('Обращения в поддержку'),
            ),
          ),
        ],
      ),
    );
  }
}
