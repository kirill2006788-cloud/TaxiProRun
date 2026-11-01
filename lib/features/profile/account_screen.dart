import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../shared/widgets/action_buttons.dart';
import 'providers/profile_provider.dart';
import 'widgets/profile_widgets.dart';

/// Единый экран аккаунта: имя, ФИО, телефон и код приглашения.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
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
        title: const Text('Учётная запись'),
        leading: IconButton(
          tooltip: 'Назад',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Consumer<ProfileProvider>(
        builder: (context, profile, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(
              'Здесь собраны все данные аккаунта.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            ProfileFormCard(
              child: Column(
                children: [
                  TextField(
                    controller: _displayNameController,
                    decoration: const InputDecoration(
                      labelText: 'Имя или никнейм',
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
                      labelText: 'Номер телефона',
                      hintText: '+7 (999) 123-45-67',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  if (profile.canUseReferralCode) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _referralController,
                      decoration: const InputDecoration(
                        labelText: 'Код пригласившего',
                        prefixIcon: Icon(Icons.card_giftcard_outlined),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Код уже применён: ${profile.usedReferralCode ?? ''}',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            PurpleActionButton(
              label: _saving ? 'Сохранение…' : 'Сохранить',
              onPressed: _saving ? null : () => _save(profile),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(ProfileProvider profile) async {
    setState(() => _saving = true);
    try {
      await profile.savePersonalData(
        displayName: _displayNameController.text,
        fullName: _fullNameController.text,
        referralCode:
            profile.canUseReferralCode ? _referralController.text.trim() : null,
      );
      await profile.updatePhone(_phoneController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Данные сохранены')),
      );
      context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
