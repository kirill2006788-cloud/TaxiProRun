import 'dart:async';



import 'package:flutter/material.dart';

import 'package:go_router/go_router.dart';

import 'package:provider/provider.dart';

import 'package:url_launcher/url_launcher.dart';



import '../../core/api/trip_status_machine.dart';
import '../../core/geo/road_route_service.dart';

import '../../core/theme/app_theme.dart';

import '../../models/models.dart';

import '../../providers/app_providers.dart';

import '../../shared/maps_navigation.dart';

import '../../shared/widgets.dart';

import '../../shared/widgets/service_badge.dart';

import '../../shared/widgets/trip_summary_sheet.dart';

import '../map/map_geo.dart';

import '../map/map_host.dart';

import 'widgets/order_chat_sheet.dart';



class ActiveOrderScreen extends StatefulWidget {

  const ActiveOrderScreen({super.key});

  @override
  State<ActiveOrderScreen> createState() => _ActiveOrderScreenState();
}

class _ActiveOrderScreenState extends State<ActiveOrderScreen> {
  final RoadRouteService _routeService = RoadRouteService();
  List<MapPoint> _resolvedRoute = const [];
  String? _requestedRouteKey;
  String? _resolvedRouteKey;
  var _routeRequestId = 0;

  @override
  void dispose() {
    _routeService.dispose();
    super.dispose();
  }

  String _routeKey(DriverOrder order) {
    final from = order.fromPoint;
    final to = order.toPoint;
    if (from == null || to == null) return 'empty';
    return '${from.lat},${from.lng}|${to.lat},${to.lng}';
  }

