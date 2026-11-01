import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/api/models/api_models.dart';
import '../../core/session/active_order_store.dart';
import '../../core/geo/geo_math.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../features/booking/providers/booking_provider.dart';
import '../../features/map/map_host.dart';
import '../../features/map/map_camera_controller.dart';
import '../../features/map/map_geo.dart';
import '../../features/map/map_trip_ui.dart';
import '../../features/payment/rate_trip_screen.dart';
import '../../shared/utils/app_snackbar.dart';
import '../../shared/utils/formatters.dart';
import '../../shared/widgets/cancel_reason_sheet.dart';
import 'active_trip_provider.dart';
import 'trip_chat_provider.dart';
import 'trip_chat_sheet.dart';

class ActiveTripScreen extends StatefulWidget {
  const ActiveTripScreen({super.key});

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen> {
  late final ActiveTripProvider _trip;
  final _mapCamera = MapCameraController();
  bool _pushedRating = false;
  bool _mapManuallyAdjusted = false;
  String? _lastFittedStatus;

  @override
  void initState() {
    super.initState();
    final booking = context.read<BookingProvider>().booking;
    _trip = ActiveTripProvider(
      apiServices: context.read<BookingProvider>().apiServices,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trip.start(
        orderId: booking.orderId,
        fromAddress: booking.fromAddress,
        toAddress: booking.toAddress,
        fromLat: booking.fromLat,
        fromLng: booking.fromLng,
        toLat: booking.toLat,
        toLng: booking.toLng,
        price: booking.estimatedPrice,
        paymentMethod: booking.paymentMethod,
        serviceType: booking.serviceType,
        tariffName: booking.selectedTariff?.name,
        bookingRoutePoints: booking.routePoints,
      );
    });
  }

  @override
  void dispose() {
    _trip.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    final reason = await showCancelReasonSheet(context);
    if (reason == null || !mounted) return;
    final ok = await _trip.cancel(reason: reason);
    if (!mounted) return;
    if (ok) {
      await ActiveOrderStore.clear();
      if (!mounted) return;
      context.read<BookingProvider>().reset();
      context.go(AppRoutes.home);
    } else {
      showAppSnackBar(
        context,
        _trip.error ?? 'Не удалось отменить заказ',
        isError: true,
      );
    }
  }

  Future<void> _callDriver() async {
    final phone = _trip.order?.driverPhone;
    if (phone == null || phone.isEmpty) {
      showAppSnackBar(context, 'Номер водителя пока недоступен', isError: true);
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      showAppSnackBar(context, 'Не удалось открыть звонок', isError: true);
    }
  }

  void _chatDriver() {
    final order = _trip.order;
    if (order == null || order.id.isEmpty) {
      showAppSnackBar(context, 'Заказ ещё не создан', isError: true);
      return;
    }

    final booking = context.read<BookingProvider>();
    final useMock =
        ApiConfigStore.instance.useMockApi || order.id.startsWith('demo-');
    final chat = TripChatProvider(
      orderId: order.id,
      socket: _trip.socket,
      useMockApi: useMock,
      loadHistory: () async {
        final dtos = await booking.apiServices.order.fetchOrderChat(order.id);
        return dtos
            .map(
              (d) => TripChatMessage(
                id: d.id.isNotEmpty
                    ? d.id
                    : '${d.from}_${d.createdAt.millisecondsSinceEpoch}',
                from: d.from,
                body: d.body,
                createdAt: d.createdAt,
              ),
            )
            .toList();
      },
      sendRest: (text) =>
          booking.apiServices.order.sendOrderChat(order.id, text),
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TripChatSheet(
        driverName: order.driverName ?? 'Водитель',
        provider: chat,
      ),
    ).whenComplete(chat.dispose);
  }

  void _showTripDetails() {
    final order = _trip.order;
    final booking = context.read<BookingProvider>().booking;
    final from = order?.fromAddress ?? booking.fromAddress;
    final to = order?.toAddress ?? booking.toAddress;
    final tariff = order?.tariffName ?? booking.selectedTariff?.name ?? 'Такси';
    final payment = order?.paymentMethod?.label ?? booking.paymentMethod.label;
    final price = (order?.displayPrice ?? booking.estimatedPrice)?.toDouble();

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.backgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Детали поездки',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              _TripDetailRow(
                icon: Icons.trip_origin_rounded,
                label: 'Подача',
                value: from,
                color: AppColors.purple,
              ),
              _TripDetailRow(
                icon: Icons.location_on_rounded,
                label: 'Куда',
                value: to,
                color: AppColors.gold,
              ),
              _TripDetailRow(
                icon: Icons.local_taxi_rounded,
                label: 'Тариф',
                value: tariff,
              ),
              _TripDetailRow(
                icon: Icons.payments_outlined,
                label: 'Оплата',
                value: price == null
                    ? payment
                    : '$payment · ${formatPriceExact(price)}',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareTripStatus() async {
    final order = _trip.order;
    final booking = context.read<BookingProvider>().booking;
    final status = _trip.statusMessage ?? _trip.statusLabel;
    final from = order?.fromAddress ?? booking.fromAddress;
    final to = order?.toAddress ?? booking.toAddress;
    final driver = order?.driverName ?? 'водитель';
    final plate = order?.driverPlate ?? '';
    final text = StringBuffer('КОРОЛИ ДОРОГ · статус поездки\n')
      ..writeln(status)
      ..writeln('$from → $to');
    if (plate.isNotEmpty) text.writeln('$driver · $plate');
    if (order?.id != null) text.writeln('Заказ ${order!.id}');

    try {
      await Share.share(
        text.toString().trim(),
        subject: 'КОРОЛИ ДОРОГ · статус поездки',
      );
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Не удалось открыть меню «Поделиться»',
        isError: true,
      );
    }
  }

