import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart'; // ApiException, ApiConfigStore
import '../../core/api/models/api_models.dart';
import '../../core/api/services/api_services.dart';
import '../../core/api/socket_service.dart';
import '../../core/auth/auth_store.dart';
import '../../core/geo/geo_math.dart';
import '../../core/geo/yandex_routing_service.dart';
import '../../core/order/order_status_ui.dart';
import '../../core/services/push_service.dart';
import '../../models/payment_method.dart';
import '../../models/service_type.dart';
import '../map/map_geo.dart';

/// Активная поездка: Socket.IO + REST polling fallback.
class ActiveTripProvider extends ChangeNotifier {
  ActiveTripProvider({
    ApiServices? apiServices,
    SocketService? socketService,
    AuthStore? authStore,
    YandexRoutingService? routingService,
  })  : _api = apiServices ?? ApiServices(),
        _socket = socketService ?? SocketService(),
        _auth = authStore ?? AuthStore(),
        _routing = routingService ?? YandexRoutingService(),
        _ownsSocket = socketService == null,
        _ownsRouting = routingService == null;

  final ApiServices _api;
  final SocketService _socket;
  final AuthStore _auth;
  final YandexRoutingService _routing;
  final bool _ownsSocket;
  final bool _ownsRouting;

  OrderDto? _order;
  double? _driverLat;
  double? _driverLng;
  String? _statusMessage;
  String? _error;
  bool _loading = false;
  bool _busy = false;
  int _nearbyDriverCount = 0;
  List<MapPoint> _nearbyVehicles = const [];
  List<MapPoint> _tripRoutePoints = const [];
  List<MapPoint> _activeRoutePoints = const [];
  MapPoint? _pickupPoint;
  MapPoint? _destinationPoint;

  final List<StreamSubscription<dynamic>> _subs = [];
  Timer? _pollTimer;
  Timer? _approachRouteDebounce;
  final List<Timer> _demoTimers = [];
  int _approachRouteRequestId = 0;
  bool _refreshInFlight = false;
  bool? _lastSocketConnected;
  bool _socketListenerBound = false;
  bool _demoMode = false;

  OrderDto? get order => _order;
  double? get driverLat => _driverLat;
  double? get driverLng => _driverLng;
  String? get statusMessage => _statusMessage;
  String? get error => _error;
  bool get loading => _loading;
  bool get busy => _busy;
  int get nearbyDriverCount => _nearbyDriverCount;
  List<MapPoint> get nearbyVehicles => _nearbyVehicles;
  List<MapPoint> get mapRoutePoints =>
      _activeRoutePoints.length >= 2 ? _activeRoutePoints : _tripRoutePoints;
  bool get isConnected => _demoMode || _socket.isConnected;
  SocketService get socket => _socket;

  int get statusStep {
    final status = _order?.status ?? 'searching';
    return OrderStatusUi.stepFor(status);
  }

  String get statusLabel {
    final status = _order?.status ?? 'searching';
    return OrderStatusUi.labelFor(status);
  }

