import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/services/payment_service.dart';
import '../../core/theme/app_theme.dart';
import '../../features/booking/providers/booking_provider.dart';
import '../../features/profile/providers/profile_provider.dart';
import '../../models/payment_method.dart';
import '../../shared/utils/app_snackbar.dart';
import '../../shared/utils/formatters.dart';
import '../../shared/widgets/action_buttons.dart';
import '../../shared/widgets/app_bar_back.dart';
import '../../shared/widgets/fare_breakdown_sheet.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  late final TextEditingController _promoCtrl;
  bool _applyingPromo = false;

  @override
  void initState() {
    super.initState();
    final booking = context.read<BookingProvider>().booking;
    final profile = context.read<ProfileProvider>();
    final initial =
        booking.promoCode.isNotEmpty ? booking.promoCode : profile.promoCode;
    _promoCtrl = TextEditingController(text: initial);

    if (booking.discountPercent <= 0 && profile.promoDiscountPercent > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<BookingProvider>().applyPromo(
              code: profile.promoCode,
              discountPercent: profile.promoDiscountPercent,
            );
      });
    }
  }

  @override
  void dispose() {
    _promoCtrl.dispose();
    super.dispose();
  }

  Future<void> _applyPromo(
      BookingProvider booking, ProfileProvider profile) async {
    final code = _promoCtrl.text.trim();
    if (code.isEmpty) {
      showAppSnackBar(context, 'Введите промокод', isError: true);
      return;
    }
    setState(() => _applyingPromo = true);
    try {
      final discount = await profile.activatePromo(code);
      if (!mounted) return;
      booking.applyPromo(code: code, discountPercent: discount);
      showAppSnackBar(context, 'Промокод применён: −$discount%');
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Промокод не найден или недействителен',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _applyingPromo = false);
    }
  }

  Future<void> _submitOrder(
      BuildContext context, BookingProvider provider) async {
    final method = provider.booking.paymentMethod;
    final payment = PaymentService.instance;
    if (method != PaymentMethod.cash && !await payment.isAvailable(method)) {
      if (!context.mounted) return;
      showAppSnackBar(
        context,
        payment.unavailableMessage(method),
        isError: true,
      );
      return;
    }

    final success = await provider.submitOrder();
    if (!context.mounted) return;

    if (success) {
      final orderId = provider.booking.orderId;
      if (method != PaymentMethod.cash && orderId != null) {
        final paymentResult = await payment.startForOrder(
          orderId: orderId,
          method: method,
        );
        if (!context.mounted) return;
        if (paymentResult == PaymentHandleResult.unavailable) {
          showAppSnackBar(
            context,
            'Заказ создан, но платёжную страницу открыть не удалось',
            isError: true,
          );
        }
      }
      if (!context.mounted) return;
      context.push(AppRoutes.confirmation);
      return;
    }

    final error = provider.booking.submitError ?? 'Не удалось создать заказ';
    showAppSnackBar(context, error, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBarWithBack(context, title: 'Способ оплаты'),
      body: Consumer2<BookingProvider, ProfileProvider>(
        builder: (context, provider, profile, _) {
          final booking = provider.booking;
          final tariff = booking.selectedTariff;
          final discount = booking.discountPercent > 0
              ? booking.discountPercent
              : profile.promoDiscountPercent;

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: AppTheme.softCard(context),
                      child: Row(
                        children: [
                          Icon(
                            booking.serviceType.icon,
                            size: 22,
                            color: AppColors.purple,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  booking.serviceType.label,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  '${booking.fromAddress} → ${booking.toAddress}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...PaymentMethod.values.map(
                      (method) => _PaymentOption(
                        method: method,
                        groupValue: booking.paymentMethod,
                        onTap: () => provider.selectPaymentMethod(method),
                      ),
                    ),
                    if (booking.paymentMethod != PaymentMethod.cash)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Доступность онлайн-оплаты проверяется безопасно на сервере перед заказом',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'Промокод',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _promoCtrl,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              hintText: 'Введите код',
                              prefixIcon:
                                  const Icon(Icons.local_offer_outlined),
                              suffixIcon: booking.discountPercent > 0
                                  ? IconButton(
                                      tooltip: 'Сбросить',
                                      onPressed: () {
                                        provider.clearPromo();
                                        _promoCtrl.clear();
                                      },
                                      icon: const Icon(Icons.close),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 56,
                          child: FilledButton(
                            onPressed: _applyingPromo
                                ? null
                                : () => _applyPromo(provider, profile),
                            child: Text(_applyingPromo ? '…' : 'ОК'),
                          ),
                        ),
                      ],
                    ),
                    if (booking.discountPercent > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Скидка ${booking.discountPercent}% по коду ${booking.promoCode}',
                        style: const TextStyle(
                          color: AppColors.success,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (tariff != null)
                      Material(
                        color: AppColors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: () => showFareBreakdownSheet(
                            context,
                            booking: booking,
                            discountPercent: discount,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Тариф',
                                      style: TextStyle(
                                          color: AppColors.textSecondary),
                                    ),
                                    Text(
                                      tariff.name,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Ставка',
                                      style: TextStyle(
                                          color: AppColors.textSecondary),
                                    ),
                                    Text(
                                      formatRate(tariff.clientRatePerKm),
                                      style: const TextStyle(
                                        color: AppColors.gold,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                Divider(height: 24, color: AppColors.divider),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Примерная стоимость',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      booking.estimatedPrice != null
                                          ? formatPrice(booking.estimatedPrice!)
                                          : '—',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.gold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.receipt_long_outlined,
                                      size: 16,
                                      color: AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Подробный расчёт',
                                      style: TextStyle(
                                        color: AppColors.purple,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(
                                      Icons.chevron_right,
                                      size: 18,
                                      color: AppColors.textMuted,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: booking.isSubmitting
                    ? const SizedBox(
                        height: 52,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : PurpleActionButton(
                        label: 'Заказать',
                        enabled: booking.isReadyToOrder,
                        onPressed: () => _submitOrder(context, provider),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    required this.method,
    required this.groupValue,
    required this.onTap,
  });

  final PaymentMethod method;
  final PaymentMethod groupValue;
  final VoidCallback onTap;

  bool get selected => method == groupValue;

  IconData get _icon => switch (method) {
        PaymentMethod.cash => Icons.payments_outlined,
        PaymentMethod.card => Icons.credit_card_outlined,
        PaymentMethod.sbp => Icons.qr_code_2_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.purple.withValues(alpha: 0.1)
                : AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.purple : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppColors.purple : AppColors.textMuted,
                    width: 2,
                  ),
                ),
                child: selected
                    ? Center(
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: AppColors.purple,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Icon(_icon,
                  color: selected ? AppColors.purple : AppColors.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(method.label, style: const TextStyle(fontSize: 16)),
              ),
              if (method != PaymentMethod.cash)
                Text(
                  'онлайн',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
