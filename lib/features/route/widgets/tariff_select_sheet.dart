import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/tariff_groups.dart';
import '../../../models/payment_method.dart';
import '../../../models/tariff.dart';
import '../../../shared/utils/formatters.dart';
import '../../../shared/widgets/action_buttons.dart';

/// Compact tariff picker with route, service tabs, cars and fixed actions.
class TariffSelectSheet extends StatelessWidget {
  const TariffSelectSheet({
    super.key,
    required this.fromAddress,
    required this.toAddress,
    required this.tariffs,
    required this.selected,
    required this.tab,
    required this.loading,
    required this.routeReady,
    required this.priceFor,
    required this.paymentMethod,
    required this.canOrder,
    required this.isSubmitting,
    required this.pricingLoading,
    required this.priceError,
    required this.onTabChanged,
    required this.onSelectTariff,
    required this.onEditRoute,
    required this.onPaymentTap,
    required this.onOptionsTap,
    required this.onOrder,
    required this.onRetryPrice,
    this.etaMinutes,
    this.onPriceTap,
  });

  final String fromAddress;
  final String toAddress;
  final List<Tariff> tariffs;
  final Tariff? selected;
  final TariffTab tab;
  final bool loading;
  final bool routeReady;
  final double? Function(Tariff tariff) priceFor;
  final PaymentMethod paymentMethod;
  final bool canOrder;
  final bool isSubmitting;
  final bool pricingLoading;
  final String? priceError;
  final ValueChanged<TariffTab> onTabChanged;
  final ValueChanged<Tariff> onSelectTariff;
  final VoidCallback onEditRoute;
  final VoidCallback onPaymentTap;
  final VoidCallback onOptionsTap;
  final VoidCallback onOrder;
  final VoidCallback onRetryPrice;
  final int? etaMinutes;
  final VoidCallback? onPriceTap;

  IconData get _paymentIcon => switch (paymentMethod) {
        PaymentMethod.cash => Icons.payments_outlined,
        PaymentMethod.card => Icons.credit_card_rounded,
        PaymentMethod.sbp => Icons.qr_code_2_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final filtered = TariffGroups.filter(tariffs, tab);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onEditRoute,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              children: [
                _RouteLine(
                  marker: 'A',
                  color: AppColors.purple,
                  text: fromAddress,
                  muted: true,
                ),
                const SizedBox(height: 4),
                _RouteLine(
                  marker: 'B',
                  color: AppColors.gold,
                  text: toAddress,
                  trailing:
                      Icon(Icons.edit_outlined, size: 16, color: p.textMuted),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 5),
        SizedBox(
          height: 32,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: TariffTab.values.map((t) {
              final selectedTab = t == tab;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(t.label),
                  selected: selectedTab,
                  onSelected: (_) => onTabChanged(t),
                  selectedColor: AppColors.gold.withValues(alpha: 0.22),
                  visualDensity: VisualDensity.compact,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: selectedTab ? AppColors.gold : p.textSecondary,
                    fontSize: 12,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 5),
        SizedBox(
          height: 76,
          child: loading && filtered.isEmpty
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : filtered.isEmpty
                  ? Center(
                      child: Text(
                        'Нет тарифов',
                        style: TextStyle(color: p.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 7),
                      itemBuilder: (context, index) {
                        final tariff = filtered[index];
                        final price = routeReady ? priceFor(tariff) : null;
                        final isSelected = selected?.id == tariff.id;
                        return _TariffCard(
                          tariff: tariff,
                          selected: isSelected,
                          price: price,
                          etaMinutes: etaMinutes,
                          onTap: () => onSelectTariff(tariff),
                          onPriceTap: isSelected ? onPriceTap : null,
                        );
                      },
                    ),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            _RoundIconButton(
              icon: _paymentIcon,
              onTap: onPaymentTap,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GoldActionButton(
                label: isSubmitting
                    ? 'Создаем заказ…'
                    : pricingLoading
                        ? 'Рассчитываем…'
                        : priceError != null
                            ? 'Повторить расчет'
                            : 'Заказать',
                enabled: canOrder || priceError != null,
                loading: isSubmitting || pricingLoading,
                onPressed: priceError != null ? onRetryPrice : onOrder,
              ),
            ),
            const SizedBox(width: 10),
            _RoundIconButton(
              icon: Icons.tune_rounded,
              onTap: onOptionsTap,
            ),
          ],
        ),
      ],
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({
    required this.marker,
    required this.color,
    required this.text,
    this.trailing,
    this.muted = false,
  });

  final String marker;
  final Color color;
  final String text;
  final Widget? trailing;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Text(
            marker,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: muted ? p.textSecondary : p.textPrimary,
              fontSize: muted ? 13 : 14,
              fontWeight: muted ? FontWeight.w600 : FontWeight.w800,
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 6),
          trailing!,
        ],
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.bgElevated,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: AppColors.gold, size: 21),
        ),
      ),
    );
  }
}

class _TariffCard extends StatelessWidget {
  const _TariffCard({
    required this.tariff,
    required this.selected,
    required this.onTap,
    this.price,
    this.etaMinutes,
    this.onPriceTap,
  });

  final Tariff tariff;
  final bool selected;
  final double? price;
  final int? etaMinutes;
  final VoidCallback onTap;
  final VoidCallback? onPriceTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      width: selected ? 92 : 80,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onPriceTap,
          borderRadius: BorderRadius.circular(13),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 4),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.gold
                      .withValues(alpha: context.isDarkTheme ? 0.16 : 0.22)
                  : p.bgElevated,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: selected ? AppColors.gold : p.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Center(
                    child: Image.asset(
                      'assets/images/tariffs/${tariff.icon}.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                      errorBuilder: (_, __, ___) => Icon(
                        tariff.isSoberDriver
                            ? Icons.no_drinks_rounded
                            : Icons.local_taxi_rounded,
                        color: selected ? AppColors.gold : p.textSecondary,
                        size: 21,
                      ),
                    ),
                  ),
                ),
                Text(
                  tariff.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  price != null
                      ? formatPrice(price!)
                      : 'от ${tariff.clientRatePerKm.toStringAsFixed(0)} ₽',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? AppColors.gold : p.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