  void _openRating(OrderDto order, BookingProvider bookingProvider) {
    if (_pushedRating) return;
    _pushedRating = true;
    final booking = bookingProvider.booking;
    context.go(
      AppRoutes.rateTrip,
      extra: RateTripArgs(
        orderId: order.id,
        fromAddress: order.fromAddress ?? booking.fromAddress,
        toAddress: order.toAddress ?? booking.toAddress,
        price: (order.displayPrice ?? booking.estimatedPrice)?.toDouble(),
        driverName: order.driverName,
        driverRating: order.driverRating,
        driverPlate: order.driverPlate,
        carModel: order.carModel,
      ),
    );
  }

  String? _etaLabel(OrderDto? order) {
    final m = order?.tripMinutes;
    if (m == null || m <= 0) return null;
    return '$m мин';
  }

  String? _fareLabel(OrderDto? order) {
    final price = order?.displayPrice;
    if (price == null) return null;
    return formatPriceExact(price.toDouble());
  }

  double _zoomForRoute(List<MapPoint> points) {
    if (points.length < 2) return 15.5;
    final lats = points.map((p) => p.lat);
    final lngs = points.map((p) => p.lng);
    final span = [
      lats.reduce((a, b) => a > b ? a : b) -
          lats.reduce((a, b) => a < b ? a : b),
      lngs.reduce((a, b) => a > b ? a : b) -
          lngs.reduce((a, b) => a < b ? a : b),
    ].reduce((a, b) => a > b ? a : b);
    if (span > 8) return 5.6;
    if (span > 4) return 6.4;
    if (span > 2) return 7.4;
    if (span > 1) return 8.5;
    if (span > 0.45) return 9.8;
    if (span > 0.18) return 11.0;
    if (span > 0.08) return 12.2;
    return 13.4;
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _trip,
      child: Consumer<ActiveTripProvider>(
        builder: (context, trip, _) {
          if (trip.loading) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Загружаем поездку…',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            );
          }

          if (trip.error != null && trip.order == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Активная поездка')),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppColors.error,
                      ),
                      const SizedBox(height: 16),
                      Text(trip.error!, textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: trip.retry,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          final order = trip.order;
          final bookingProvider = context.watch<BookingProvider>();
          final booking = bookingProvider.booking;
          final tariffName =
              order?.tariffName ?? booking.selectedTariff?.name ?? 'Эконом';
          final completed = order?.isCompleted == true;
          final searching = (order?.status ?? 'searching') == 'searching';
          final driverComing = {'accepted', 'enroute'}.contains(order?.status);
          final inTrip = order?.status == 'started';
          final approaching = !searching &&
              !completed &&
              {'accepted', 'enroute', 'arrived', 'started'}
                  .contains(order?.status);
          final eta = _etaLabel(order);
          final fare = _fareLabel(order);
          final topPad = MediaQuery.paddingOf(context).top;
          final isArrived = order?.status == 'arrived';
          final routePoints = trip.mapRoutePoints.length >= 2
              ? trip.mapRoutePoints
              : booking.routePoints.length >= 2
                  ? booking.routePoints
                  : routePointsForBooking(
                      fromLat: booking.fromLat,
                      fromLng: booking.fromLng,
                      toLat: booking.toLat,
                      toLng: booking.toLng,
                    );

          final fitStatus = order?.status ?? 'searching';
          if (_lastFittedStatus != fitStatus &&
              !_mapManuallyAdjusted &&
              routePoints.length >= 2) {
            _lastFittedStatus = fitStatus;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              final lat =
                  routePoints.map((p) => p.lat).reduce((a, b) => a + b) /
                      routePoints.length;
              final lng =
                  routePoints.map((p) => p.lng).reduce((a, b) => a + b) /
                      routePoints.length;
              _mapCamera.moveTo(lat, lng, zoom: _zoomForRoute(routePoints));
            });
          }

          if (completed && order != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (mounted) {
                await ActiveOrderStore.clear();
                _openRating(order, bookingProvider);
              }
            });
          }

          return Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: MapHost(
                    routePoints: routePoints,
                    showUserPin: searching,
                    showDriverMarker: approaching,
                    nearbyVehicleCount: searching ? trip.nearbyDriverCount : 0,
                    nearbyVehicles: searching ? trip.nearbyVehicles : const [],
                    demoCruise: false,
                    driverLat: trip.driverLat,
                    driverLng: trip.driverLng,
                    showSetupHint: false,
                    cameraController: _mapCamera,
                    onCameraMoving: () {
                      if (_mapManuallyAdjusted || !mounted) return;
                      setState(() => _mapManuallyAdjusted = true);
                    },
                    nightMode: context.isDarkTheme,
                  ),
                ),
                Positioned(
                  top: topPad + 8,
                  right: 6,
                  child: Column(
                    children: [
                      Material(
                        color:
                            context.palette.bgSecondary.withValues(alpha: 0.96),
                        shape: const CircleBorder(),
                        elevation: 4,
                        child: IconButton(
                          tooltip: 'Показать маршрут',
                          onPressed: routePoints.length < 2
                              ? null
                              : () {
                                  final lat = routePoints
                                          .map((p) => p.lat)
                                          .reduce((a, b) => a + b) /
                                      routePoints.length;
                                  final lng = routePoints
                                          .map((p) => p.lng)
                                          .reduce((a, b) => a + b) /
                                      routePoints.length;
                                  setState(() => _mapManuallyAdjusted = false);
                                  _mapCamera.moveTo(
                                    lat,
                                    lng,
                                    zoom: _zoomForRoute(routePoints),
                                  );
                                },
                          icon: const Icon(
                            Icons.my_location_rounded,
                            color: AppColors.gold,
                          ),
                        ),
                      ),
                      if (!trip.isConnected && !searching) ...[
                        const SizedBox(height: 8),
                        const MapOverlayChip(
                          icon: Icons.cloud_off_outlined,
                          label: 'Офлайн',
                          accent: AppColors.gold,
                        ),
                      ],
                    ],
                  ),
                ),
                if (!searching && (eta != null || fare != null || isArrived))
                  Positioned(
                    top: topPad + 56,
                    left: 16,
                    right: 16,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (eta != null)
                          MapOverlayChip(
                            icon: Icons.schedule_rounded,
                            label: eta,
                            accent: AppColors.purple,
                          ),
                        if (fare != null)
                          MapOverlayChip(
                            icon: Icons.payments_outlined,
                            label: fare,
                            accent: AppColors.gold,
                          ),
                        if (isArrived)
                          ArrivedWaitChip(
                            key: ValueKey('wait-${order?.id}'),
                            arrivedAt: order?.arrivedAt,
                          ),
                      ],
                    ),
                  ),
                MapBottomSheet(
                  halfHeightFactor: searching ? 0.24 : 0.34,
                  maxHeightFactor: searching ? 0.24 : 0.34,
                  expandable: false,
                  child: searching
                      ? SearchingDriverPanel(
                          nearbyDriverCount: trip.nearbyDriverCount > 0
                              ? trip.nearbyDriverCount
                              : 5,
                          onCancel: order?.isActive == true ? _cancel : null,
                          onDetails: _showTripDetails,
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              driverComing && eta != null
                                  ? 'Через ~$eta приедет'
                                  : inTrip && eta != null
                                      ? 'Осталось ехать ~$eta'
                                      : trip.statusMessage ?? trip.statusLabel,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: context.isDarkTheme
                                    ? AppColors.gold
                                    : AppColors.goldDark,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (approaching)
                              TripDriverCard(
                                name: order?.driverName ??
                                    order?.driverPhone ??
                                    'Водитель',
                                plate: order?.driverPlate,
                                subtitle: [
                                  if ((order?.carModel ?? '').isNotEmpty)
                                    order!.carModel!,
                                  if (tariffName.isNotEmpty) tariffName,
                                ].where((e) => e.isNotEmpty).join(' · '),
                                rating: order?.driverRating ?? 4.9,
                                carAssetPath:
                                    'assets/images/tariffs/${booking.selectedTariff?.icon ?? 'comfort_plus'}.png',
                                onCall: _callDriver,
                                onChat: _chatDriver,
                                onShare: _shareTripStatus,
                                onDetails: _showTripDetails,
                              ),
                            if (!completed && !approaching) ...[
                              const SizedBox(height: 8),
                              if (order?.isActive == true)
                                TextButton(
                                  onPressed: trip.busy ? null : _cancel,
                                  child: const Text(
                                    'Отменить заказ',
                                    style: TextStyle(color: AppColors.error),
                                  ),
                                ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TripDetailRow extends StatelessWidget {
  const _TripDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color ?? p.textSecondary, size: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: p.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    height: 1.18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
