import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../widgets.dart';

Future<void> showTripSummarySheet(
  BuildContext context, {
  required DriverOrder order,
}) {
  final gross = order.priceFinal ?? order.price;
  final commissionAmount = order.commissionAmount?.toDouble() ??
      (order.commissionPercent != null
          ? gross * (order.commissionPercent! / 100)
          : gross * 0.15);
  final commissionPct = order.commissionPercent ??
      (gross > 0 ? (commissionAmount / gross * 100) : 15);
  final net = (gross - commissionAmount).clamp(0, double.infinity);

  return showModalBottomSheet<void>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: context.tokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final t = ctx.tokens;
      final gold = t.isDark ? AppColors.gold : AppColors.goldDark;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Поездка завершена',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: t.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${order.pickup} → ${order.dropoff}',
                style: TextStyle(color: t.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              _SumRow(label: 'Стоимость поездки', value: formatMoney(gross)),
              _SumRow(
                label: 'Комиссия сервиса · ${commissionPct.toStringAsFixed(0)}%',
                value: '−${formatMoney(commissionAmount)}',
                valueColor: AppColors.error,
              ),
              _SumRow(
                label: 'Чаевые',
                value: '—',
                valueColor: t.textMuted,
              ),
              Divider(height: 24, color: t.border),
              _SumRow(
                label: 'К выплате',
                value: formatMoney(net.toDouble()),
                bold: true,
                valueColor: gold,
              ),
              if (order.paymentStatus != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Оплата: ${order.paymentStatusLabel}',
                  style: TextStyle(color: t.textMuted, fontSize: 13),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Готово'),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _SumRow extends StatelessWidget {
  const _SumRow({
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
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: bold ? t.textPrimary : t.textSecondary,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                fontSize: bold ? 16 : 14,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: bold ? 20 : 14,
              color: valueColor ?? t.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
