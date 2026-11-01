import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/action_buttons.dart';
import 'providers/profile_provider.dart';
import 'widgets/profile_widgets.dart';

class PromoScreen extends StatefulWidget {
  const PromoScreen({super.key});

  @override
  State<PromoScreen> createState() => _PromoScreenState();
}

class _PromoScreenState extends State<PromoScreen> {
  late final TextEditingController _controller;
  bool _activating = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: context.read<ProfileProvider>().promoCode);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Промокоды'),
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
              ProfileFormCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _controller,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Промокод',
                        prefixIcon: Icon(Icons.local_offer_outlined),
                        hintText: 'Например, KOROLI',
                      ),
                    ),
                    const SizedBox(height: 16),
                    PurpleActionButton(
                      label: _activating ? 'Активация…' : 'Активировать',
                      onPressed: _activating
                          ? null
                          : () async {
                              final code = _controller.text.trim();
                              if (code.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Введите промокод')),
                                );
                                return;
                              }
                              setState(() => _activating = true);
                              try {
                                final discount = await profile.activatePromo(code);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Промокод активирован: −$discount%')),
                                  );
                                }
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Промокод не найден или недействителен'),
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => _activating = false);
                              }
                            },
                    ),
                    if (profile.promoDiscountPercent > 0) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: AppColors.success),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Активна скидка: −${profile.promoDiscountPercent}%',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (ApiConfigStore.instance.useMockApi) ...[
                const SizedBox(height: 16),
                Text(
                  'Демо-коды (только mock API): KOROLI (−10%), WELCOME (−15%)',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
