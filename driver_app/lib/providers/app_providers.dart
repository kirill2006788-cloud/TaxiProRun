import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api/app_services.dart';
import '../core/api/api_config.dart';
import '../core/api/api_exception.dart';
import '../core/api/driver_location_ticker.dart';
import '../core/api/repositories/repositories.dart';
import '../core/api/services/driver_profile_service.dart';
import '../core/api/socket_service.dart';
import '../core/api/trip_status_machine.dart';
import '../core/auth/phone_utils.dart';
import '../core/network/connectivity_monitor.dart';
import '../core/services/push_service.dart';
import '../data/mock_data.dart';
import '../models/registration_draft.dart';
import '../models/models.dart';

class DriverProvider extends ChangeNotifier {
  DriverProvider(this._profileRepo) : _profile = MockData.profile;

  final DriverProfileRepository _profileRepo;
  DriverProfile _profile;
  bool _loadingProfile = false;
  bool _savingProfileMedia = false;
  String? _profileError;

  DriverProfile get profile => _profile;
  DriverCar get car => _profile.car;
  bool get loadingProfile => _loadingProfile;
  bool get savingProfileMedia => _savingProfileMedia;
  String? get profileError => _profileError;

  Future<void> loadProfile() async {
    _loadingProfile = true;
    _profileError = null;
    notifyListeners();
    try {
      _profile = await _profileRepo.loadProfile();
      await _persistRegistrationStatus(_profile.registrationStatus);
    } catch (e) {
      _profileError = e.toString();
    } finally {
      _loadingProfile = false;
      notifyListeners();
    }
  }

  Future<void> loadFullProfile() async {
    _loadingProfile = true;
    _profileError = null;
    notifyListeners();
    try {
      _profile = await _profileRepo.loadFullProfile();
      await _persistRegistrationStatus(_profile.registrationStatus);
    } catch (error) {
      _profileError = apiErrorMessage(error);
    } finally {
      _loadingProfile = false;
      notifyListeners();
    }
  }

  Future<DriverProfile> submitRegistration(RegistrationDraft draft) async {
    final phone = normalizePhone(draft.phone);
    final payload = draft.toApiPayload(normalizedPhone: phone);
    _profile = await _profileRepo.saveProfilePayload(payload);
    await _persistRegistrationStatus(_profile.registrationStatus);
    notifyListeners();
    return _profile;
  }

  Future<void> refreshRegistrationStatus() async {
    await loadProfile();
  }

  static Future<void> _persistRegistrationStatus(String status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ApiConfig.registrationStatusKey, status);
  }

  Future<bool> uploadProfileMedia({
    required String field,
    required String base64,
  }) async {
    if (_savingProfileMedia || base64.trim().isEmpty) return false;
    _savingProfileMedia = true;
    _profileError = null;
    notifyListeners();
    try {
      _profile = await _profileRepo.saveProfilePayload({field: base64});
      if (field == 'avatarBase64') {
        _profile = _profile.copyWith(hasAvatar: true, avatarBase64: base64);
      }
      await _persistRegistrationStatus(_profile.registrationStatus);
      return true;
    } catch (error) {
      _profileError = apiErrorMessage(error);
      return false;
    } finally {
      _savingProfileMedia = false;
      notifyListeners();
    }
  }

  Future<bool> toggleTariffClass(String tariffClass) async {
    final current = List<String>.from(_profile.car.servedClasses);
    if (current.contains(tariffClass)) {
      if (current.length <= 1) return false;
      current.remove(tariffClass);
    } else {
      current.add(tariffClass);
    }
    current.sort(
      (a, b) =>
          TariffClasses.all.indexOf(a).compareTo(TariffClasses.all.indexOf(b)),
    );
    final previous = _profile;
    _profile = _profile.copyWith(
      car: _profile.car.copyWith(servedClasses: current),
    );
    notifyListeners();
    try {
      _profile = await _profileRepo.saveProfilePayload({
        'servedClasses': current,
      });
      notifyListeners();
      return true;
    } catch (error) {
      _profile = previous;
      _profileError = apiErrorMessage(error);
      notifyListeners();
      return false;
    }
  }
}

