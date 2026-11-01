import 'package:flutter/material.dart';

import '../../core/pricing/fare_calculator.dart';
import '../../core/theme/app_theme.dart';
import '../../models/booking.dart';
import '../utils/formatters.dart';

class FareBreakdown {
  const FareBreakdown({
    required this.base,
    required this.distance,
    required this.options,
    required this.discount,
    required this.total,
    required this.distanceKm,
    this.discountPercent = 0,
  });

  final double base;
  final double distance;
  final double options;
  final double discount;
  final double total;
  final double distanceKm;
  final int discountPercent;

  static double distanceKmFor(Booking booking) =>
      FareCalculator.distanceKmForBooking(booking);

  static FareBreakdown fromBooking(Booking booking, {int discountPercent = 0}) {
    final quote = FareCalculator.fromBooking(
      booking,
      discountPercent: discountPercent,
    );
    return FareBreakdown(
      base: quote.base,
      distance: quote.distance,
      options: quote.options,
      discount: quote.discount,
      total: quote.total,
      distanceKm: quote.distanceKm,
      discountPercent: quote.discountPercent,
    );
  }
}

Future<void> showFareBreakdownSheet(
  BuildContext context, {
  required Booking booking,
  int discountPercent = 0,
}) {
  final fare = FareBreakdown.fromBooking(
    booking,
    discountPercent: discountPercent,
  );

  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    backgroundColor: AppColors.backgroundSecondary,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Детали стоимости',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              _FareRow(label: 'Подача', value: formatPrice(fare.base)),
              _FareRow(
                label: 'Путь · ${fare.distanceKm.toStringAsFixed(0)} км',
                value: formatPrice(fare.distance),
              ),
              if (fare.options > 0)
                _FareRow(label: 'Опции', value: formatPrice(fare.options)),
              if (fare.discount > 0)
                _FareRow(
                  label: 'Скидка · ${fare.discountPercent}%',
                  value: '−${formatPrice(fare.discount)}',
                  valueColor: AppColors.success,
                ),
              Divider(height: 24, color: AppColors.divider),
              _FareRow(
                label: 'Итого',
                value: formatPrice(fare.total),
                bold: true,
                valueColor: AppColors.gold,
              ),
              const SizedBox(height: 8),
              Text(
                'Ориентировочная цена · может измениться по факту маршрута',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Понятно'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _FareRow extends StatelessWidget {
  const _FareRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: bold ? AppColors.textPrimary : AppColors.textSecondary,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                fontSize: bold ? 16 : 14,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: bold ? 18 : 14,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