  void _ensureRoute(DriverOrder order) {
    final key = _routeKey(order);
    if (key == _requestedRouteKey) return;
    _requestedRouteKey = key;
    _resolvedRouteKey = null;
    _resolvedRoute = const [];
    final from = order.fromPoint;
    final to = order.toPoint;
    if (from == null || to == null) return;

    final requestId = ++_routeRequestId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final route = await _routeService.resolve(
        from: mapPoint(from.lat, from.lng),
        to: mapPoint(to.lat, to.lng),
      );
      if (!mounted || requestId != _routeRequestId) return;
      setState(() {
        _resolvedRoute = route;
        _resolvedRouteKey = key;
      });
    });
  }



  Future<void> _callClient(BuildContext context, String phone) async {

    final cleaned = phone.trim();

    if (cleaned.isEmpty) {

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(content: Text('Номер клиента недоступен')),

      );

      return;

    }

    final uri = Uri(scheme: 'tel', path: cleaned);

    if (await canLaunchUrl(uri)) {

      await launchUrl(uri);

    } else if (context.mounted) {

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(content: Text('Не удалось открыть звонок')),

      );

    }

  }



  Future<void> _openNavigation(

    BuildContext context,

    DriverOrder order, {

    NavApp? app,

  }) async {

    final settings = context.read<SettingsProvider>();

    final navApp = app ?? settings.settings.navApp;

    final point = navigationPointFor(order);

    final label =

        order.status == TripOrderStatus.started ? order.dropoff : order.pickup;

    final ok = await openMapsNavigation(

      app: navApp,

      lat: point.lat,

      lng: point.lng,

      label: label,

    );

    if (!context.mounted) return;

    if (!ok) {

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(content: Text('Не удалось открыть карты')),

      );

    }

  }



  Future<void> _showNavPicker(BuildContext context, DriverOrder order) async {

    final settings = context.read<SettingsProvider>();

    final current = settings.settings.navApp;

    final selected = await showModalBottomSheet<NavApp>(

      context: context,

      shape: const RoundedRectangleBorder(

        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),

      ),

      builder: (ctx) {

        return SafeArea(

          child: Column(

            mainAxisSize: MainAxisSize.min,

            children: [

              const Padding(

                padding: EdgeInsets.all(16),

                child: Text(

                  'Открыть маршрут',

                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),

                ),

              ),

              for (final app in NavApp.values)

                ListTile(

                  leading: Icon(

                    Icons.check_circle,

                    color: current == app ? AppColors.purple : Colors.transparent,

                  ),

                  title: Text(navAppLabel(app)),

                  onTap: () => Navigator.pop(ctx, app),

                ),

              const SizedBox(height: 8),

            ],

          ),

        );

      },

    );

    if (selected == null || !context.mounted) return;

    if (selected != current) {

      await context.read<SettingsProvider>().setNavApp(selected);

    }

    if (!context.mounted) return;

    await _openNavigation(context, order, app: selected);

  }



  Future<void> _cancelOrder(BuildContext context, OrdersProvider provider) async {

    final ok = await showDialog<bool>(

      context: context,

      builder: (ctx) => AlertDialog(

        title: const Text('Отменить заказ?'),

        content: const Text(

          'Заказ будет отменён. Клиент получит уведомление.',

        ),

        actions: [

          TextButton(

            onPressed: () => Navigator.pop(ctx, false),

            child: const Text('Назад'),

          ),

          TextButton(

            onPressed: () => Navigator.pop(ctx, true),

            child: const Text(

              'Отменить',

              style: TextStyle(color: AppColors.error),

            ),

          ),

        ],

      ),

    );

    if (ok != true || !context.mounted) return;

    final canceled = await provider.cancelActiveOrder();

    if (!context.mounted) return;

    if (!canceled) {

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(content: Text(provider.lastError ?? 'Не удалось отменить')),

      );

      return;

    }

    context.pop();

  }



  Future<void> _handleMenuAction(

    BuildContext context,

    String action,

    DriverOrder order,

    OrdersProvider provider,

  ) async {

    switch (action) {

      case 'call':

        await _callClient(context, order.clientPhone);

      case 'chat':

        await showOrderChatSheet(

          context,

          orderId: order.id,

          peerLabel: order.passengerName,

        );

      case 'nav':

        await _showNavPicker(context, order);

      case 'cancel':

        await _cancelOrder(context, provider);

    }

  }



  @override

  Widget build(BuildContext context) {

    final provider = context.watch<OrdersProvider>();

    final order = provider.activeOrder;

    final t = context.tokens;



    if (order == null) {

      return Scaffold(

        appBar: AppBar(title: const Text('Активный заказ')),

        body: EmptyState(

          icon: Icons.local_taxi_outlined,

          title: 'Нет активного заказа',

          subtitle: 'Примите заказ из списка, чтобы управлять поездкой',

          action: TextButton(

            onPressed: () => context.pop(),

            child: const Text('Назад к заказам'),

          ),

        ),

      );

    }



    _ensureRoute(order);
    final routeKey = _routeKey(order);
    final routePoints = _resolvedRouteKey == routeKey &&
            _resolvedRoute.length >= 2
        ? _resolvedRoute
        : const <MapPoint>[];

    final etaLabel = order.etaMinutes > 0

        ? '~${order.etaMinutes} мин'

        : 'время уточняется';

    final distanceLabel = order.distanceKm > 0

        ? '${order.distanceKm.toStringAsFixed(1)} км'

        : '—';



    return Scaffold(

      body: Column(

        children: [

          Expanded(

            child: Stack(

              fit: StackFit.expand,

              children: [

                MapHost(

                  routePoints: routePoints,

                  demoCruise: false,

                  showSetupHint: false,

                ),

                Positioned(

                  top: MediaQuery.paddingOf(context).top + 8,

                  left: 12,

                  right: 12,

                  child: Row(

                    children: [

                      Material(

                        color: t.surface.withValues(alpha: 0.94),

                        borderRadius: BorderRadius.circular(14),

                        elevation: 2,

                        child: IconButton(

                          onPressed: () => context.pop(),

                          icon: const Icon(Icons.arrow_back_rounded),

                          color: t.textPrimary,

                        ),

                      ),

                      const SizedBox(width: 8),

                      Expanded(

                        child: DecoratedBox(

                          decoration: BoxDecoration(

                            color: t.surface.withValues(alpha: 0.94),

                            borderRadius: BorderRadius.circular(14),

                            border: Border.all(color: t.border),

                          ),

                          child: Padding(

                            padding: const EdgeInsets.symmetric(

                              horizontal: 12,

                              vertical: 10,

                            ),

                            child: Text(

                              TripStatusMachine.statusLabel(order.status),

                              style: TextStyle(

                                fontWeight: FontWeight.w700,

                                color: t.isDark

                                    ? AppColors.gold

                                    : AppColors.goldDark,

                              ),

                            ),

                          ),

                        ),

                      ),

                      const SizedBox(width: 8),

                      Material(

                        color: t.surface.withValues(alpha: 0.94),

                        borderRadius: BorderRadius.circular(14),

                        child: PopupMenuButton<String>(

                          icon: Icon(Icons.more_vert_rounded, color: t.textPrimary),

                          onSelected: (value) =>

                              _handleMenuAction(context, value, order, provider),

                          itemBuilder: (_) => const [

                            PopupMenuItem(

                              value: 'call',

                              child: ListTile(

                                leading: Icon(Icons.phone_rounded),

                                title: Text('Позвонить'),

                                contentPadding: EdgeInsets.zero,

                              ),

                            ),

                            PopupMenuItem(

                              value: 'chat',

                              child: ListTile(

                                leading: Icon(Icons.chat_bubble_rounded),

                                title: Text('Чат'),

                                contentPadding: EdgeInsets.zero,

                              ),

                            ),

                            PopupMenuItem(

                              value: 'nav',

                              child: ListTile(

                                leading: Icon(Icons.navigation_rounded),

                                title: Text('Навигация'),

                                contentPadding: EdgeInsets.zero,

                              ),

                            ),

                            PopupMenuItem(

                              value: 'cancel',

                              child: ListTile(

                                leading: Icon(

                                  Icons.cancel_rounded,

                                  color: AppColors.error,

                                ),

                                title: Text(

                                  'Отменить заказ',

                                  style: TextStyle(color: AppColors.error),

                                ),

                                contentPadding: EdgeInsets.zero,

                              ),

                            ),

                          ],

                        ),

                      ),

                    ],

                  ),

                ),

                Positioned(

                  top: MediaQuery.paddingOf(context).top + 64,

                  left: 12,

                  child: Wrap(

                    spacing: 8,

                    runSpacing: 8,

                    children: [

                      _InfoPill(

                        icon: Icons.schedule_rounded,

                        label: etaLabel,

                        accent: AppColors.purple,

                      ),

                      _InfoPill(

                        icon: Icons.route_rounded,

                        label: distanceLabel,

                        accent: AppColors.gold,

                      ),

                      _InfoPill(

                        icon: Icons.payments_outlined,

                        label: formatMoney(order.price),

                        accent: AppColors.success,

                      ),

                      if (order.status == TripOrderStatus.arrived)

                        _ArrivedWaitChip(

                          key: ValueKey('wait-${order.id}'),

                          arrivedAt: order.arrivedAt,

                        ),

                    ],

                  ),

                ),

              ],

            ),

          ),

          SafeArea(

            top: false,

            child: DecoratedBox(

              decoration: BoxDecoration(

                color: t.scaffold.withValues(alpha: 0.98),

                border: Border(top: BorderSide(color: t.border)),

                boxShadow: [

                  BoxShadow(

                    color: Colors.black.withValues(alpha: t.isDark ? 0.35 : 0.08),

                    blurRadius: 20,

                    offset: const Offset(0, -4),

                  ),

                ],

              ),

              child: Padding(

                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),

                child: Column(

                  mainAxisSize: MainAxisSize.min,

                  crossAxisAlignment: CrossAxisAlignment.stretch,

                  children: [

                    ServiceTypeBadge(serviceType: order.serviceType),

                    const SizedBox(height: 10),

                    _TargetCard(order: order),

                    if ((order.comment ?? '').trim().isNotEmpty) ...[

                      const SizedBox(height: 10),

                      Text(

                        order.comment!,

                        maxLines: 2,

                        overflow: TextOverflow.ellipsis,

                        style: TextStyle(color: t.textSecondary, fontSize: 13),

                      ),

                    ],

                    const SizedBox(height: 14),

                    _PrimaryActionButton(order: order, provider: provider),

                  ],

                ),

              ),

            ),

          ),

        ],

      ),

    );

  }

}



