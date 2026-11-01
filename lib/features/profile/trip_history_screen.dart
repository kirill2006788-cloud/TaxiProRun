import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/mock_trips.dart';
import '../../features/booking/providers/booking_provider.dart';
import '../../features/profile/providers/settings_provider.dart';
import '../../models/payment_method.dart';
import '../../shared/utils/formatters.dart';
import 'providers/profile_provider.dart';
import 'widgets/profile_widgets.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key});

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  List<Map<String, dynamic>> _localItems = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = context.read<ProfileProvider>();
    final items = await profile.loadOrderHistory();
    if (mounted) {
      setState(() {
        _localItems = items;
        _loading = false;
      });
    }
  }

  void _reorder(String from, String to, {PaymentMethod? payment}) {
    context.read<BookingProvider>().prefillFromTrip(
          fromAddress: from,
          toAddress: to,
          paymentMethod: payment,
        );
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final useMock = context.watch<SettingsProvider>().useMockApi ||
        ApiConfigStore.instance.useMockApi;
    final mockTrips = MockTrips.all;
    final hasLocal = _localItems.isNotEmpty;
    final hasMock = useMock && mockTrips.isNotEmpty;
    final isEmpty = !hasLocal && !hasMock;

    return Scaffold(
      appBar: AppBar(
        title: const Text('История заказов'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : isEmpty
              ? ProfileEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'История пока пустая',
                  subtitle: 'Завершённые поездки появятся здесь',
                  actionLabel: 'Заказать поездку',
                  onAction: () => context.go(AppRoutes.home),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    if (hasLocal) ...[
                      const ProfileSectionLabel('Сохранённые заказы'),
                      ..._localItems.map(
                        (item) => _LocalHistoryCard(
                          item,
                          onReorder: () => _reorder(
                            item['from']?.toString() ?? '',
                            item['to']?.toString() ?? '',
                          ),
                        ),
                      ),
                      if (hasMock) const SizedBox(height: 24),
                    ],
                    if (hasMock) ...[
                      const ProfileSectionLabel('Демо-история'),
                      ...mockTrips.map(
                        (trip) => _MockTripCard(
                          trip: trip,
                          onReorder: trip.status == TripStatus.cancelled
                              ? null
                              : () => _reorder(
                                    trip.fromAddress,
                                    trip.toAddress,
                                  ),
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }
}

class _LocalHistoryCard extends StatelessWidget {
  const _LocalHistoryCard(this.item, {this.onReorder});

  final Map<String, dynamic> item;
  final VoidCallback? onReorder;

  @override
  Widget build(BuildContext context) {
    final from = item['from']?.toString() ?? '';
    final to = item['to']?.toString() ?? '';
    final price = item['price'];
    final priceLabel = price == null
        ? ''
        : price is num
            ? formatPriceExact(price.toDouble())
            : '$price ₽';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(from, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(to,
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            if (priceLabel.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                priceLabel,
                style: const TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (onReorder != null && from.isNotEmpty && to.isNotEmpty) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onReorder,
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: const Text('Повторить'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MockTripCard extends StatelessWidget {
  const _MockTripCard({required this.trip, this.onReorder});

  final MockTrip trip;
  final VoidCallback? onReorder;

  @override
  Widget build(BuildContext context) {
    final isCancelled = trip.status == TripStatus.cancelled;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formatDateTime(trip.date),
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 10),
            Text(trip.fromAddress,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(trip.toAddress,
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            Text(
              isCancelled ? 'Отменён' : formatPriceExact(trip.price),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isCancelled ? AppColors.textMuted : AppColors.gold,
              ),
            ),
            if (onReorder != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onReorder,
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: const Text('Повторить'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
