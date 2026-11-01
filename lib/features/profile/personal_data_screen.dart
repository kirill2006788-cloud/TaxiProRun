import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/action_buttons.dart';
import 'providers/profile_provider.dart';
import 'widgets/profile_widgets.dart';

class PersonalDataScreen extends StatefulWidget {
  const PersonalDataScreen({super.key});

  @override
  State<PersonalDataScreen> createState() => _PersonalDataScreenState();
}

class _PersonalDataScreenState extends State<PersonalDataScreen> {
  late final TextEditingController _displayNameController;
  late final TextEditingController _fullNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _referralController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = context.read<ProfileProvider>();
    _displayNameController = TextEditingController(text: profile.displayName);
    _fullNameController = TextEditingController(text: profile.fullName);
    _phoneController = TextEditingController(text: profile.phone);
    _referralController = TextEditingController();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _referralController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Личные данные'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Consumer<ProfileProvider>(
        builder: (context, profile, _) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text(
                'Данные сохраняются локально и синхронизируются с сервером после авторизации.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ProfileFormCard(
                child: Column(
                  children: [
                    TextField(
                      controller: _displayNameController,
                      decoration: const InputDecoration(
                        labelText: 'Имя',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _fullNameController,
                      decoration: const InputDecoration(
                        labelText: 'ФИО / отчество',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        hintText: '+7 (999) 123-45-67',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    if (profile.canUseReferralCode) ...[
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Если вас пригласил друг — введите его код. Тогда ему засчитается приглашение.',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.35),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _referralController,
                        decoration: const InputDecoration(
                          labelText: 'Код пригласившего',
                          prefixIcon: Icon(Icons.card_giftcard_outlined),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Код пригласившего уже был введён: ${profile.usedReferralCode ?? ''}',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              PurpleActionButton(
                label: _saving ? 'Сохранение…' : 'Сохранить',
                onPressed: _saving
                    ? null
                    : () async {
                        setState(() => _saving = true);
                        try {
                          await profile.savePersonalData(
                            displayName: _displayNameController.text,
                            fullName: _fullNameController.text,
                            referralCode: profile.canUseReferralCode
                                ? _referralController.text.trim()
                                : null,
                          );
                          await profile.updatePhone(_phoneController.text);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Данные сохранены')),
                            );
                            context.pop();
                          }
                        } finally {
                          if (mounted) setState(() => _saving = false);
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
