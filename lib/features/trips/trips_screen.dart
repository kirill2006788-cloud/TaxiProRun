import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/models/api_models.dart';
import '../../core/api/services/api_services.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/mock_trips.dart';
import '../../models/payment_method.dart';
import '../../shared/utils/formatters.dart';
import '../../shared/widgets/premium_chrome.dart';
import '../booking/providers/booking_provider.dart';
import '../payment/payment_receipt_screen.dart';
import '../payment/rate_trip_screen.dart';
import '../profile/providers/profile_provider.dart';
import '../profile/providers/settings_provider.dart';
import '../profile/widgets/profile_widgets.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  List<OrderDto> _serverOrders = [];
  List<Map<String, dynamic>> _localItems = [];
  bool _loading = true;
  String? _error;
  bool _fromServer = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final useMock = context.read<SettingsProvider>().useMockApi ||
        ApiConfigStore.instance.useMockApi;
    final local = await context.read<ProfileProvider>().loadOrderHistory();

    if (!useMock) {
      final api = ApiServices();
      try {
        final orders = await api.order.fetchClientOrders();
        if (!mounted) return;
        setState(() {
          _serverOrders = orders;
          _localItems = local;
          _fromServer = true;
          _loading = false;
        });
        return;
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() {
          _error = e.message;
          _localItems = local;
          _fromServer = false;
          _loading = false;
        });
        return;
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _error = 'Не удалось загрузить историю';
          _localItems = local;
          _fromServer = false;
          _loading = false;
        });
        return;
      } finally {
        api.dispose();
      }
    }

    if (!mounted) return;
    setState(() {
      _serverOrders = const [];
      _localItems = local;
      _fromServer = false;
      _loading = false;
    });
  }

  void _repeatOrder({
    required String from,
    required String to,
    PaymentMethod? payment,
  }) {
    context.read<BookingProvider>().prefillFromTrip(
          fromAddress: from,
          toAddress: to,
          paymentMethod: payment,
        );
    context.go(AppRoutes.home);
  }

  void _openTripDetail({
    required String orderId,
    required String from,
    required String to,
    double? price,
    PaymentMethod? payment,
    bool completed = true,
    int? rating,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.backgroundSecondary,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
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
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Поездка',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(from, style: const TextStyle(fontWeight: FontWeight.w600)),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Icon(Icons.arrow_downward_rounded,
                      size: 16, color: AppColors.textMuted),
                ),
                Text(to, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (price != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    formatPriceExact(price),
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                if (completed) ...[
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.push(
                        AppRoutes.paymentReceipt,
                        extra: PaymentReceiptArgs(
                          orderId: orderId,
                          fromAddress: from,
                          toAddress: to,
                          price: price,
                          paymentMethod: payment ?? PaymentMethod.cash,
                        ),
                      );
                    },
                    child: const Text('Чек'),
                  ),
                  const SizedBox(height: 8),
                  if (rating == null)
                    OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.push(
                          AppRoutes.rateTrip,
                          extra: RateTripArgs(
                            orderId: orderId,
                            fromAddress: from,
                            toAddress: to,
                          ),
                        );
                      },
                      child: const Text('Оценить'),
                    ),
                  if (rating == null) const SizedBox(height: 8),
                ],
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _repeatOrder(from: from, to: to, payment: payment);
                  },
                  child: const Text('Повторить'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final useMock = context.watch<SettingsProvider>().useMockApi ||
        ApiConfigStore.instance.useMockApi;
    final mockTrips = MockTrips.all;
    final showServer = _fromServer && _serverOrders.isNotEmpty;
    final showLocal = _localItems.isNotEmpty;
    final showMock = useMock && !_fromServer && mockTrips.isNotEmpty;
    final isEmpty = !_loading &&
        !showServer &&
        !showLocal &&
        !showMock &&
        _error == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Поездки'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Обновить',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const TripListSkeleton()
          : isEmpty
              ? ProfileEmptyState(
                  icon: Icons.route_outlined,
                  title: 'Пока нет поездок',
                  subtitle: 'Здесь появится история ваших заказов',
                  actionLabel: 'Заказать поездку',
                  onAction: () => context.go('/home'),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          '$_error · показаны локальные данные',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    if (showServer) ...[
                      const ProfileSectionLabel('История'),
                      ..._serverOrders.map(
                        (order) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ServerTripCard(
                            order: order,
                            onTap: () => _openTripDetail(
                              orderId: order.id,
                              from: order.fromAddress ?? '',
                              to: order.toAddress ?? '',
                              price: order.displayPrice?.toDouble(),
                              payment: order.paymentMethod,
                              completed: order.isCompleted,
                              rating: order.rating,
                            ),
                            onRepeat: () => _repeatOrder(
                              from: order.fromAddress ?? '',
                              to: order.toAddress ?? '',
                              payment: order.paymentMethod,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (showLocal) ...[
                      const ProfileSectionLabel('Сохранённые'),
                      ..._localItems.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _LocalTripCard(
                            item: item,
                            onTap: () => _openTripDetail(
                              orderId: item['id']?.toString() ?? 'local',
                              from: item['from']?.toString() ?? '',
                              to: item['to']?.toString() ?? '',
                              price: (item['price'] as num?)?.toDouble(),
                              rating: (item['rating'] as num?)?.toInt(),
                            ),
                            onRepeat: () => _repeatOrder(
                              from: item['from']?.toString() ?? '',
                              to: item['to']?.toString() ?? '',
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (showMock) ...[
                      if (showLocal) const SizedBox(height: 8),
                      if (showLocal) const ProfileSectionLabel('Демо'),
                      ...mockTrips.map(
                        (trip) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _TripCard(
                            trip: trip,
                            onTap: () => _openTripDetail(
                              orderId: 'mock-${trip.hashCode}',
                              from: trip.fromAddress,
                              to: trip.toAddress,
                              price: trip.price,
                              completed: trip.status != TripStatus.cancelled,
                            ),
                            onRepeat: () => _repeatOrder(
                              from: trip.fromAddress,
                              to: trip.toAddress,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }
}

class _ServerTripCard extends StatelessWidget {
  const _ServerTripCard({
    required this.order,
    required this.onRepeat,
    required this.onTap,
  });

  final OrderDto order;
  final VoidCallback onRepeat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cancelled =
        order.status == 'canceled' || order.status == 'cancelled';
    final when = order.completedAt ?? order.createdAt ?? order.scheduledAt;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.softCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  when != null ? formatDateTime(when) : order.id,
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
              if (order.rating != null) ...[
                const Icon(Icons.star_rounded, size: 14, color: AppColors.gold),
                const SizedBox(width: 4),
                Text(
                  '${order.rating}',
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              _StatusPill(
                label: cancelled ? 'Отменён' : _statusLabel(order.status),
                tone: cancelled ? AppColors.error : AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _AddressLine(
            icon: Icons.trip_origin,
            color: AppColors.purple,
            text: order.fromAddress ?? '—',
          ),
          Padding(
            padding: const EdgeInsets.only(left: 9),
            child: Container(width: 2, height: 14, color: AppColors.border),
          ),
          _AddressLine(
            icon: Icons.location_on,
            color: AppColors.gold,
            text: order.toAddress ?? '—',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (order.displayPrice != null)
                Text(
                  '${order.displayPrice} ₽',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold,
                  ),
                ),
              if (order.paymentMethod != null) ...[
                const SizedBox(width: 12),
                Text(
                  order.paymentMethod!.label,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
              const Spacer(),
              TextButton(
                onPressed: onRepeat,
                child: const Text('Повторить'),
              ),
            ],
          ),
        ],
      ),
    ),
    );
  }

  String _statusLabel(String status) => switch (status) {
        'completed' => 'Завершена',
        'searching' => 'Поиск',
        'accepted' || 'enroute' || 'arrived' || 'started' => 'Активна',
        _ => status,
      };
}

class _LocalTripCard extends StatelessWidget {
  const _LocalTripCard({
    required this.item,
    required this.onRepeat,
    required this.onTap,
  });

  final Map<String, dynamic> item;
  final VoidCallback onRepeat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.softCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AddressLine(
            icon: Icons.trip_origin,
            color: AppColors.purple,
            text: item['from']?.toString() ?? '',
          ),
          Padding(
            padding: const EdgeInsets.only(left: 9),
            child: Container(width: 2, height: 14, color: AppColors.border),
          ),
          _AddressLine(
            icon: Icons.location_on,
            color: AppColors.gold,
            text: item['to']?.toString() ?? '',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (item['price'] != null)
                Text(
                  '${item['price']} ₽',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold,
                  ),
                ),
              const Spacer(),
              TextButton(onPressed: onRepeat, child: const Text('Повторить')),
            ],
          ),
        ],
      ),
    ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({
    required this.trip,
    required this.onRepeat,
    required this.onTap,
  });

  final MockTrip trip;
  final VoidCallback onRepeat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isCancelled = trip.status == TripStatus.cancelled;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.softCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  formatDateTime(trip.date),
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ),
              _StatusPill(
                label: trip.statusLabel,
                tone: isCancelled ? AppColors.error : AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _AddressLine(
            icon: Icons.trip_origin,
            color: AppColors.purple,
            text: trip.fromAddress,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 9),
            child: Container(width: 2, height: 14, color: AppColors.border),
          ),
          _AddressLine(
            icon: Icons.location_on,
            color: AppColors.gold,
            text: trip.toAddress,
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.local_taxi_outlined,
                  size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(
                trip.tariff.name,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Text(
                isCancelled ? '—' : formatPriceExact(trip.price),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isCancelled ? AppColors.textMuted : AppColors.gold,
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onRepeat,
              child: const Text('Повторить'),
            ),
          ),
        ],
      ),
    ),
    );
  }
}

class _AddressLine extends StatelessWidget {
  const _AddressLine({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              height: 1.3,
              fontWeight: FontWeight.w500,
              color: context.palette.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.tone});

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: tone,
        ),
      ),
    );
  }
}