class _InfoPill extends StatelessWidget {

  const _InfoPill({

    required this.icon,

    required this.label,

    required this.accent,

  });



  final IconData icon;

  final String label;

  final Color accent;



  @override

  Widget build(BuildContext context) {

    final t = context.tokens;

    return DecoratedBox(

      decoration: BoxDecoration(

        color: t.surface.withValues(alpha: 0.94),

        borderRadius: BorderRadius.circular(14),

        border: Border.all(color: t.border),

      ),

      child: Padding(

        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),

        child: Row(

          mainAxisSize: MainAxisSize.min,

          children: [

            Icon(icon, size: 15, color: accent),

            const SizedBox(width: 6),

            Text(

              label,

              style: TextStyle(

                fontWeight: FontWeight.w700,

                fontSize: 12,

                color: t.textPrimary,

              ),

            ),

          ],

        ),

      ),

    );

  }

}



class _ArrivedWaitChip extends StatefulWidget {

  const _ArrivedWaitChip({

    super.key,

    this.arrivedAt,

  });



  static const freeWait = Duration(minutes: 3);



  final DateTime? arrivedAt;



  @override

  State<_ArrivedWaitChip> createState() => _ArrivedWaitChipState();

}



class _ArrivedWaitChipState extends State<_ArrivedWaitChip> {

