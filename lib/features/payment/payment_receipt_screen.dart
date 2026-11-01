import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/payment_method.dart';
import '../../shared/utils/formatters.dart';
import '../../shared/widgets/action_buttons.dart';
import '../booking/providers/booking_provider.dart';
import 'rate_trip_screen.dart';

class PaymentReceiptArgs {
  const PaymentReceiptArgs({
    required this.orderId,
    required this.fromAddress,
    required this.toAddress,
    this.price,
    this.paymentMethod = PaymentMethod.cash,
  });

  final String orderId;
  final String fromAddress;
  final String toAddress;
  final double? price;
  final PaymentMethod paymentMethod;
}

/// Чек после поездки: маршрут, цена, способ оплаты, id заказа.
class PaymentReceiptScreen extends StatelessWidget {
  const PaymentReceiptScreen({super.key, required this.args});

  final PaymentReceiptArgs args;

  void _repeat(BuildContext context) {
    context.read<BookingProvider>().prefillFromTrip(
          fromAddress: args.fromAddress,
          toAddress: args.toAddress,
          paymentMethod: args.paymentMethod,
        );
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Чек поездки'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  size: 36,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Поездка завершена',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Спасибо, что выбрали КОРОЛИ ДОРОГ',
                style: TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _Row(label: 'Откуда', value: args.fromAddress),
                    const SizedBox(height: 12),
                    _Row(label: 'Куда', value: args.toAddress),
                    Divider(height: 28, color: AppColors.divider),
                    _Row(
                      label: 'Оплата',
                      value: args.paymentMethod.label,
                    ),
                    const SizedBox(height: 12),
                    _Row(
                      label: 'Стоимость',
                      value: args.price != null
                          ? formatPriceExact(args.price!)
                          : '—',
                      highlight: true,
                    ),
                    const SizedBox(height: 12),
                    _Row(label: 'Заказ', value: args.orderId),
                  ],
                ),
              ),
              const Spacer(),
              GoldActionButton(
                label: 'Готово',
                onPressed: () {
                  context.read<BookingProvider>().reset();
                  context.go(AppRoutes.home);
                },
              ),
              const SizedBox(height: 12),
              PurpleActionButton(
                label: 'Оценить поездку',
                onPressed: () {
                  context.pushReplacement(
                    AppRoutes.rateTrip,
                    extra: RateTripArgs(
                      orderId: args.orderId,
                      fromAddress: args.fromAddress,
                      toAddress: args.toAddress,
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _repeat(context),
                child: const Text('Повторить заказ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w500,
              color: highlight ? AppColors.gold : AppColors.textPrimary,
              fontSize: highlight ? 18 : 14,
            ),
          ),
        ),
      ],
    );
  }
}
