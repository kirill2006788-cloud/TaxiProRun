import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/premium_chrome.dart';

class ProfileSectionLabel extends StatelessWidget {
  const ProfileSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.textMuted,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class ProfileMenuCard extends StatelessWidget {
  const ProfileMenuCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.softCard(context),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class ProfileMenuTile extends StatelessWidget {
  const ProfileMenuTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
    this.iconColor,
    this.showDivider = true,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;
  final Color? iconColor;
  final bool showDivider;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final accent = iconColor ?? AppColors.purple;
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          title: Text(title),
          subtitle: subtitle != null
              ? Text(
                  subtitle!,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                )
              : null,
          trailing: trailing ??
              (showChevron
                  ? Icon(Icons.chevron_right_rounded, color: AppColors.textMuted)
                  : null),
          onTap: onTap,
        ),
        if (showDivider)
          Divider(height: 1, indent: 68, color: AppColors.divider),
      ],
    );
  }
}

class ProfileEmptyState extends StatelessWidget {
  const ProfileEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return PremiumEmptyState(
      icon: icon,
      title: title,
      subtitle: subtitle,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}

class ProfileBonusBanner extends StatelessWidget {
  const ProfileBonusBanner({
    super.key,
    required this.balance,
    this.onTap,
  });

  final int balance;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [
                AppColors.gold.withValues(alpha: 0.18),
                AppColors.backgroundSecondary,
              ],
            ),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.card_giftcard, color: AppColors.gold),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Бонусный баланс',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      balance > 0 ? 'Доступно $balance ₽' : 'Приглашайте друзей',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$balance ₽',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileFormCard extends StatelessWidget {
  const ProfileFormCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.softCard(context),
      child: child,
    );
  }
}