  Timer? _timer;

  late DateTime _started;

  late Duration _elapsed;



  static String _mmSs(Duration d) {

    final total = d.inSeconds.clamp(0, 99 * 60 + 59);

    final m = (total ~/ 60).toString().padLeft(2, '0');

    final s = (total % 60).toString().padLeft(2, '0');

    return '$m:$s';

  }



  @override

  void initState() {

    super.initState();

    _started = widget.arrivedAt ?? DateTime.now();

    _elapsed = DateTime.now().difference(_started);

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {

      if (!mounted) return;

      setState(() {

        _elapsed = DateTime.now().difference(_started);

      });

    });

  }



  @override

  void didUpdateWidget(covariant _ArrivedWaitChip oldWidget) {

    super.didUpdateWidget(oldWidget);

    if (widget.arrivedAt != null && widget.arrivedAt != _started) {

      _started = widget.arrivedAt!;

      _elapsed = DateTime.now().difference(_started);

    }

  }



  @override

  void dispose() {

    _timer?.cancel();

    super.dispose();

  }



  @override

  Widget build(BuildContext context) {

    const free = _ArrivedWaitChip.freeWait;

    final isFree = _elapsed < free;

    final shown = isFree ? _elapsed : _elapsed - free;

    return _InfoPill(

      icon: Icons.hourglass_top_rounded,

      label:

          '${isFree ? 'Ожидание' : 'Платное'} · ${_mmSs(shown)}',

      accent: isFree ? AppColors.success : AppColors.gold,

    );

  }

}



class _PrimaryActionButton extends StatelessWidget {

  const _PrimaryActionButton({

    required this.order,

    required this.provider,

  });



  final DriverOrder order;

  final OrdersProvider provider;



  @override

  Widget build(BuildContext context) {

    final next = TripStatusMachine.nextDriverAction(order.status);



    if (next == null) {

      return FilledButton(

        onPressed: () => context.pop(),

        child: const Text('Готово'),

      );

    }



    final label = TripStatusMachine.actionLabel(order.status);

    final isComplete = next == TripOrderStatus.completed;



    return ElevatedButton(

      style: ElevatedButton.styleFrom(

        minimumSize: const Size.fromHeight(56),

      ),

      onPressed: () async {

        final ok = await provider.advanceActiveOrder();

        if (!context.mounted) return;

        if (!ok) {

          ScaffoldMessenger.of(context).showSnackBar(

            SnackBar(

              content: Text(

                provider.lastError ?? 'Не удалось обновить статус',

              ),

            ),

          );

          return;

        }

        if (isComplete) {

          final done = provider.lastCompleted ?? order;

          await showTripSummarySheet(context, order: done);

          if (!context.mounted) return;

          context.pop();

        }

      },

      child: Text(label),

    );

  }

}



class _TargetCard extends StatelessWidget {

  const _TargetCard({required this.order});



  final DriverOrder order;



  @override

  Widget build(BuildContext context) {

    final t = context.tokens;

    final goingToDestination = order.status == TripOrderStatus.started;

    return Container(

      padding: const EdgeInsets.all(13),

      decoration: BoxDecoration(

        color: t.elevated,

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: t.border),

      ),

      child: Row(

        children: [

          Icon(

            goingToDestination

                ? Icons.flag_rounded

                : Icons.person_pin_circle_rounded,

            color: goingToDestination ? AppColors.gold : AppColors.purple,

            size: 28,

          ),

          const SizedBox(width: 11),

          Expanded(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(

                  goingToDestination ? 'Едем к точке Б' : 'Подача автомобиля',

                  style: TextStyle(color: t.textMuted, fontSize: 12),

                ),

                const SizedBox(height: 3),

                Text(

                  goingToDestination ? order.dropoff : order.pickup,

                  maxLines: 2,

                  overflow: TextOverflow.ellipsis,

                  style: TextStyle(

                    color: t.textPrimary,

                    fontWeight: FontWeight.w800,

                  ),

                ),

                const SizedBox(height: 4),

                Text(

                  order.passengerName,

                  style: TextStyle(color: t.textSecondary, fontSize: 13),

                ),

              ],

            ),

          ),

        ],

      ),

    );

  }

}