class OrdersProvider extends ChangeNotifier {
  OrdersProvider(this._ordersRepo, {SocketService? socket}) : _socket = socket {
    unawaited(_bootstrap());
    _bindSocket();
  }

  final OrdersRepository _ordersRepo;
  final SocketService? _socket;

  List<DriverOrder> _orders = [];
  DriverOrder? _activeOrder;
  DriverOrder? _lastCompleted;
  List<TripHistoryItem> _history = [];
  bool _alertNewOrder = false;
  bool _loading = false;
  String? _lastError;
  Timer? _alertTimer;
  final List<StreamSubscription<dynamic>> _subs = [];

  List<DriverOrder> get pendingOrders {
    final result = _orders
        .where((o) => o.status == TripOrderStatus.searching)
        .toList(growable: true);
    final position = AppServices.instance.locationTicker.latestPosition;
    if (position == null) return List.unmodifiable(result);
    result.sort((a, b) {
      final aDistance = a.pickupDistanceKm ?? _distanceToPickup(position, a);
      final bDistance = b.pickupDistanceKm ?? _distanceToPickup(position, b);
      return aDistance.compareTo(bDistance);
    });
    return List.unmodifiable(result);
  }

  double _distanceToPickup(Position position, DriverOrder order) {
    final point = order.fromPoint;
    if (point == null) return double.infinity;
    return Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          point.lat,
          point.lng,
        ) /
        1000;
  }

  /// Предзаказы: scheduledAt в будущем.
  List<DriverOrder> get preorders {
    final now = DateTime.now();
    return _orders
        .where(
          (o) =>
              o.scheduledAt != null &&
              o.scheduledAt!.isAfter(now) &&
              o.status != TripOrderStatus.canceled &&
              o.status != TripOrderStatus.skipped &&
              o.status != TripOrderStatus.completed,
        )
        .toList(growable: false);
  }

  List<DriverOrder> get immediatePending => pendingOrders
      .where(
        (o) => o.scheduledAt == null || !o.scheduledAt!.isAfter(DateTime.now()),
      )
      .toList(growable: false);

  DriverOrder? get incomingOrder =>
      immediatePending.isEmpty ? null : immediatePending.first;

  DriverOrder? get activeOrder => _activeOrder;
  DriverOrder? get lastCompleted => _lastCompleted;
  List<TripHistoryItem> get history => List.unmodifiable(_history);
  bool get alertNewOrder => _alertNewOrder;
  bool get hasActiveOrder => _activeOrder != null;
  bool get loading => _loading;
  String? get lastError => _lastError;

  void _bindSocket() {
    final socket = _socket;
    if (socket == null) return;

    _subs.add(socket.onOrderNew.listen((data) {
      final orderRaw = data['order'];
      if (orderRaw is! Map) return;
      final order =
          DriverOrder.fromServerJson(orderRaw.cast<String, dynamic>());
      if (_orders.any((o) => o.id == order.id) ||
          _activeOrder?.id == order.id) {
        return;
      }
      _orders = [order, ..._orders];
      _triggerAlert(order: order);
      notifyListeners();
    }));

    _subs.add(socket.onOrderTaken.listen((data) {
      final orderId = data['orderId']?.toString() ??
          (data['order'] is Map
              ? (data['order'] as Map)['id']?.toString()
              : null);
      if (orderId == null) return;
      _orders = _orders.where((o) => o.id != orderId).toList();
      if (_activeOrder?.id == orderId &&
          _activeOrder?.status == TripOrderStatus.searching) {
        _activeOrder = null;
      }
      notifyListeners();
    }));

    _subs.add(socket.onOrderCanceled.listen((data) {
      final orderId = data['orderId']?.toString() ??
          (data['order'] is Map
              ? (data['order'] as Map)['id']?.toString()
              : null);
      if (orderId == null) return;
      _orders = [
        for (final o in _orders)
          if (o.id == orderId)
            o.copyWith(status: TripOrderStatus.canceled)
          else
            o,
      ];
      if (_activeOrder?.id == orderId) {
        _activeOrder = null;
        _socket?.emitDriverStatus('online');
        unawaited(_syncTripLocation());
      }
      notifyListeners();
    }));
  }

  Future<void> _bootstrap() async {
    _loading = true;
    notifyListeners();
    try {
      _orders = await _ordersRepo.fetchPendingOffers();
      _activeOrder = await _ordersRepo.fetchActiveOrder();
      _history = await _ordersRepo.fetchHistory();
      await _syncTripLocation();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _syncTripLocation() async {
    if (ApiConfig.useMock) return;
    final ticker = AppServices.instance.locationTicker;
    if (_activeOrder != null) {
      _socket?.emitDriverStatus('busy');
      await ticker.startTripMode();
    } else {
      await ticker.stopTripMode();
    }
  }

  void _triggerAlert({DriverOrder? order}) {
    _alertNewOrder = true;
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
    Future<void>.delayed(const Duration(milliseconds: 120), () {
      if (_alertNewOrder) HapticFeedback.mediumImpact();
    });
    final target = order ?? incomingOrder;
    if (target != null) {
      unawaited(
        PushService.instance.notifyOrderNew(
          fromAddress: target.pickup,
          toAddress: target.dropoff,
          price: target.price,
          orderId: target.id,
        ),
      );
    }
    _alertTimer?.cancel();
    _alertTimer = Timer(const Duration(seconds: 3), () {
      _alertNewOrder = false;
      notifyListeners();
    });
  }

  void onWentOnline() {
    if (_activeOrder == null && pendingOrders.isNotEmpty) {
      _triggerAlert();
      notifyListeners();
    }
  }

  /// Adds a local, complete demo order from the profile screen. It stays
  /// local even when the app is connected to the real API, so it cannot
  /// create a real customer order while the driver tests the workflow.
  Future<void> startDemoOrder() async {
    if (_activeOrder != null ||
        _orders.any((o) => o.id == 'demo-driver-order')) {
      _lastError = 'Сначала завершите текущий заказ';
      notifyListeners();
      return;
    }
    final ticker = AppServices.instance.locationTicker;
    if (ticker.latestPosition == null) {
      final allowed = await DriverLocationTicker.ensureLocationPermission();
      if (allowed) await ticker.start(tripMode: false);
    }
    final position = ticker.latestPosition;
    if (position == null) {
      _lastError =
          'Р’РєР»СЋС‡РёС‚Рµ GPS, С‡С‚РѕР±С‹ Р·Р°РїСѓСЃС‚РёС‚СЊ РґРµРјРѕ-Р·Р°РєР°Р·';
      notifyListeners();
      return;
    }
    final demo = MockData.demoOrder().copyWith(
      fromPoint: LatLngPoint(
        lat: position.latitude,
        lng: position.longitude,
      ),
    );
    _orders = [demo, ..._orders];
    _lastError = null;
    _triggerAlert(order: demo);
    notifyListeners();
  }

  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  void clearLastCompleted() {
    _lastCompleted = null;
    notifyListeners();
  }

  Future<bool> acceptOrder(String id) async {
    if (_activeOrder != null) return false;
    _lastError = null;
    try {
      final accepted = id == 'demo-driver-order'
          ? _orders.firstWhere((o) => o.id == id).copyWith(
                status: TripOrderStatus.accepted,
              )
          : await _ordersRepo.accept(id);
      _activeOrder = accepted;
      _orders = [
        for (final o in _orders)
          if (o.id == id) accepted else o,
      ];
      _alertTimer?.cancel();
      _alertNewOrder = false;
      _socket?.emitDriverStatus('busy');
      await _syncTripLocation();
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = apiErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  /// Instantly switches the main screen to the trip state. Server acceptance
  /// and the first status transition continue in the background, so network
  /// latency cannot block the driver's primary action.
  Future<bool> acceptOrderFast(DriverOrder order) {
    if (_activeOrder != null) return Future.value(false);
    final connectivity = ConnectivityMonitor.instance;
    final ticker = AppServices.instance.locationTicker;
    if (connectivity.isOffline || !AppServices.instance.socket.isConnected) {
      _lastError = 'Нет соединения с сервером. Повторите после подключения';
      notifyListeners();
      return Future.value(false);
    }
    if (ticker.latestPosition == null || ticker.isStale || ticker.hasWeakGps) {
      _lastError = 'Дождитесь точного сигнала GPS перед принятием заказа';
      notifyListeners();
      return Future.value(false);
    }
    final previousOrders = List<DriverOrder>.from(_orders);
    final optimistic = order.copyWith(status: TripOrderStatus.enroute);
    _activeOrder = optimistic;
    _orders = [
      for (final item in _orders)
        if (item.id != order.id) item
    ];
    _alertTimer?.cancel();
    _alertNewOrder = false;
    _lastError = null;
    _socket?.emitDriverStatus('busy');
    unawaited(_syncTripLocation());
    notifyListeners();

    if (order.id != 'demo-driver-order') {
      unawaited(_confirmAcceptedOrder(order, previousOrders));
    }
    return Future.value(true);
  }

  Future<void> _confirmAcceptedOrder(
    DriverOrder order,
    List<DriverOrder> previousOrders,
  ) async {
    try {
      await _ordersRepo.accept(order.id);
      final updated = await _ordersRepo.advanceStatus(
        order.id,
        TripOrderStatus.enroute,
      );
      if (_activeOrder?.id != order.id) return;
      _activeOrder = updated;
      notifyListeners();
    } catch (e) {
      if (_activeOrder?.id != order.id) return;
      _activeOrder = null;
      _orders = previousOrders;
      _socket?.emitDriverStatus('online');
      await _syncTripLocation();
      _lastError = apiErrorMessage(e);
      notifyListeners();
    }
  }

  Future<bool> skipOrder(String id, {String? reason}) async {
    _lastError = null;
    try {
      if (id != 'demo-driver-order') {
        await _ordersRepo.skip(id, reason: reason);
      }
      _orders = [
        for (final o in _orders)
          if (o.id == id) o.copyWith(status: TripOrderStatus.skipped) else o,
      ];
      _alertTimer?.cancel();
      _alertNewOrder = false;
      if (pendingOrders.isNotEmpty) _triggerAlert();
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = apiErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelActiveOrder({String? reason}) async {
    final order = _activeOrder;
    if (order == null) return false;
    if (!TripStatusMachine.canTransition(
        order.status, TripOrderStatus.canceled)) {
      _lastError = 'Отмена недоступна на этом этапе';
      notifyListeners();
      return false;
    }
    _lastError = null;
    try {
      if (order.id != 'demo-driver-order') {
        await _ordersRepo.advanceStatus(order.id, TripOrderStatus.canceled);
      }
      _activeOrder = null;
      _socket?.emitDriverStatus('online');
      await _syncTripLocation();
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = apiErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> advanceActiveOrder() async {
    final order = _activeOrder;
    if (order == null) return false;
    final next = TripStatusMachine.nextDriverAction(order.status);
    if (next == null) return false;
    _lastError = null;
    try {
      final updated = order.id == 'demo-driver-order'
          ? order.copyWith(status: next)
          : await _ordersRepo.advanceStatus(order.id, next);
      if (next == TripOrderStatus.completed) {
        _lastCompleted = updated;
        _activeOrder = null;
        _socket?.emitDriverStatus('online');
        if (order.id != 'demo-driver-order') {
          _history = await _ordersRepo.fetchHistory();
        } else {
          _history = [
            TripHistoryItem(
              id: 'demo-history-${DateTime.now().millisecondsSinceEpoch}',
              completedAt: DateTime.now(),
              pickup: order.pickup,
              dropoff: order.dropoff,
              earningsRub: (order.priceFinal ?? order.price).round(),
              clientRating: 0.0,
              clientName: order.passengerName,
              tariff: order.tariff,
              serviceType: order.serviceType,
            ),
            ..._history,
          ];
        }
      } else {
        _activeOrder = TripStatusMachine.isActive(next) ? updated : null;
      }
      await _syncTripLocation();
      if (_activeOrder == null &&
          next != TripOrderStatus.completed &&
          pendingOrders.isNotEmpty) {
        _triggerAlert();
      }
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = apiErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _alertTimer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    super.dispose();
  }
}

class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._settingsRepo) {
    _pushTokenSubscription = PushService.instance.onTokenRefresh.listen(
      (token) {
        if (_initialized && _settings.notificationsEnabled) {
          unawaited(_syncPushToken(token));
        }
      },
    );
    _socketConnectedSubscription =
        AppServices.instance.socket.onConnected.listen((_) {
      if (!_initialized || !_settings.isOnline || ApiConfig.useMock) return;
      final ticker = AppServices.instance.locationTicker;
      AppServices.instance.socket
          .emitDriverStatus(ticker.isTripMode ? 'busy' : 'online');
      if (ticker.isRunning) {
        ticker.onSocketReconnected();
      } else {
        unawaited(ticker.start());
      }
    });
  }

  final SettingsRepository _settingsRepo;
  DriverSettings _settings = const DriverSettings();
  bool _initialized = false;
  StreamSubscription<String>? _pushTokenSubscription;
  StreamSubscription<void>? _socketConnectedSubscription;
  Timer? _gpsWatchdog;
  bool _forcingOffline = false;

  DriverSettings get settings => _settings;
  bool get isOnline => _settings.isOnline;
  bool get isLoggedIn => _settings.isLoggedIn;
  bool get initialized => _initialized;
  String? get onlineError => _onlineError;

  String? _onlineError;

  ThemeMode get themeMode =>
      _settings.themeMode == 'light' ? ThemeMode.light : ThemeMode.dark;

  bool get isLightTheme => themeMode == ThemeMode.light;

  Future<void> load() async {
    _settings = await _settingsRepo.load();
    _initialized = true;
    if (_settings.isOnline) {
      _settings = _settings.copyWith(isOnline: false);
      await _settingsRepo.syncOnlineStatus(false);
      await _settingsRepo.save(_settings);
    }
    if (_settings.notificationsEnabled) {
      final token = await PushService.instance.getTokenForApi();
      if (token != null) unawaited(_syncPushToken(token));
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (themeMode == mode) return;
    _settings = _settings.copyWith(
      themeMode: mode == ThemeMode.light ? 'light' : 'dark',
    );
    notifyListeners();
    // Do not hold the repaint behind storage I/O. The selected mode is kept
    // in memory immediately and persisted before this future completes.
    await _settingsRepo.save(_settings);
  }

  Future<void> setLightTheme(bool value) =>
      setThemeMode(value ? ThemeMode.light : ThemeMode.dark);

  Future<void> setNotifications(bool value) async {
    if (value && !await PushService.instance.requestPermission()) return;
    _settings = _settings.copyWith(notificationsEnabled: value);
    await _settingsRepo.save(_settings);
    notifyListeners();
    try {
      final token = value ? await PushService.instance.getTokenForApi() : '';
      if (value && (token == null || token.isEmpty)) return;
      await DriverProfileService(AppServices.instance.client).savePushToken(
        token: token ?? '',
        platform: PushService.instance.platformLabel,
      );
    } catch (error) {
      debugPrint('Driver push token sync failed: $error');
    }
  }

  Future<void> _syncPushToken(String token) async {
    if (token.trim().isEmpty) return;
    try {
      await DriverProfileService(AppServices.instance.client).savePushToken(
        token: token,
        platform: PushService.instance.platformLabel,
      );
    } catch (error) {
      debugPrint('Driver push token refresh sync failed: $error');
    }
  }

  Future<void> setNavApp(NavApp app) async {
    _settings = _settings.copyWith(navApp: app);
    await _settingsRepo.save(_settings);
    notifyListeners();
  }

  Future<bool> setOnline(bool value) async {
    final ticker = AppServices.instance.locationTicker;
    if (value) {
      final connectivity = ConnectivityMonitor.instance;
      await connectivity.start();
      if (connectivity.isOffline) {
        _onlineError = 'Нет соединения с сервером';
        notifyListeners();
        return false;
      }
      final ok = await DriverLocationTicker.ensureLocationPermission();
      if (!ok) {
        _onlineError =
            'Включите геолокацию и разрешите доступ, чтобы выйти на линию';
        notifyListeners();
        return false;
      }
      await ticker.start();
      if (ticker.latestPosition == null ||
          ticker.isStale ||
          ticker.hasWeakGps) {
        _onlineError =
            'Не удалось получить точную GPS-позицию. Перейдите на открытое место и повторите';
        ticker.stop();
        notifyListeners();
        return false;
      }
    }

    final previous = _settings;
    _onlineError = null;
    _settings = _settings.copyWith(isOnline: value);
    notifyListeners();
    try {
      if (!value) {
        // Сначала прекращаем GPS, чтобы запоздалый пакет не вернул водителя
        // в online после ручного выключения.
        ticker.stop();
      }
      await _settingsRepo.syncOnlineStatus(value);
      await _settingsRepo.save(_settings);
      if (value) {
        _startGpsWatchdog();
      } else {
        _gpsWatchdog?.cancel();
        _gpsWatchdog = null;
      }
      return true;
    } catch (error) {
      _settings = previous;
      _onlineError = 'Не удалось изменить статус. Проверьте интернет';
      ticker.stop();
      debugPrint('setOnline failed: $error');
      notifyListeners();
      return false;
    }
  }

  void _startGpsWatchdog() {
    _gpsWatchdog?.cancel();
    _gpsWatchdog = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!_settings.isOnline || _forcingOffline) return;
      final ticker = AppServices.instance.locationTicker;
      if (ticker.latestPosition == null ||
          ticker.isStale ||
          ticker.hasWeakGps) {
        unawaited(_forceOfflineForGps());
      }
    });
  }

  Future<void> _forceOfflineForGps() async {
    if (_forcingOffline || !_settings.isOnline) return;
    _forcingOffline = true;
    try {
      _gpsWatchdog?.cancel();
      _gpsWatchdog = null;
      AppServices.instance.locationTicker.stop();
      AppServices.instance.socket.emitDriverStatus('offline');
      _settings = _settings.copyWith(isOnline: false);
      try {
        await _settingsRepo.syncOnlineStatus(false);
        await _settingsRepo.save(_settings);
      } catch (error) {
        debugPrint('force offline GPS sync failed: $error');
      }
      _onlineError =
          'Вы переведены не на линию: GPS-позиция устарела или стала неточной';
      notifyListeners();
    } finally {
      _forcingOffline = false;
    }
  }

  Future<void> setServerUrl(String url) async {
    _settings = _settings.copyWith(serverUrl: url.trim());
    await _settingsRepo.save(_settings);
    notifyListeners();
  }

  Future<void> setUseMockApi(bool value) async {
    _settings = _settings.copyWith(useMockApi: value);
    await _settingsRepo.save(_settings);
    notifyListeners();
  }

  Future<void> logout() async {
    _gpsWatchdog?.cancel();
    _gpsWatchdog = null;
    AppServices.instance.locationTicker.stop();
    _settings = _settings.copyWith(isLoggedIn: false, isOnline: false);
    await _settingsRepo.syncOnlineStatus(false);
    await _settingsRepo.save(_settings);
    notifyListeners();
  }

  void markLoggedIn() {
    _settings = _settings.copyWith(isLoggedIn: true);
    notifyListeners();
  }

  @override
  void dispose() {
    _gpsWatchdog?.cancel();
    _pushTokenSubscription?.cancel();
    _socketConnectedSubscription?.cancel();
    super.dispose();
  }
}
