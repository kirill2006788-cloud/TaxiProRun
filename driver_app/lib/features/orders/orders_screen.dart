import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/api/app_services.dart';
import '../../core/api/driver_location_ticker.dart';
import '../../core/geo/road_route_service.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets.dart';
import '../../shared/widgets/decline_reason_sheet.dart';
import '../map/map_geo.dart';
import '../map/map_host.dart';

/// Главный рабочий экран водителя: карта всегда остаётся основой, а снизу
/// меняется только контекстная карточка — офлайн, ожидание, новый или активный
/// заказ. Так водитель не теряет дорогу и не ищет действия в списках.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final RoadRouteService _routeService = RoadRouteService();
  List<MapPoint> _resolvedRoute = const [];
  String? _requestedRouteKey;
  String? _resolvedRouteKey;
  var _routeRequestId = 0;
  var _recenterToken = 0;
  var _gpsChecking = false;
  var _gpsReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkGpsOnEntry());
  }

  Future<void> _checkGpsOnEntry() async {
    if (!mounted || _gpsChecking || _gpsReady) return;
    setState(() => _gpsChecking = true);
    final allowed = await DriverLocationTicker.ensureLocationPermission();
    if (allowed) {
      await AppServices.instance.locationTicker.start(tripMode: false);
    }
    if (!mounted) return;
    setState(() {
      _gpsChecking = false;
      _gpsReady =
          allowed && AppServices.instance.locationTicker.latestPosition != null;
    });
  }

  @override
  void dispose() {
    _routeService.dispose();
    super.dispose();
  }

  Future<void> _setOnline(BuildContext context, bool value) async {
    final settings = context.read<SettingsProvider>();
    final changed = await settings.setOnline(value);
    if (!context.mounted) return;
    if (!changed) {
      showDriverSnackBar(
        context,
        settings.onlineError ?? 'Не удалось изменить статус',
        isError: true,
      );
      return;
    }
    if (value) context.read<OrdersProvider>().onWentOnline();
  }

  Future<void> _accept(BuildContext context, DriverOrder order) async {
    final provider = context.read<OrdersProvider>();
    final ok = await provider.acceptOrderFast(order);
    if (!context.mounted) return;
    if (!ok) {
      showDriverSnackBar(
        context,
        provider.lastError ?? 'Не удалось принять заказ',
        isError: true,
      );
      return;
    }
    if (ok) return;
    if (!context.mounted) return;
    showDriverSnackBar(
      context,
      provider.lastError ?? 'Не удалось начать движение по заказу',
      isError: true,
    );
  }

  bool _isNearPickup(DriverOrder order) {
    final point = order.fromPoint;
    final position = AppServices.instance.locationTicker.latestPosition;
    if (point == null || position == null) return false;
    return Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          point.lat,
          point.lng,
        ) <=
        250;
  }

  Future<void> _advanceActive(BuildContext context, DriverOrder order) async {
    if (order.status == TripOrderStatus.enroute ||
        order.status == TripOrderStatus.accepted) {
      if (!_isNearPickup(order)) {
        showDriverSnackBar(
          context,
          'Подъедьте к точке подачи: GPS ещё не подтвердил прибытие',
          isError: true,
        );
        return;
      }
    }
    final provider = context.read<OrdersProvider>();
    final ok = await provider.advanceActiveOrder();
    if (!context.mounted || ok) return;
    showDriverSnackBar(
      context,
      provider.lastError ?? 'Не удалось обновить статус заказа',
      isError: true,
    );
  }

  Future<void> _locate(BuildContext context) async {
    final allowed = await DriverLocationTicker.ensureLocationPermission();
    if (!context.mounted) return;
    if (!allowed) {
      showDriverSnackBar(
        context,
        'Разрешите геолокацию, чтобы определить ваше местоположение',
        isError: true,
      );
      return;
    }
    final ticker = AppServices.instance.locationTicker;
    await ticker.start(tripMode: ticker.isTripMode);
    if (!mounted) return;
    setState(() => _recenterToken++);
  }

  Future<void> _skip(
    BuildContext context,
    DriverOrder order, {
    bool askReason = true,
  }) async {
    String? reason;
    if (askReason) {
      final picked = await showDeclineReasonSheet(context);
      if (!context.mounted || picked == null) return;
      reason = picked.isEmpty ? null : picked;
    }
    final provider = context.read<OrdersProvider>();
    final ok = await provider.skipOrder(order.id, reason: reason);
    if (!context.mounted || ok) return;
    showDriverSnackBar(
      context,
      provider.lastError ?? 'Не удалось пропустить заказ',
      isError: true,
    );
  }

  String _routeKeyFor(DriverOrder? order) {
    final fromPoint = order?.fromPoint;
    final toPoint = order?.toPoint;
    final from =
        fromPoint == null ? null : mapPoint(fromPoint.lat, fromPoint.lng);
    final to = toPoint == null ? null : mapPoint(toPoint.lat, toPoint.lng);
    if (from == null || to == null) return 'empty';
    return '${from.lat},${from.lng}|${to.lat},${to.lng}';
  }

  void _requestRoadRoute(DriverOrder? order) {
    final key = _routeKeyFor(order);
    if (key == _requestedRouteKey) return;
    _requestedRouteKey = key;
    _resolvedRouteKey = null;
    _resolvedRoute = const [];
    final fromPoint = order?.fromPoint;
    final toPoint = order?.toPoint;
    final from =
        fromPoint == null ? null : mapPoint(fromPoint.lat, fromPoint.lng);
    final to = toPoint == null ? null : mapPoint(toPoint.lat, toPoint.lng);
    if (from == null ||
        to == null ||
        (from.lat == 0 && from.lng == 0) ||
        (to.lat == 0 && to.lng == 0)) {
      return;
    }

    final requestId = ++_routeRequestId;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final route = await _routeService.resolve(from: from, to: to);
      if (!mounted || requestId != _routeRequestId) return;
      setState(() {
        _resolvedRoute = route;
        _resolvedRouteKey = key;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final orders = context.watch<OrdersProvider>();
    final driver = context.watch<DriverProvider>();
    final incoming = orders.incomingOrder;
    final active = orders.activeOrder;
    final canGoOnline = driver.profile.registrationComplete &&
        !driver.profile.registrationBlocked;
    final shownOrder = active ?? incoming;
    _requestRoadRoute(shownOrder);
    final routeKey = _routeKeyFor(shownOrder);
    final route = _resolvedRouteKey == routeKey && _resolvedRoute.length >= 2
        ? _resolvedRoute
        : const <MapPoint>[];
    final top = MediaQuery.paddingOf(context).top;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: ListenableBuilder(
              listenable: AppServices.instance.locationTicker,
              builder: (context, _) {
                final position =
                    AppServices.instance.locationTicker.latestPosition;
                return MapHost(
                  routePoints: route,
                  driverLat: position?.latitude,
                  driverLng: position?.longitude,
                  recenterToken: _recenterToken,
                  demoCruise: false,
                  showSetupHint: false,
                );
              },
            ),
          ),
          Positioned(
            top: top + 12,
            right: 14,
            child: _DriverTopBar(
              earnings: driver.profile.earningsToday + driver.profile.tipsToday,
              profile: driver.profile,
            ),
          ),
          Positioned(
            top: top + 62,
            right: 14,
            child: _GpsButton(
              checking: _gpsChecking,
              ready: _gpsReady,
              onPressed: () => _locate(context),
            ),
          ),
          if (incoming != null && active == null)
            Positioned(
              top: top + 8,
              left: 0,
              right: 0,
              child: Center(
                child: _IncomingSkipButton(
                  onPressed: () => _skip(context, incoming),
                ),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _MapWorkSheet(
              child: orders.loading
                  ? const _LoadingPanel()
                  : !canGoOnline
                      ? _VerificationPanel(profile: driver.profile)
                      : !settings.isOnline
                          ? _OfflinePanel(
                              onGoOnline: () => _setOnline(context, true),
                            )
                          : active != null
                              ? _ActiveOrderPanel(
                                  order: active,
                                  onAction: () =>
                                      _advanceActive(context, active),
                                )
                              : incoming != null
                                  ? _IncomingOrderPanel(
                                      key: ValueKey(incoming.id),
                                      order: incoming,
                                      acceptTimeoutSec:
                                          driver.profile.orderAcceptTimeoutSec,
                                      onAccept: () =>
                                          _accept(context, incoming),
                                      onSkip: ({bool askReason = true}) =>
                                          _skip(
                                        context,
                                        incoming,
                                        askReason: askReason,
                                      ),
                                    )
                                  : orders.lastCompleted != null
                                      ? _CompletedTripPanel(
                                          order: orders.lastCompleted!,
                                          onDismiss: () =>
                                              orders.clearLastCompleted(),
                                        )
                                      : _WaitingPanel(
                                          preorders: orders.preorders,
                                          onPause: () =>
                                              _setOnline(context, false),
                                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GpsButton extends StatelessWidget {
  const _GpsButton({
    required this.onPressed,
    required this.checking,
    required this.ready,
  });

  final VoidCallback onPressed;
  final bool checking;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: t.surface.withValues(alpha: 0.94),
      shape: const CircleBorder(),
      elevation: 5,
      child: IconButton(
        tooltip: 'Моё местоположение',
        onPressed: onPressed,
        icon: checking
            ? const SizedBox.square(
                dimension: 19,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            : const Icon(Icons.my_location_rounded),
        color: ready ? Colors.greenAccent : AppColors.gold,
      ),
    );
  }
}

class _DriverTopBar extends StatelessWidget {
  const _DriverTopBar({required this.earnings, required this.profile});

  final double earnings;
  final DriverProfile profile;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: t.surface.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(22),
      elevation: 5,
      shadowColor: Colors.black38,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => context.push(AppRoutes.profile),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DriverAvatar(profile: profile),
              const SizedBox(width: 7),
              Text(
                formatMoney(earnings),
                style: TextStyle(
                  color: t.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DriverAvatar extends StatelessWidget {
  const _DriverAvatar({required this.profile});

  final DriverProfile profile;

  @override
  Widget build(BuildContext context) {
    final encoded = profile.avatarBase64?.trim();
    if (encoded == null || encoded.isEmpty) {
      return const Icon(Icons.account_circle_rounded,
          color: AppColors.gold, size: 25);
    }
    try {
      return ClipOval(
        child: Image.memory(
          base64Decode(encoded),
          width: 26,
          height: 26,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(
            Icons.account_circle_rounded,
            color: AppColors.gold,
            size: 25,
          ),
        ),
      );
    } catch (_) {
      return const Icon(Icons.account_circle_rounded,
          color: AppColors.gold, size: 25);
    }
  }
}

class _IncomingSkipButton extends StatelessWidget {
  const _IncomingSkipButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.close_rounded, size: 17),
      label: const Text('Пропустить'),
      style: OutlinedButton.styleFrom(
        foregroundColor: t.textPrimary,
        backgroundColor: t.surface.withValues(alpha: 0.94),
        side: BorderSide(color: t.textMuted.withValues(alpha: 0.7)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
      ),
    );
  }
}

class _MapWorkSheet extends StatelessWidget {
  const _MapWorkSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.63,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.surface.withValues(alpha: 0.985),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border(top: BorderSide(color: t.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: t.isDark ? 0.52 : 0.15),
              blurRadius: 34,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: t.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Обновляем заказы…'),
        ],
      ),
    );
  }
}

class _OfflinePanel extends StatelessWidget {
  const _OfflinePanel({required this.onGoOnline});

  final VoidCallback onGoOnline;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PrimaryGoldButton(label: 'На линию', onPressed: onGoOnline),
      ],
    );
  }
}

