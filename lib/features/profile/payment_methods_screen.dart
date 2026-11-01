import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services/payment_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/payment_method.dart';

class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Способы оплаты'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: FutureBuilder<List<bool>>(
        future: Future.wait([
          PaymentService.instance.isAvailable(PaymentMethod.card),
          PaymentService.instance.isAvailable(PaymentMethod.sbp),
        ]),
        builder: (context, snapshot) {
          final online = snapshot.data ?? const [false, false];
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Способ оплаты выбирается при оформлении каждого заказа',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              const _PaymentCard(
                method: PaymentMethod.cash,
                subtitle: 'Оплата водителю после поездки',
                enabled: true,
              ),
              _PaymentCard(
                method: PaymentMethod.card,
                subtitle: online[0]
                    ? 'Защищённая платёжная страница банка'
                    : 'Эквайринг ещё не подключён',
                enabled: online[0],
              ),
              _PaymentCard(
                method: PaymentMethod.sbp,
                subtitle: online[1]
                    ? 'Оплата через приложение вашего банка'
                    : 'СБП ещё не подключена',
                enabled: online[1],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.purple.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.purple.withValues(alpha: 0.25),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_outline_rounded, color: AppColors.purple),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Данные банковской карты не хранятся в приложении и вводятся только на странице банка.',
                        style: TextStyle(fontSize: 13, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.method,
    required this.subtitle,
    required this.enabled,
  });

  final PaymentMethod method;
  final String subtitle;
  final bool enabled;

  IconData get _icon => switch (method) {
        PaymentMethod.cash => Icons.payments_outlined,
        PaymentMethod.card => Icons.credit_card_outlined,
        PaymentMethod.sbp => Icons.qr_code_2_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(_icon, color: enabled ? AppColors.purple : AppColors.textMuted),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  method.label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          Icon(
            enabled ? Icons.check_circle_outline : Icons.schedule_outlined,
            color: enabled ? AppColors.success : AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}
