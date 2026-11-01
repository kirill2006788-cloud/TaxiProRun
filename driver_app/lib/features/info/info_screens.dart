import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../data/legal_texts.dart';

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  factory LegalDocumentScreen.privacy() {
    return const LegalDocumentScreen(
      title: LegalTexts.privacyPolicyTitle,
      body: LegalTexts.privacyPolicy,
    );
  }

  factory LegalDocumentScreen.agreement() {
    return const LegalDocumentScreen(
      title: LegalTexts.driverAgreementTitle,
      body: LegalTexts.driverAgreement,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Text(
          body,
          style: TextStyle(
            color: context.tokens.textSecondary,
            fontSize: 14,
            height: 1.55,
          ),
        ),
      ),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const version = '1.0.0';
  static const buildNumber = '1';
  static const versionLabel = '$version ($buildNumber)';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('О приложении')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.purple, AppColors.goldDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: AppColors.gold, width: 2),
              ),
              child: const Center(
                child: Text(
                  'КД',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'КОРОЛИ ДОРОГ',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.gold,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Приложение для водителей',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.tokens.textSecondary),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.tokens.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.tokens.border),
            ),
            child: const Column(
              children: [
                _AboutRow(label: 'Версия', value: versionLabel),
                Divider(height: 24),
                _AboutRow(label: 'Сборка', value: buildNumber),
                Divider(height: 24),
                _AboutRow(label: 'Пакет', value: 'com.korolidorog.driver'),
                Divider(height: 24),
                _AboutRow(label: 'Режим', value: 'Демо / API'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '© 2026 КОРОЛИ ДОРОГ. Все права защищены.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.tokens.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: context.tokens.textMuted)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: context.tokens.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