class _WaitingPanel extends StatelessWidget {
  const _WaitingPanel({required this.preorders, required this.onPause});

  final List<DriverOrder> preorders;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Вы на линии',
            style: TextStyle(
                color: t.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900)),
        if (preorders.isNotEmpty) ...[
          const SizedBox(height: 15),
          _PreorderNotice(order: preorders.first),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onPause,
          icon: const Icon(Icons.power_settings_new_rounded),
          label: const Text('Закончить смену'),
        ),
      ],
    );
  }
}

class _PreorderNotice extends StatelessWidget {
  const _PreorderNotice({required this.order});

  final DriverOrder order;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final at = order.scheduledAt;
    final time = at == null
        ? 'время уточняется'
        : '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.elevated,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: t.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_available_rounded, color: AppColors.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Предзаказ в $time · ${order.pickup}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  TextStyle(color: t.textPrimary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _IncomingCountdown extends StatelessWidget {
  const _IncomingCountdown({
    required this.seconds,
    required this.progress,
    required this.color,
  });

  final int seconds;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: progress, end: progress),
            duration: const Duration(milliseconds: 120),
            builder: (context, value, child) => SizedBox.expand(
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: 4,
                backgroundColor: color.withValues(alpha: 0.14),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.11),
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                ),
                child: Column(
                  key: ValueKey(seconds),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$seconds',
                      style: TextStyle(
                        color: color,
                        fontSize: 17,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'сек',
                      style: TextStyle(
                        color: t.textSecondary,
                        fontSize: 9,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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

class _IncomingOrderPanel extends StatefulWidget {
  const _IncomingOrderPanel({
    super.key,
    required this.order,
    required this.acceptTimeoutSec,
    required this.onAccept,
    required this.onSkip,
  });

  final DriverOrder order;
  final int acceptTimeoutSec;
  final VoidCallback onAccept;
  final FutureOr<void> Function({bool askReason}) onSkip;

  @override
  State<_IncomingOrderPanel> createState() => _IncomingOrderPanelState();
}

class _IncomingOrderPanelState extends State<_IncomingOrderPanel> {
  Timer? _timer;
  late DateTime _deadline;
  late Duration _remaining;
  bool _expired = false;

  int get _timeout => widget.acceptTimeoutSec.clamp(5, 30);

  @override
  void initState() {
    super.initState();
    _resetDeadline();
  }

  @override
  void didUpdateWidget(covariant _IncomingOrderPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.id != widget.order.id ||
        oldWidget.acceptTimeoutSec != widget.acceptTimeoutSec) {
      _resetDeadline();
    }
  }

  void _resetDeadline() {
    _timer?.cancel();
    _expired = false;
    _deadline = DateTime.now().add(Duration(seconds: _timeout));
    _remaining = Duration(seconds: _timeout);
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    final next = _deadline.difference(DateTime.now());
    if (next <= Duration.zero) {
      _timer?.cancel();
      if (!_expired) {
        _expired = true;
        setState(() => _remaining = Duration.zero);
        widget.onSkip(askReason: false);
      }
      return;
    }
    setState(() => _remaining = next);
  }

  void _accept() {
    _timer?.cancel();
    HapticFeedback.mediumImpact();
    widget.onAccept();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final t = context.tokens;
    final seconds = (_remaining.inMilliseconds / 1000).ceil().clamp(0, 99);
    final urgent = seconds <= 5;
    final timerColor = urgent ? AppColors.error : AppColors.gold;
    final progress =
        (_remaining.inMilliseconds / (_timeout * 1000)).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Новый заказ',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    order.etaMinutes <= 5
                        ? 'Ближняя подача · ~${order.etaMinutes.clamp(1, 99)} мин'
                        : 'Подача · ~${order.etaMinutes.clamp(1, 99)} мин',
                    style: TextStyle(color: t.textSecondary),
                  ),
                ],
              ),
            ),
            _IncomingCountdown(
              seconds: seconds,
              progress: progress,
              color: timerColor,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'Рейтинг пассажира  ${order.clientRating.toStringAsFixed(2)} ★',
          style: TextStyle(color: t.textSecondary, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        _RouteLine(from: order.pickup, to: order.dropoff),
        const SizedBox(height: 12),
        Row(
          children: [
            _OrderMetric(
              icon: Icons.route_rounded,
              label: '${order.distanceKm.toStringAsFixed(1)} км',
            ),
            const SizedBox(width: 8),
            _OrderMetric(
              icon: Icons.payments_outlined,
              label: formatMoney(order.price),
              color: AppColors.gold,
            ),
          ],
        ),
        if ((order.comment ?? '').trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: t.elevated,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              order.comment!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: t.textSecondary, fontSize: 13),
            ),
          ),
        ],
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _expired ? null : _accept,
          icon: const Icon(Icons.check_rounded),
          label: const Text('Принять'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(58),
            backgroundColor: AppColors.gold,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActiveOrderPanel extends StatefulWidget {
  const _ActiveOrderPanel({required this.order, required this.onAction});

  final DriverOrder order;
  final VoidCallback onAction;

  @override
  State<_ActiveOrderPanel> createState() => _ActiveOrderPanelState();
}

class _ActiveOrderPanelState extends State<_ActiveOrderPanel> {
  Timer? _waitTimer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _syncWaitingTimer();
  }

  @override
  void didUpdateWidget(covariant _ActiveOrderPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.id != widget.order.id ||
        oldWidget.order.status != widget.order.status ||
        oldWidget.order.arrivedAt != widget.order.arrivedAt) {
      _syncWaitingTimer();
    }
  }

  void _syncWaitingTimer() {
    _waitTimer?.cancel();
    if (widget.order.status != TripOrderStatus.arrived) return;
    _waitTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _waitTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final order = widget.order;
    final arrivedAt = order.arrivedAt;
    final waitingSeconds = arrivedAt == null
        ? 0
        : _now.difference(arrivedAt).inSeconds.clamp(0, 86400);
    final freeSeconds = order.freeWaitMinutes * 60;
    final isFree = waitingSeconds < freeSeconds;
    final paidSeconds = (waitingSeconds - freeSeconds).clamp(0, 86400);
    final waitingFee = paidSeconds / 60 * order.waitPricePerMinute;
    final actionLabel = switch (order.status) {
      TripOrderStatus.accepted || TripOrderStatus.enroute => 'На месте',
      TripOrderStatus.arrived => 'Начать поездку',
      TripOrderStatus.started => 'Завершить',
      _ => 'Продолжить',
    };
    final title = switch (order.status) {
      TripOrderStatus.arrived => 'Вы на месте',
      TripOrderStatus.started => 'Поездка начата',
      _ => 'Едем к клиенту',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (order.status == TripOrderStatus.enroute ||
                order.status == TripOrderStatus.accepted)
              _OrderMetric(
                icon: Icons.schedule_rounded,
                label: order.etaMinutes > 0
                    ? '~${order.etaMinutes} мин'
                    : 'В пути',
                color: AppColors.purple,
              ),
          ],
        ),
        const SizedBox(height: 12),
        _RouteLine(
          from: order.status == TripOrderStatus.started
              ? order.pickup
              : 'Подача · ${order.pickup}',
          to: 'Куда · ${order.dropoff}',
        ),
        if (order.status == TripOrderStatus.arrived) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.hourglass_top_rounded,
                  size: 18, color: isFree ? AppColors.success : AppColors.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isFree
                      ? 'Бесплатное ожидание · ${_formatWait(freeSeconds - waitingSeconds)}'
                      : 'Платное ожидание · ${formatMoney(waitingFee)} · ${order.waitPricePerMinute.round()} ₽/мин',
                  style: TextStyle(
                    color: isFree ? t.textSecondary : AppColors.gold,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        PrimaryGoldButton(label: actionLabel, onPressed: widget.onAction),
      ],
    );
  }

  String _formatWait(int seconds) {
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${rest.toString().padLeft(2, '0')}';
  }
}

