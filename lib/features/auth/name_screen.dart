import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/profile/profile_keys.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/action_buttons.dart';
import '../../shared/widgets/premium_chrome.dart';
import '../profile/providers/profile_provider.dart';
import 'providers/auth_provider.dart';

class NameScreen extends StatefulWidget {
  const NameScreen({super.key});

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit(AuthProvider auth) async {
    auth.clearError();
    final ok = await auth.saveName(_nameController.text);
    if (!mounted || !ok) return;

    final profile = context.read<ProfileProvider>();
    final prefs = await SharedPreferences.getInstance();
    await profile.applyAuthSession(
      token: auth.token!,
      phone: prefs.getString(ProfileKeys.phone),
      displayName: prefs.getString(ProfileKeys.displayName),
      fullName: prefs.getString(ProfileKeys.fullName),
    );
    if (!mounted) return;

    if (auth.onboardingCompleted) {
      context.go(AppRoutes.home);
    } else {
      context.go(AppRoutes.onboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AmbientBackground(
        intensity: 0.85,
        child: SafeArea(
          child: Consumer<AuthProvider>(
            builder: (context, auth, _) {
              return FadeSlideIn(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(flex: 1),
                      Text(
                        'КОРОЛИ ДОРОГ',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              color: context.isDarkTheme
                                  ? AppColors.gold
                                  : AppColors.goldDark,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Как к вам обращаться?',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Укажите имя для заказов и поездок',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 32),
                      TextField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        autofocus: true,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 17,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Имя',
                          hintText: 'Например, Анна',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        onChanged: (_) => auth.clearError(),
                        onSubmitted: auth.busy ? null : (_) => _submit(auth),
                      ),
                      if (auth.error != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          auth.error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ],
                      const Spacer(flex: 2),
                      GoldActionButton(
                        label: 'Продолжить',
                        loading: auth.busy,
                        onPressed: () => _submit(auth),
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