  Future<void> start({
    String? orderId,
    String? fromAddress,
    String? toAddress,
    double? fromLat,
    double? fromLng,
    double? toLat,
    double? toLng,
    double? price,
    PaymentMethod? paymentMethod,
    ServiceType? serviceType,
    String? tariffName,
    List<MapPoint> bookingRoutePoints = const [],
  }) async {
    _loading = true;
    _error = null;
    PushService.instance.resetStatusDedupe();
    if (PushService.instance.enabled) {
      unawaited(PushService.instance.requestPermission());
    }
    _clearDemoTimers();
    _demoMode = false;
    _pickupPoint = _safePointOrNull(fromLat, fromLng);
    _destinationPoint = _safePointOrNull(toLat, toLng);
    _tripRoutePoints = bookingRoutePoints.length >= 2
        ? bookingRoutePoints
        : (_pickupPoint != null && _destinationPoint != null)
            ? buildRoutePoints(
                fromLat: _pickupPoint!.lat,
                fromLng: _pickupPoint!.lng,
                toLat: _destinationPoint!.lat,
                toLng: _destinationPoint!.lng,
              )
            : const [];
    _activeRoutePoints = _tripRoutePoints;
    notifyListeners();

    try {
      if (orderId != null && orderId.startsWith('demo-')) {
        _demoMode = true;
        _startDemoTrip(
          orderId: orderId,
          fromAddress: fromAddress,
          toAddress: toAddress,
          fromLat: fromLat,
          fromLng: fromLng,
          toLat: toLat,
          toLng: toLng,
          price: price,
          paymentMethod: paymentMethod,
          serviceType: serviceType,
          tariffName: tariffName,
        );
        return;
      }

      final token = await _auth.readToken();
      if (token != null && !ApiConfigStore.instance.useMockApi) {
        _socket.connect(token: token);
      }

      OrderDto? order;
      if (orderId != null && orderId.isNotEmpty) {
        try {
          order = await _api.order.fetchOrder(orderId);
        } catch (_) {}
      }
      order ??= await _api.order.fetchActiveOrder();

      if (order == null && orderId != null) {
        order = OrderDto(id: orderId, status: 'searching');
      }

      _order = order;
      if (_order?.driverLat != null) _driverLat = _order!.driverLat;
      if (_order?.driverLng != null) _driverLng = _order!.driverLng;
      _statusMessage = statusLabel;
      _syncRouteForCurrentStatus();
      _bindSocketListeners();
      if (!_socketListenerBound) {
        _socketListenerBound = true;
        _lastSocketConnected = _socket.isConnected;
        _socket.addListener(_handleSocketStateChanged);
      }
      _startPolling();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'Не удалось загрузить статус поездки';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _startDemoTrip({
    required String orderId,
    String? fromAddress,
    String? toAddress,
    double? fromLat,
    double? fromLng,
    double? toLat,
    double? toLng,
    double? price,
    PaymentMethod? paymentMethod,
    ServiceType? serviceType,
    String? tariffName,
  }) {
    final pickup = _safePoint(
      lat: fromLat,
      lng: fromLng,
      fallback: (lat: 55.751244, lng: 37.618423),
    );
    final destination = _safePoint(
      lat: toLat,
      lng: toLng,
      fallback: (lat: pickup.lat + 0.035, lng: pickup.lng + 0.045),
    );
    final priceRub = (price ?? 1200).round().clamp(250, 999999);
    _pickupPoint = pickup;
    _destinationPoint = destination;
    if (_tripRoutePoints.length < 2) {
      _tripRoutePoints = buildRoutePoints(
        fromLat: pickup.lat,
        fromLng: pickup.lng,
        toLat: destination.lat,
        toLng: destination.lng,
      );
    }
    _activeRoutePoints = _tripRoutePoints;

    _driverLat = null;
    _driverLng = null;
    _nearbyDriverCount = 0;
    _nearbyVehicles = _demoVehiclesAround(pickup);
    _order = OrderDto(
      id: orderId,
      status: 'searching',
      fromAddress: fromAddress,
      toAddress: toAddress,
      serviceType: serviceType,
      paymentMethod: paymentMethod,
      paymentStatus: 'unpaid',
      priceFrom: priceRub,
      tariffName: tariffName,
      tripMinutes: 5,
      createdAt: DateTime.now(),
    );
    _statusMessage = 'Ищем водителя';

    _scheduleDemo(const Duration(milliseconds: 1400), () {
      _nearbyDriverCount = 7;
      _statusMessage = 'Ждём ответ водителя';
      notifyListeners();
    });

    _scheduleDemo(const Duration(seconds: 3), () {
      final driver = (lat: pickup.lat + 0.016, lng: pickup.lng - 0.021);
      _driverLat = driver.lat;
      _driverLng = driver.lng;
      _nearbyDriverCount = 0;
      _nearbyVehicles = const [];
      _order = _order?.copyWith(
        status: 'accepted',
        driverPhone: '+7 901 555-01-77',
        driverName: 'Алексей',
        driverPlate: 'А123ВС 77',
        driverRating: 4.9,
        carModel: 'Hyundai Solaris',
        driverLat: _driverLat,
        driverLng: _driverLng,
        tripMinutes: 5,
      );
      _statusMessage = 'Водитель принял заказ';
      unawaited(PushService.instance.notifyOrderStatus('accepted'));
      unawaited(_resolveApproachRoute(driver, pickup));
      notifyListeners();
    });

    _scheduleDemo(const Duration(seconds: 8), () {
      final driver = _pointAlongRoute(_activeRoutePoints, 0.72, pickup);
      _driverLat = driver.lat;
      _driverLng = driver.lng;
      _order = _order?.copyWith(
        status: 'enroute',
        driverLat: _driverLat,
        driverLng: _driverLng,
        tripMinutes: 2,
      );
      _statusMessage = 'Водитель едет к вам';
      unawaited(PushService.instance.notifyOrderStatus('enroute'));
      notifyListeners();
    });

    _scheduleDemo(const Duration(seconds: 13), () {
      _driverLat = pickup.lat;
      _driverLng = pickup.lng;
      _order = _order?.copyWith(
        status: 'arrived',
        driverLat: _driverLat,
        driverLng: _driverLng,
        tripMinutes: 1,
        arrivedAt: DateTime.now(),
      );
      _statusMessage = 'Водитель на месте';
      unawaited(PushService.instance.notifyOrderStatus('arrived'));
      notifyListeners();
    });

    _scheduleDemo(const Duration(seconds: 18), () {
      _activeRoutePoints = _tripRoutePoints;
      final driver = _pointAlongRoute(_tripRoutePoints, 0.28, destination);
      _driverLat = driver.lat;
      _driverLng = driver.lng;
      _order = _order?.copyWith(
        status: 'started',
        driverLat: _driverLat,
        driverLng: _driverLng,
        tripMinutes: 7,
      );
      _statusMessage = 'Поездка началась';
      unawaited(PushService.instance.notifyOrderStatus('started'));
      notifyListeners();
    });

    _scheduleDemo(const Duration(seconds: 23), () {
      final driver = _pointAlongRoute(_tripRoutePoints, 0.68, destination);
      _driverLat = driver.lat;
      _driverLng = driver.lng;
      _order = _order?.copyWith(
        driverLat: _driverLat,
        driverLng: _driverLng,
        tripMinutes: 3,
      );
      notifyListeners();
    });

    _scheduleDemo(const Duration(seconds: 27), () {
      _driverLat = destination.lat;
      _driverLng = destination.lng;
      _order = _order?.copyWith(
        status: 'completed',
        driverLat: _driverLat,
        driverLng: _driverLng,
        priceFinal: priceRub,
        completedAt: DateTime.now(),
        tripMinutes: 12,
      );
      _statusMessage = 'Поездка завершена';
      unawaited(PushService.instance.notifyOrderStatus('completed'));
      notifyListeners();
    });
  }

  void _scheduleDemo(Duration delay, VoidCallback action) {
    _demoTimers.add(Timer(delay, () {
      if (!_demoMode) return;
      action();
    }));
  }

  void _clearDemoTimers() {
    for (final timer in _demoTimers) {
      timer.cancel();
    }
    _demoTimers.clear();
  }

  MapPoint _safePoint({
    required double? lat,
    required double? lng,
    required MapPoint fallback,
  }) {
    if (lat == null || lng == null || lat.abs() > 90 || lng.abs() > 180) {
      return fallback;
    }
    return (lat: lat, lng: lng);
  }

  MapPoint _lerpPoint(MapPoint a, MapPoint b, double t) {
    return (
      lat: a.lat + (b.lat - a.lat) * t,
      lng: a.lng + (b.lng - a.lng) * t,
    );
  }

  MapPoint? _safePointOrNull(double? lat, double? lng) {
    if (lat == null || lng == null || lat.abs() > 90 || lng.abs() > 180) {
      return null;
    }
    return (lat: lat, lng: lng);
  }

  MapPoint _pointAlongRoute(
    List<MapPoint> route,
    double progress,
    MapPoint fallback,
  ) {
    if (route.length < 2) return fallback;
    final scaled = progress.clamp(0.0, 1.0) * (route.length - 1);
    final index = scaled.floor().clamp(0, route.length - 2);
    return _lerpPoint(route[index], route[index + 1], scaled - index);
  }

  void _syncRouteForCurrentStatus() {
    final status = _order?.status;
    if (status == 'started' || status == 'completed') {
      _activeRoutePoints = _tripRoutePoints;
      return;
    }
    if ({'accepted', 'enroute', 'arrived'}.contains(status)) {
      final driver = _safePointOrNull(_driverLat, _driverLng);
      final pickup = _pickupPoint;
      if (driver != null && pickup != null) {
        _scheduleApproachRouteRefresh(driver, pickup, immediate: true);
      }
    }
  }

  void _scheduleApproachRouteRefresh(
    MapPoint driver,
    MapPoint pickup, {
    bool immediate = false,
  }) {
    _approachRouteDebounce?.cancel();
    if (immediate) {
      unawaited(_resolveApproachRoute(driver, pickup));
      return;
    }
    _approachRouteDebounce = Timer(const Duration(seconds: 4), () {
      unawaited(_resolveApproachRoute(driver, pickup));
    });
  }

  Future<void> _resolveApproachRoute(
    MapPoint driver,
    MapPoint pickup,
  ) async {
    final requestId = ++_approachRouteRequestId;
    try {
      final route = await _routing.resolveRoute(
        fromLat: driver.lat,
        fromLng: driver.lng,
        toLat: pickup.lat,
        toLng: pickup.lng,
      );
      if (requestId != _approachRouteRequestId) return;
      if (!{'accepted', 'enroute', 'arrived'}.contains(_order?.status)) return;
      if (route.points.length >= 2) {
        _activeRoutePoints = route.points;
        notifyListeners();
      }
    } catch (_) {
      if (requestId != _approachRouteRequestId) return;
      _activeRoutePoints = buildRoutePoints(
        fromLat: driver.lat,
        fromLng: driver.lng,
        toLat: pickup.lat,
        toLng: pickup.lng,
      );
      notifyListeners();
    }
  }

  List<MapPoint> _demoVehiclesAround(MapPoint pickup) {
    const offsets = [
      (lat: 0.004, lng: -0.006),
      (lat: -0.003, lng: 0.005),
      (lat: 0.007, lng: 0.003),
      (lat: -0.006, lng: -0.004),
      (lat: 0.002, lng: 0.009),
      (lat: -0.008, lng: 0.002),
      (lat: 0.009, lng: -0.002),
    ];
    return offsets
        .map((o) => (lat: pickup.lat + o.lat, lng: pickup.lng + o.lng))
        .toList(growable: false);
  }

  void _bindSocketListeners() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();

    _subs.add(_socket.onOrderStatus.listen((data) {
      final orderId = data['orderId']?.toString() ??
          (data['order'] is Map
              ? (data['order'] as Map)['id']?.toString()
              : null);
      if (_order != null &&
          orderId != null &&
          orderId.isNotEmpty &&
          orderId != _order!.id) {
        return;
      }

      final status = data['status']?.toString();
      final driverPhone = data['driverPhone']?.toString();
      if (status != null && _order != null) {
        _order = _order!.copyWith(
          status: status,
          driverPhone: driverPhone ?? _order!.driverPhone,
        );
        _statusMessage = statusLabel;
        unawaited(PushService.instance.notifyOrderStatus(status));
        if (status != 'searching') {
          _nearbyDriverCount = 0;
          _nearbyVehicles = const [];
        }
        _syncRouteForCurrentStatus();
        notifyListeners();
      } else if (data['order'] is Map) {
        final parsed = OrderDto.fromJson(
          (data['order'] as Map).cast<String, dynamic>(),
        );
        if (_order == null || parsed.id == _order!.id || _order!.id.isEmpty) {
          _order = parsed;
          _statusMessage = statusLabel;
          unawaited(
            PushService.instance.notifyOrderStatus(parsed.status),
          );
          _syncRouteForCurrentStatus();
          notifyListeners();
        }
      }
    }));

    _subs.add(_socket.onDriverLocation.listen((data) {
      final lat = _toDouble(data['lat'] ?? data['driverLat']);
      final lng = _toDouble(data['lng'] ?? data['driverLng']);
      if (lat != null && lng != null) {
        _driverLat = lat;
        _driverLng = lng;
        final pickup = _pickupPoint;
        if (pickup != null &&
            {'accepted', 'enroute'}.contains(_order?.status)) {
          _scheduleApproachRouteRefresh((lat: lat, lng: lng), pickup);
        }
        notifyListeners();
      }
    }));

    _subs.add(_socket.onOrderDelay.listen((data) {
      final message = data['message']?.toString() ??
          data['text']?.toString() ??
          data['reason']?.toString();
      if (message != null && message.isNotEmpty) {
        _statusMessage = message;
      }
      final count = _toInt(data['candidateCount']);
      if (count != null) _nearbyDriverCount = count.clamp(0, 12);
      if (data.containsKey('candidateLocations')) {
        _nearbyVehicles = _parseVehicleLocations(data['candidateLocations']);
      } else if (count == 0) {
        _nearbyVehicles = const [];
      }
      notifyListeners();
    }));
  }

  List<MapPoint> _parseVehicleLocations(dynamic raw) {
    if (raw is! List) return const [];
    final points = <MapPoint>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final lat = _toDouble(item['lat']);
      final lng = _toDouble(item['lng']);
      if (lat == null || lng == null) continue;
      points.add((lat: lat, lng: lng));
    }
    return points.take(12).toList(growable: false);
  }

