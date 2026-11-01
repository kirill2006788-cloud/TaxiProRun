import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import 'package:provider/provider.dart';



import '../../core/router/app_router.dart';

import '../../core/theme/app_theme.dart';

import '../../models/models.dart';

import '../../providers/app_providers.dart';

import '../../shared/registration_status_badge.dart';

import '../../shared/widgets.dart';



class RegistrationStatusScreen extends StatefulWidget {

  const RegistrationStatusScreen({super.key});



  @override

  State<RegistrationStatusScreen> createState() =>

      _RegistrationStatusScreenState();

}



class _RegistrationStatusScreenState extends State<RegistrationStatusScreen> {

  bool _refreshing = false;



  @override

  void initState() {

    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {

      if (!mounted) return;

      context.read<DriverProvider>().refreshRegistrationStatus();

    });

  }



  Future<void> _refresh() async {

    setState(() => _refreshing = true);

    try {

      await context.read<DriverProvider>().refreshRegistrationStatus();

    } finally {

      if (mounted) setState(() => _refreshing = false);

    }

  }



  @override

  Widget build(BuildContext context) {

    final profile = context.watch<DriverProvider>().profile;

    final status = normalizeRegistrationStatus(profile.registrationStatus);

    final blocked = profile.registrationBlocked;

    final t = context.tokens;



    if (status == 'completed' && !blocked) {

      WidgetsBinding.instance.addPostFrameCallback((_) {

        if (context.mounted) context.go(AppRoutes.orders);

      });

    }



    final icon = switch (status) {

      'completed' => Icons.verified_rounded,

      'pending' => Icons.hourglass_top_rounded,

      'rejected' => Icons.edit_note_rounded,

      'blocked' => Icons.block_rounded,

      _ => Icons.drafts_outlined,

    };



    final iconColor = blocked || status == 'blocked'

        ? AppColors.error

        : switch (status) {

            'completed' => AppColors.success,

            'pending' => AppColors.warning,

            'rejected' => AppColors.error,

            _ => t.textMuted,

          };



    return Scaffold(

      appBar: AppBar(

        title: const Text('Статус регистрации'),

        actions: [

          IconButton(

            tooltip: 'Обновить',

            onPressed: _refreshing ? null : _refresh,

            icon: _refreshing

                ? const SizedBox(

                    width: 20,

                    height: 20,

                    child: CircularProgressIndicator(strokeWidth: 2),

                  )

                : const Icon(Icons.refresh_rounded),

          ),

        ],

      ),

      body: ListView(

        padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),

        children: [

          SectionCard(

            child: Column(

              children: [

                Container(

                  width: 96,

                  height: 96,

                  decoration: BoxDecoration(

                    shape: BoxShape.circle,

                    color: iconColor.withValues(alpha: 0.12),

                    border: Border.all(

                      color: iconColor.withValues(alpha: 0.35),

                    ),

                  ),

                  child: Icon(icon, size: 48, color: iconColor),

                ),

                const SizedBox(height: 18),

                Text(

                  registrationStatusTitle(status),

                  textAlign: TextAlign.center,

                  style: TextStyle(

                    color: t.textPrimary,

                    fontSize: 24,

                    fontWeight: FontWeight.w800,

                  ),

                ),

                const SizedBox(height: 10),

                RegistrationStatusBadge(status: status),

                const SizedBox(height: 16),

                Text(

                  registrationStatusSubtitle(profile),

                  textAlign: TextAlign.center,

                  style: TextStyle(

                    color: t.textSecondary,

                    height: 1.45,

                  ),

                ),

              ],

            ),

          ),

          const SizedBox(height: 16),

          if (blocked || status == 'blocked') ...[

            OutlinedButton.icon(

              onPressed: () => context.push(AppRoutes.support),

              icon: const Icon(Icons.support_agent_rounded),

              label: const Text('Написать в поддержку'),

            ),

          ],

          if (status == 'pending') ...[

            SectionCard(

              child: Row(

                children: [

                  const Icon(

                    Icons.admin_panel_settings_outlined,

                    color: AppColors.purple,

                  ),

                  const SizedBox(width: 12),

                  Expanded(

                    child: Text(

                      'Обычно проверка занимает до 24 часов. Мы уведомим вас после решения.',

                      style: TextStyle(color: t.textSecondary, height: 1.4),

                    ),

                  ),

                ],

              ),

            ),

          ],

          if (status == 'rejected') ...[

            ElevatedButton.icon(

              onPressed: () => context.go(AppRoutes.registration),

              icon: const Icon(Icons.edit_note_rounded),

              label: const Text('Исправить и отправить снова'),

            ),

          ],

          if (status == 'incomplete') ...[

            ElevatedButton(

              onPressed: () => context.go(AppRoutes.registration),

              child: const Text('Продолжить регистрацию'),

            ),

          ],

        ],

      ),

    );

  }

}