class _CompletedTripPanel extends StatelessWidget {
  const _CompletedTripPanel({required this.order, required this.onDismiss});

  final DriverOrder order;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final total = order.priceFinal ?? order.price;
    final commission = order.commissionAmount?.toDouble() ??
        (order.commissionPercent == null
            ? 0
            : total * order.commissionPercent! / 100);
    final driverIncome =
        (total - commission).clamp(0, double.infinity).toDouble();
    final payment = (order.paymentMethod ?? '').trim().isEmpty
        ? 'Наличные'
        : order.paymentMethod!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.success.withValues(alpha: 0.14),
              ),
              child: const Icon(Icons.check_rounded, color: AppColors.success),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Поездка завершена',
                      style: TextStyle(
                          color: t.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text(order.passengerName,
                      style: TextStyle(color: t.textSecondary)),
                ],
              ),
            ),
            Text(formatMoney(driverIncome),
                style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 18,
                    fontWeight: FontWeight.w900)),
          ],
        ),
        const SizedBox(height: 12),
        _CompletedRoute(order: order),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _OrderMetric(
                icon: Icons.local_taxi_rounded,
                label: order.tariff,
                color: AppColors.purple),
            _OrderMetric(
                icon: Icons.payments_outlined,
                label: payment,
                color: AppColors.gold),
            if (order.tripMinutes != null && order.tripMinutes! > 0)
              _OrderMetric(
                  icon: Icons.timer_outlined,
                  label: '${order.tripMinutes} мин'),
            _OrderMetric(
                icon: Icons.receipt_long_outlined,
                label: 'Заказ ${formatMoney(total)}'),
          ],
        ),
        const SizedBox(height: 11),
        DecoratedBox(
          decoration: BoxDecoration(
            color: t.elevated,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: t.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Text('Ваш доход',
                      style: TextStyle(color: t.textSecondary)),
                ),
                Text(formatMoney(driverIncome),
                    style: const TextStyle(
                        color: AppColors.success, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 11),
        PrimaryGoldButton(label: 'Готово', onPressed: onDismiss),
      ],
    );
  }
}