  void _startPolling() {
    _pollTimer?.cancel();
    if (ApiConfigStore.instance.useMockApi) return;
    // Socket events carry live state. REST remains a slow reconciliation path;
    // when the socket is down, polling speeds up without hammering the server.
    final interval = _socket.isConnected
        ? const Duration(seconds: 30)
        : const Duration(seconds: 10);
    _pollTimer = Timer.periodic(interval, (_) {
      unawaited(_refreshFromApi());
    });
  }

  void _handleSocketStateChanged() {
    final connected = _socket.isConnected;
    if (_lastSocketConnected == connected) return;
    _lastSocketConnected = connected;
    _startPolling();
    if (connected) unawaited(_refreshFromApi());
  }

  Future<void> _refreshFromApi() async {
    final current = _order;
    if (_refreshInFlight || current == null || current.id.isEmpty) return;
    if ({'completed', 'canceled', 'cancelled'}.contains(current.status)) {
      _pollTimer?.cancel();
      return;
    }
    _refreshInFlight = true;
    try {
      final fresh = await _api.order.fetchOrder(current.id);
      final statusChanged = fresh.status != current.status;
      _order = fresh;
      if (fresh.driverLat != null) _driverLat = fresh.driverLat;
      if (fresh.driverLng != null) _driverLng = fresh.driverLng;
      _statusMessage = statusLabel;
      if (statusChanged) {
        unawaited(PushService.instance.notifyOrderStatus(fresh.status));
      }
      _syncRouteForCurrentStatus();
      notifyListeners();
    } catch (_) {
    } finally {
      _refreshInFlight = false;
    }
  }

