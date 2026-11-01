import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../features/booking/providers/booking_provider.dart';
import '../../shared/widgets/action_buttons.dart';
import '../../shared/widgets/app_bar_back.dart';
import '../../shared/widgets/async_state_widgets.dart';
import '../../shared/widgets/tariff_card.dart';

class TariffsScreen extends StatefulWidget {
  const TariffsScreen({super.key});

  @override
  State<TariffsScreen> createState() => _TariffsScreenState();
}

class _TariffsScreenState extends State<TariffsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookingProvider>().loadTariffs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBarWithBack(context, title: 'Выберите тариф'),
      body: Consumer<BookingProvider>(
        builder: (context, provider, _) {
          final selected = provider.booking.selectedTariff;
          final serviceLabel = provider.booking.serviceType.label;

          if (provider.tariffsState == TariffsLoadState.loading) {
            return LoadingStateView(
              message: 'Загружаем тарифы для «$serviceLabel»…',
            );
          }

          if (provider.tariffsState == TariffsLoadState.error) {
            return ErrorStateView(
              message: provider.tariffsError ?? 'Не удалось загрузить тарифы',
              onRetry: provider.loadTariffs,
            );
          }

          final tariffs = provider.availableTariffs;
          if (tariffs.isEmpty) {
            return const EmptyStateView(
              title: 'Тарифы недоступны',
              subtitle: 'Попробуйте позже или смените тип услуги',
              icon: Icons.local_taxi_outlined,
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        provider.booking.serviceType.icon,
                        size: 20,
                        color: AppColors.purple,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          serviceLabel,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (provider.booking.estimatedPrice != null)
                        Text(
                          '~ ${provider.booking.estimatedPrice!.round()} ₽',
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: tariffs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final tariff = tariffs[index];
                    return TariffCard(
                      tariff: tariff,
                      isSelected: selected?.id == tariff.id,
                      onTap: () => provider.selectTariff(tariff),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (selected?.driverRateLabel != null)
                      Text(
                        'Водителю: от ${selected!.driverRateLabel}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    const SizedBox(height: 12),
                    PurpleActionButton(
                      label: 'Далее',
                      enabled: selected != null,
                      onPressed: () => context.push(AppRoutes.preferences),
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
