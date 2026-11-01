import 'package:flutter/material.dart';

import '../../../core/services/payment_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/payment_method.dart';
import '../../../shared/widgets/action_buttons.dart';

Future<PaymentMethod?> showPaymentMethodSheet({
  required BuildContext context,
  required PaymentMethod current,
}) {
  return showModalBottomSheet<PaymentMethod>(
    context: context,
    useRootNavigator: true,
    backgroundColor: context.palette.bgSecondary,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) => _PaymentMethodSheet(current: current),
  );
}

class _PaymentMethodSheet extends StatefulWidget {
  const _PaymentMethodSheet({required this.current});

  final PaymentMethod current;

  @override
  State<_PaymentMethodSheet> createState() => _PaymentMethodSheetState();
}

class _PaymentMethodSheetState extends State<_PaymentMethodSheet> {
  late PaymentMethod _selected = widget.current;
  Map<PaymentMethod, bool>? _available;

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    final payment = PaymentService.instance;
    final card = await payment.isAvailable(PaymentMethod.card);
    final sbp = await payment.isAvailable(PaymentMethod.sbp);
    if (!mounted) return;
    setState(() {
      _available = {
        PaymentMethod.cash: true,
        PaymentMethod.card: card,
        PaymentMethod.sbp: sbp,
      };
      // If current method became unavailable, fall back to cash.
      if (_available![_selected] != true) {
        _selected = PaymentMethod.cash;
      }
    });
  }

  IconData _icon(PaymentMethod method) => switch (method) {
        PaymentMethod.cash => Icons.payments_outlined,
        PaymentMethod.card => Icons.credit_card_rounded,
        PaymentMethod.sbp => Icons.qr_code_2_rounded,
      };

  String _label(PaymentMethod method) => switch (method) {
        PaymentMethod.sbp => 'QR / СБП',
        PaymentMethod.cash => 'Наличными',
        PaymentMethod.card => 'Картой',
      };

  String? _subtitle(PaymentMethod method, bool enabled) {
    if (enabled) return null;
    return switch (method) {
      PaymentMethod.card ||
      PaymentMethod.sbp =>
        'Пока недоступно — эквайринг не подключён',
      PaymentMethod.cash => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final availability = _available;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Способ оплаты',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: p.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            if (availability == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              ...PaymentMethod.values.map((method) {
                final enabled = availability[method] == true;
                final selected = method == _selected && enabled;
                final subtitle = _subtitle(method, enabled);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: selected
                        ? AppColors.gold.withValues(alpha: 0.14)
                        : p.bgElevated,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: enabled
                          ? () => setState(() => _selected = method)
                          : null,
                      child: Opacity(
                        opacity: enabled ? 1 : 0.45,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _icon(method),
                                color:
                                    selected ? AppColors.gold : p.textSecondary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _label(method),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: p.textPrimary,
                                      ),
                                    ),
                                    if (subtitle != null)
                                      Text(
                                        subtitle,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: p.textSecondary,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (selected)
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.gold,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 8),
            GoldActionButton(
              label: 'Готово',
              onPressed: availability == null
                  ? null
                  : () => Navigator.of(context).pop(_selected),
            ),
          ],
        ),
      ),
    );
  }
}
