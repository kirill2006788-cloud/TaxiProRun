import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/legal_texts.dart';
import '../../shared/widgets/action_buttons.dart';
import '../../shared/widgets/premium_chrome.dart';
import '../auth/providers/auth_provider.dart';
import '../profile/legal_document_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  void _openLegal(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalDocumentScreen(title: title, body: body),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: FadeSlideIn(
              child: Column(
                children: [
                  const Spacer(),
                  const _BrandMark(),
                  const SizedBox(height: 24),
                  Text(
                    'КОРОЛИ ДОРОГ',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Такси и трезвый водитель',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: context.isDarkTheme
                              ? AppColors.gold
                              : AppColors.goldDark,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const Spacer(),
                  GoldActionButton(
                    label: 'Начать',
                    onPressed: () async {
                      await context.read<AuthProvider>().completeOnboarding();
                      if (context.mounted) {
                        context.go(AppRoutes.home);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _OnboardingLegalLinks(
                    onPrivacy: () => _openLegal(
                      context,
                      title: LegalTexts.privacyPolicyTitle,
                      body: LegalTexts.privacyPolicy,
                    ),
                    onTerms: () => _openLegal(
                      context,
                      title: LegalTexts.termsTitle,
                      body: LegalTexts.termsOfUse,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingLegalLinks extends StatelessWidget {
  const _OnboardingLegalLinks({
    required this.onPrivacy,
    required this.onTerms,
  });

  final VoidCallback onPrivacy;
  final VoidCallback onTerms;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: context.palette.textMuted,
          height: 1.35,
        );
    final link = base?.copyWith(
      color: AppColors.purple,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.purple.withValues(alpha: 0.55),
    );

    return Text.rich(
      TextSpan(
        style: base,
        children: [
          const TextSpan(text: 'Продолжая, вы принимаете '),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: onTerms,
              child: Text('условия сервиса', style: link),
            ),
          ),
          const TextSpan(text: ' и '),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: onPrivacy,
              child: Text('политику конфиденциальности', style: link),
            ),
          ),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.gold.withValues(alpha: 0.32),
            AppColors.purple.withValues(alpha: 0.4),
          ],
        ),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.65),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple
                .withValues(alpha: context.isDarkTheme ? 0.28 : 0.16),
            blurRadius: 28,
            spreadRadius: 1,
          ),
        ],
      ),
      child: const Icon(
        Icons.directions_car_filled_rounded,
        size: 52,
        color: AppColors.gold,
      ),
    );
  }
}