class _CompletedRoute extends StatelessWidget {
  const _CompletedRoute({required this.order});

  final DriverOrder order;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.elevated,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: t.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CompletedRouteLine(
              icon: Icons.radio_button_checked_rounded,
              color: AppColors.purple,
              label: 'Подача',
              value: order.pickup,
            ),
            const SizedBox(height: 7),
            _CompletedRouteLine(
              icon: Icons.location_on_rounded,
              color: AppColors.gold,
              label: 'Назначение',
              value: order.dropoff,
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletedRouteLine extends StatelessWidget {
  const _CompletedRouteLine({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 9),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: '$label · ',
              style: TextStyle(color: t.textMuted, fontSize: 12),
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                      color: t.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _VerificationPanel extends StatelessWidget {
  const _VerificationPanel({required this.profile});

  final DriverProfile profile;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final status = normalizeRegistrationStatus(profile.registrationStatus);
    final blocked = profile.registrationBlocked;

    late final String title;
    late final String subtitle;
    late final IconData icon;
    late final Color color;

    if (blocked) {
      title = 'Аккаунт заблокирован';
      subtitle = profile.blockReason?.trim().isNotEmpty == true
          ? profile.blockReason!.trim()
          : 'Доступ к линии ограничен. Обратитесь в поддержку.';
      icon = Icons.block_rounded;
      color = AppColors.error;
    } else {
      switch (status) {
        case 'pending':
          title = 'Документы на проверке';
          subtitle =
              'После проверки документов переключатель «На линии» станет доступен.';
          icon = Icons.hourglass_top_rounded;
          color = AppColors.warning;
        case 'rejected':
          title = 'Нужны правки';
          subtitle = profile.rejectionReason?.trim().isNotEmpty == true
              ? profile.rejectionReason!.trim()
              : 'Исправьте данные и отправьте заявку повторно.';
          icon = Icons.edit_note_rounded;
          color = AppColors.error;
        case 'incomplete':
          title = 'Завершите регистрацию';
          subtitle = 'Заполните анкету и загрузите документы.';
          icon = Icons.drafts_outlined;
          color = AppColors.warning;
        default:
          title = 'Доступ к линии ограничен';
          subtitle =
              'После проверки документов переключатель «На линии» станет доступен.';
          icon = Icons.verified_user_outlined;
          color = AppColors.warning;
      }
    }

    return Column(
      children: [
        Icon(icon, color: color, size: 46),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: t.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: t.textSecondary),
        ),
        const SizedBox(height: 16),
        if (blocked || status == 'blocked')
          OutlinedButton.icon(
            onPressed: () => context.push(AppRoutes.support),
            icon: const Icon(Icons.support_agent_rounded),
            label: const Text('Написать в поддержку'),
          )
        else if (status == 'rejected' || status == 'incomplete')
          FilledButton(
            onPressed: () => context.go(AppRoutes.registration),
            child: Text(
              status == 'rejected'
                  ? 'Исправить и отправить'
                  : 'Продолжить регистрацию',
            ),
          )
        else
          FilledButton(
            onPressed: () => context.go(AppRoutes.registrationStatus),
            child: const Text('Статус регистрации'),
          ),
      ],
    );
  }
}

class _OrderMetric extends StatelessWidget {
  const _OrderMetric({
    required this.icon,
    required this.label,
    this.color = AppColors.textSecondary,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: t.elevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: t.textPrimary, fontSize: 12)),
        ],
      ),
    );
  }
}

class _RouteLine extends StatelessWidget {
  const _RouteLine({required this.from, required this.to});

  final String from;
  final String to;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            const Icon(Icons.circle, size: 12, color: AppColors.purple),
            Container(width: 2, height: 31, color: t.border),
            const Icon(Icons.location_on_rounded,
                size: 18, color: AppColors.gold),
          ],
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                from,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: t.textPrimary, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 17),
              Text(
                to,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: t.textPrimary, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
