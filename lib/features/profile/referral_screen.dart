import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/action_buttons.dart';
import 'providers/profile_provider.dart';
import 'widgets/profile_widgets.dart';

class ReferralScreen extends StatelessWidget {
  const ReferralScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Пригласить друзей'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Consumer<ProfileProvider>(
        builder: (context, profile, _) {
          final referralCode = profile.effectiveReferralCode;
          final progress = profile.referralCount % 3 / 3;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              ProfileFormCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ваш код приглашения',
                      style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            referralCode.isNotEmpty ? referralCode : 'Загрузка…',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Копировать',
                          onPressed: referralCode.isEmpty
                              ? null
                              : () async {
                                  await Clipboard.setData(ClipboardData(text: referralCode));
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Код скопирован')),
                                    );
                                  }
                                },
                          icon: const Icon(Icons.copy_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ProfileBonusBanner(balance: profile.bonusBalance),
              const SizedBox(height: 16),
              ProfileFormCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Приглашено друзей: ${profile.referralCount} / 3',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: AppColors.backgroundElevated,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.gold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Как это работает?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 12),
                    const _ReferralStep(number: '1', text: 'Поделитесь кодом с друзьями'),
                    const SizedBox(height: 8),
                    const _ReferralStep(number: '2', text: 'Друг вводит код в личных данных'),
                    const SizedBox(height: 8),
                    const _ReferralStep(number: '3', text: 'За каждые 3 друга — 500 ₽ на баланс'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              PurpleActionButton(
                label: 'Поделиться кодом',
                onPressed: referralCode.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(ClipboardData(
                          text: 'Присоединяйся к КОРОЛИ ДОРОГ! Мой код: $referralCode',
                        ));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Текст скопирован')),
                          );
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReferralStep extends StatelessWidget {
  const _ReferralStep({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.purple.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Text(number, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: AppColors.textSecondary))),
      ],
    );
  }
}
