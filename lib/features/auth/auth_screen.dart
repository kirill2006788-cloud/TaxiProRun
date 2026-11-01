import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/auth/phone_utils.dart';
import '../../core/profile/profile_keys.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/legal_texts.dart';
import '../../shared/widgets/action_buttons.dart';
import '../../shared/widgets/premium_chrome.dart';
import '../profile/legal_document_screen.dart';
import '../profile/providers/profile_provider.dart';
import 'providers/auth_provider.dart';

enum _AuthStep { phone, otp }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  _AuthStep _step = _AuthStep.phone;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp(AuthProvider auth) async {
    auth.clearError();
    try {
      await auth.requestOtp(_phoneController.text);
      if (!mounted) return;
      setState(() => _step = _AuthStep.otp);
    } catch (_) {}
  }

  Future<void> _syncProfile(BuildContext context, AuthProvider auth) async {
    final profile = context.read<ProfileProvider>();
    final prefs = await SharedPreferences.getInstance();
    await profile.applyAuthSession(
      token: auth.token!,
      phone: prefs.getString(ProfileKeys.phone),
      displayName: prefs.getString(ProfileKeys.displayName),
      fullName: prefs.getString(ProfileKeys.fullName),
    );
  }

  Future<void> _verifyOtp(AuthProvider auth) async {
    auth.clearError();
    try {
      await auth.verifyOtp(_codeController.text);
    } catch (_) {
      return;
    }
    if (!mounted) return;

    await _syncProfile(context, auth);
    if (!mounted) return;

    if (auth.needsName) {
      context.go(AppRoutes.authName);
    } else if (auth.onboardingCompleted) {
      context.go(AppRoutes.home);
    } else {
      context.go(AppRoutes.onboarding);
    }
  }

  void _backToPhone(AuthProvider auth) {
    auth.clearError();
    _codeController.clear();
    setState(() => _step = _AuthStep.phone);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: Consumer<AuthProvider>(
            builder: (context, auth, _) {
              return FadeSlideIn(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_step == _AuthStep.otp)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            onPressed:
                                auth.busy ? null : () => _backToPhone(auth),
                            icon: const Icon(Icons.arrow_back_rounded),
                            color: AppColors.textSecondary,
                          ),
                        ),
                      const Spacer(flex: 1),
                      Center(
                        child: Container(
                          width: 76,
                          height: 76,
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.18),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.gold.withValues(
                                  alpha: context.isDarkTheme ? 0.22 : 0.14,
                                ),
                                blurRadius: 22,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/branding/splash_logo.png',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'КОРОЛИ ДОРОГ',
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.headlineLarge?.copyWith(
                                  color: context.isDarkTheme
                                      ? AppColors.gold
                                      : AppColors.goldDark,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.6,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _step == _AuthStep.phone
                            ? 'Вход по номеру телефона'
                            : 'Код из SMS',
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: context.palette.textSecondary,
                                ),
                      ),
                      const SizedBox(height: 32),
                      if (_step == _AuthStep.phone) ...[
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [RussianPhoneInputFormatter()],
                          autofocus: true,
                          enabled: !auth.busy,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 17,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Телефон',
                            hintText: '+7 (___) ___-__-__',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                          onChanged: (_) => auth.clearError(),
                        ),
                      ] else ...[
                        Text(
                          'Отправили код на ${formatPhoneForDisplay(auth.phone)}',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _codeController,
                          keyboardType: TextInputType.number,
                          autofocus: true,
                          enabled: !auth.busy,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 28,
                            letterSpacing: 8,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Код (4–6 цифр)',
                            hintText: '••••',
                          ),
                          onChanged: (_) => auth.clearError(),
                          onSubmitted:
                              auth.busy ? null : (_) => _verifyOtp(auth),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: auth.canResendCode
                              ? TextButton(
                                  onPressed: auth.busy
                                      ? null
                                      : () => _requestOtp(auth),
                                  child: const Text('Отправить код повторно'),
                                )
                              : Text(
                                  'Повторная отправка через ${auth.resendSecondsRemaining} сек',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 14,
                                  ),
                                ),
                        ),
                      ],
                      if (auth.error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: AppColors.error,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  auth.error!,
                                  style: const TextStyle(
                                    color: AppColors.error,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Spacer(flex: 2),
                      if (_step == _AuthStep.phone)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _AuthLegalConsent(
                            onPrivacy: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const LegalDocumentScreen(
                                    title: LegalTexts.privacyPolicyTitle,
                                    body: LegalTexts.privacyPolicy,
                                  ),
                                ),
                              );
                            },
                            onTerms: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => const LegalDocumentScreen(
                                    title: LegalTexts.termsTitle,
                                    body: LegalTexts.termsOfUse,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      if (_step == _AuthStep.phone)
                        GoldActionButton(
                          label: 'Получить код',
                          loading: auth.busy,
                          onPressed: () => _requestOtp(auth),
                        )
                      else
                        PurpleActionButton(
                          label: 'Войти',
                          loading: auth.busy,
                          onPressed: () => _verifyOtp(auth),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AuthLegalConsent extends StatelessWidget {
  const _AuthLegalConsent({
    required this.onPrivacy,
    required this.onTerms,
  });

  final VoidCallback onPrivacy;
  final VoidCallback onTerms;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textMuted,
          height: 1.4,
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
          const TextSpan(text: 'Продолжая, вы соглашаетесь с '),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: onPrivacy,
              child: Text('политикой конфиденциальности', style: link),
            ),
          ),
          const TextSpan(text: ' и '),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: onTerms,
              child: Text('пользовательским соглашением', style: link),
            ),
          ),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
