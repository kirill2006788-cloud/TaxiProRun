import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/session/active_order_store.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../features/booking/providers/booking_provider.dart';
import '../../shared/utils/app_snackbar.dart';
import '../../shared/utils/formatters.dart';
import '../../shared/widgets/action_buttons.dart';
import '../../shared/widgets/cancel_reason_sheet.dart';

class ConfirmationScreen extends StatefulWidget {
  const ConfirmationScreen({super.key});

  @override
  State<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends State<ConfirmationScreen> {
  bool _canceling = false;

  Future<void> _cancelOrder(BookingProvider provider) async {
    final reason = await showCancelReasonSheet(context);
    if (reason == null || !mounted) return;

    final orderId = provider.booking.orderId;
    if (orderId == null || orderId.isEmpty) {
      provider.reset();
      if (mounted) context.go(AppRoutes.home);
      return;
    }

    setState(() => _canceling = true);
    try {
      await provider.apiServices.order.cancelOrder(
        orderId,
        reason: reason,
      );
      await ActiveOrderStore.clear();
      if (!mounted) return;
      provider.reset();
      showAppSnackBar(context, 'Заказ отменён');
      context.go(AppRoutes.home);
    } on ApiException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.message, isError: true);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, 'Не удалось отменить заказ', isError: true);
    } finally {
      if (mounted) setState(() => _canceling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<BookingProvider>(
          builder: (context, provider, _) {
            final booking = provider.booking;
            final tariff = booking.selectedTariff;

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Spacer(),
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: AppColors.purple.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.purple, width: 2),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 48,
                      color: AppColors.purple,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Заказ создан!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    booking.date != null &&
                            booking.date!.isAfter(DateTime.now())
                        ? 'Предзаказ на ${formatDateTime(booking.date!)}'
                        : 'Ищем ближайшего водителя…',
                    style: TextStyle(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DetailRow(
                          icon: Icons.trip_origin,
                          label: 'Откуда',
                          value: booking.fromAddress,
                        ),
                        const SizedBox(height: 12),
                        _DetailRow(
                          icon: Icons.location_on,
                          label: 'Куда',
                          value: booking.toAddress,
                        ),
                        if (booking.stops.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _DetailRow(
                            icon: Icons.place_outlined,
                            label: 'Остановки',
                            value: booking.stops.join(', '),
                          ),
                        ],
                        Divider(height: 24, color: AppColors.divider),
                        if (tariff != null)
                          _DetailRow(
                            icon: Icons.local_taxi_outlined,
                            label: 'Тариф',
                            value: '${tariff.name} · ${tariff.clientRateLabel}',
                          ),
                        const SizedBox(height: 12),
                        _DetailRow(
                          icon: Icons.category_outlined,
                          label: 'Услуга',
                          value: booking.serviceType.label,
                        ),
                        const SizedBox(height: 12),
                        _DetailRow(
                          icon: Icons.payments_outlined,
                          label: 'Оплата',
                          value: booking.paymentMethod.label,
                        ),
                        if (booking.estimatedPrice != null) ...[
                          const SizedBox(height: 12),
                          _DetailRow(
                            icon: Icons.attach_money,
                            label: 'Стоимость',
                            value: formatPrice(booking.estimatedPrice!),
                          ),
                        ],
                        if (booking.orderId != null) ...[
                          Divider(height: 24, color: AppColors.divider),
                          _DetailRow(
                            icon: Icons.tag_outlined,
                            label: 'Номер заказа',
                            value: booking.orderId!,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _canceling ? null : () => _cancelOrder(provider),
                    child: Text(
                      _canceling ? 'Отмена…' : 'Отменить заказ',
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ),
                  const SizedBox(height: 12),
                  PurpleActionButton(
                    label: 'К поездке',
                    onPressed: () => context.go(AppRoutes.activeTrip),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              Text(value, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }
}