  Future<void> retry() => start(orderId: _order?.id);

  Future<bool> cancel({String? reason}) async {
    final id = _order?.id;
    if (id == null || id.isEmpty || _busy) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      if (_demoMode) {
        _clearDemoTimers();
        _order = _order?.copyWith(status: 'canceled');
        _statusMessage = statusLabel;
        _nearbyDriverCount = 0;
        _nearbyVehicles = const [];
        unawaited(PushService.instance.notifyOrderStatus('canceled'));
        return true;
      }
      await _api.order.cancelOrder(id, reason: reason);
      _order = _order?.copyWith(status: 'canceled');
      _statusMessage = statusLabel;
      _pollTimer?.cancel();
      unawaited(PushService.instance.notifyOrderStatus('canceled'));
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (_) {
      _error = 'Не удалось отменить заказ';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<bool> rate({required int rating, String? comment}) async {
    final id = _order?.id;
    if (id == null || id.isEmpty || _busy) return false;
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      if (_demoMode) return true;
      await _api.order.rateOrder(id, rating: rating, comment: comment);
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } catch (_) {
      _error = 'Не удалось отправить оценку';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  double? _toDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  int? _toInt(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _approachRouteDebounce?.cancel();
    _clearDemoTimers();
    if (_socketListenerBound) _socket.removeListener(_handleSocketStateChanged);
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    if (_ownsSocket) {
      _socket.dispose();
    }
    if (_ownsRouting) {
      _routing.dispose();
    }
    super.dispose();
  }
}
