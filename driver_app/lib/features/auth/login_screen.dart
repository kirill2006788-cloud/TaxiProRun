import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';
import '../../providers/auth_provider.dart';
import '../info/info_screens.dart';
import '../../shared/widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();

  bool _codeStage = false;
  bool _requesting = false;
  bool _verifying = false;
  String? _noticeMessage;
  bool _noticeIsError = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    setState(() {
      _requesting = true;
      _noticeMessage = null;
    });
    try {
      await context.read<AuthProvider>().requestOtp(_phoneController.text);
      if (!mounted) return;
      setState(() {
        _codeStage = true;
        _noticeIsError = false;
        _noticeMessage = 'Код отправлен. Введите 4 цифры из SMS.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _noticeIsError = true;
        _noticeMessage = context.read<AuthProvider>().requestOtpErrorMessage(e);
      });
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  Future<void> _verifyOtp() async {
    setState(() {
      _verifying = true;
      _noticeMessage = null;
    });
    try {
      await context.read<AuthProvider>().verifyOtp(
            phoneInput: _phoneController.text,
            codeInput: _codeController.text,
          );
      if (!mounted) return;
      context.read<SettingsProvider>().markLoggedIn();
      await context.read<DriverProvider>().loadProfile();
      if (!mounted) return;
      final status = context.read<DriverProvider>().profile.registrationStatus;
      if (status == 'completed') {
        context.go(AppRoutes.orders);
      } else if (status == 'pending' || status == 'rejected') {
        context.go(AppRoutes.registrationStatus);
      } else {
        context.go(AppRoutes.registration);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _noticeIsError = true;
        _noticeMessage = context.read<AuthProvider>().otpErrorMessage(e);
      });
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: t.isDark
                ? const [
                    Color(0xFF141218),
                    AppColors.backgroundPrimary,
                    Color(0xFF0A0A0C),
                  ]
                : const [
                    Color(0xFFF8F6FF),
                    AppColors.lightBackgroundPrimary,
                    Color(0xFFF0F2F8),
                  ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),
                Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.92, end: 1),
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutCubic,
                    builder: (context, scale, child) {
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: Container(
                      width: 96,
                      height: 96,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.18),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.18),
                            blurRadius: 28,
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
                ),
                const SizedBox(height: 22),
                Text(
                  'КОРОЛИ ДОРОГ',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: t.isDark ? AppColors.gold : AppColors.goldDark,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Вход водителя',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: t.textSecondary, fontSize: 16),
                ),
                const Spacer(),
                if (_noticeMessage != null) ...[
                  _LoginNotice(
                    message: _noticeMessage!,
                    isError: _noticeIsError,
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: t.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Телефон',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                if (_codeStage) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: t.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Код (4 цифры)',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                PrimaryGoldButton(
                  label: _codeStage ? 'Войти' : 'Получить код',
                  loading: _requesting || _verifying,
                  onPressed: _codeStage ? _verifyOtp : _requestOtp,
                ),
                if (_codeStage) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: _requesting ? null : _requestOtp,
                        child: const Text('Отправить ещё раз'),
                      ),
                      TextButton(
                        onPressed: _requesting
                            ? null
                            : () {
                                setState(() {
                                  _codeStage = false;
                                  _codeController.clear();
                                  _noticeMessage = null;
                                });
                              },
                        child: const Text('Изменить номер'),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                _LoginLegalConsent(
                  onPrivacy: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => LegalDocumentScreen.privacy(),
                      ),
                    );
                  },
                  onAgreement: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => LegalDocumentScreen.agreement(),
                      ),
                    );
                  },
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginNotice extends StatelessWidget {
  const _LoginNotice({
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = isError ? AppColors.error : AppColors.success;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: t.isDark ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.mark_email_read_outlined,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginLegalConsent extends StatelessWidget {
  const _LoginLegalConsent({
    required this.onPrivacy,
    required this.onAgreement,
  });

  final VoidCallback onPrivacy;
  final VoidCallback onAgreement;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final base = TextStyle(
      color: t.textMuted,
      fontSize: 12,
      height: 1.35,
    );
    final link = base.copyWith(
      color: AppColors.purple,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.purple.withValues(alpha: 0.55),
    );

    return Text.rich(
      TextSpan(
        style: base,
        children: [
          const TextSpan(text: 'Регистрируясь, вы соглашаетесь с '),
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
              onTap: onAgreement,
              child: Text('соглашением водителя', style: link),
            ),
          ),
          const TextSpan(text: '.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}
