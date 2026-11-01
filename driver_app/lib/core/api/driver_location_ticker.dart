import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'socket_service.dart';

/// Энергоэффективная отправка координат водителя.
///
/// В обычном online-режиме координаты уходят по факту заметного перемещения и
/// heartbeat раз в 70 секунд (Redis TTL на сервере — 120 секунд). Во время
/// заказа точность и частота повышаются. Это исключает старую двойную отправку
/// одновременно из GPS stream и таймера каждые 8 секунд.
class DriverLocationTicker extends ChangeNotifier {
  DriverLocationTicker(this._socket);

  final SocketService _socket;
  Timer? _heartbeatTimer;
  StreamSubscription<Position>? _positionSub;

  bool _tripMode = false;
  bool _running = false;
  Position? _latestPosition;
  DateTime? _lastFixAt;
  DateTime? _lastSentAt;
  double? _lastSentLat;
  double? _lastSentLng;

  bool get isTripMode => _tripMode;
  bool get isRunning => _running;
  Position? get latestPosition => _latestPosition;
  DateTime? get lastFixAt => _lastFixAt;

  double? get accuracyMeters {
    final acc = _latestPosition?.accuracy;
    if (acc == null || acc <= 0) return null;
    return acc;
  }

  bool get hasWeakGps {
    final position = _latestPosition;
    if (position == null) return false;
    if (position.accuracy <= 0) return false;
    return position.accuracy > (_tripMode ? 65 : 140);
  }

  bool get isStale {
    if (!_running) return false;
    final at = _lastFixAt;
    if (at == null) return true;
    final maxAge =
        _tripMode ? const Duration(seconds: 45) : const Duration(seconds: 90);
    return DateTime.now().difference(at) > maxAge;
  }

  Duration get _heartbeatInterval =>
      _tripMode ? const Duration(seconds: 25) : const Duration(seconds: 70);
  Duration get _minimumSendInterval =>
      _tripMode ? const Duration(seconds: 4) : const Duration(seconds: 15);
  double get _minimumMovementMeters => _tripMode ? 8 : 35;
  int get _distanceFilterMeters => _tripMode ? 8 : 35;

  void _notifyGpsState() {
    if (hasListeners) notifyListeners();
  }

  void _applyPosition(Position position) {
    _latestPosition = position;
    _lastFixAt = DateTime.now();
    _notifyGpsState();
  }

  /// Разрешение foreground-геолокации обязательно для выхода на линию.
  static Future<bool> ensureLocationPermission(
      {bool background = false}) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return false;
    }

    var status = await Permission.locationWhenInUse.status;
    if (!status.isGranted && !status.isLimited) {
      status = await Permission.locationWhenInUse.request();
    }
    if (!status.isGranted && !status.isLimited) return false;

    if (background) {
      var always = await Permission.locationAlways.status;
      if (!always.isGranted && !always.isLimited) {
        always = await Permission.locationAlways.request();
      }
      // Foreground GPS still remains useful if Always was denied. The caller
      // can continue, while the UI/system explains the background limitation.
    }
    return true;
  }

  Future<void> start({bool tripMode = false}) async {
    if (_running && _tripMode == tripMode) return;
    _tripMode = tripMode;
    await _restart();
  }

  Future<void> startTripMode() => start(tripMode: true);

  Future<void> stopTripMode() async {
    if (!_tripMode) return;
    _tripMode = false;
    await _restart();
  }

  Future<void> _restart() async {
    _heartbeatTimer?.cancel();
    await _positionSub?.cancel();
    _positionSub = null;
    _running = false;
    // Preserve the last valid fix while switching between normal and trip
    // tracking. This keeps the map and proximity checks responsive.
    _notifyGpsState();

    final permitted = await ensureLocationPermission(background: true);
    if (!permitted) {
      debugPrint('driver GPS: permission or location service unavailable');
      return;
    }

    _running = true;
    _notifyGpsState();
    await _bootstrapGps();
    _heartbeatTimer = Timer.periodic(
      _heartbeatInterval,
      (_) => _emitIfNeeded(forceHeartbeat: true),
    );
  }

  Future<void> _bootstrapGps() async {
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && _isUsable(lastKnown)) {
        _applyPosition(lastKnown);
        _emitIfNeeded(forceHeartbeat: true);
      }

      final current = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: _tripMode
              ? LocationAccuracy.bestForNavigation
              : LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 12),
        ),
      );
      if (_isUsable(current)) {
        _applyPosition(current);
        // Last known position may have just been sent. Let distance/time
        // filtering suppress the duplicate bootstrap packet.
        _emitIfNeeded(forceHeartbeat: _lastSentAt == null);
      }

      _positionSub = Geolocator.getPositionStream(
        locationSettings: _platformLocationSettings(),
      ).listen(
        (position) {
          if (!_isUsable(position)) return;
          _applyPosition(position);
          _emitIfNeeded();
        },
        onError: (Object error) {
          debugPrint('driver GPS stream error: $error');
        },
      );
    } catch (error) {
      debugPrint('driver GPS bootstrap failed: $error');
    }
  }

  LocationSettings _platformLocationSettings() {
    final accuracy = _tripMode
        ? LocationAccuracy.bestForNavigation
        : LocationAccuracy.medium;

    if (!kIsWeb && Platform.isAndroid) {
      return AndroidSettings(
        accuracy: accuracy,
        distanceFilter: _distanceFilterMeters,
        intervalDuration: _tripMode
            ? const Duration(seconds: 4)
            : const Duration(seconds: 20),
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: 'КОРОЛИ ДОРОГ — вы на линии',
          notificationText: _tripMode
              ? 'Передаём геопозицию клиенту во время заказа'
              : 'Ищем подходящие заказы рядом с вами',
          notificationChannelName: 'Работа на линии',
          enableWakeLock: _tripMode,
          setOngoing: true,
        ),
      );
    }

    if (!kIsWeb && Platform.isIOS) {
      return AppleSettings(
        accuracy: accuracy,
        distanceFilter: _distanceFilterMeters,
        activityType: ActivityType.automotiveNavigation,
        pauseLocationUpdatesAutomatically: !_tripMode,
        showBackgroundLocationIndicator: _tripMode,
        allowBackgroundLocationUpdates: true,
      );
    }

    return LocationSettings(
      accuracy: accuracy,
      distanceFilter: _distanceFilterMeters,
    );
  }

  void _emitIfNeeded({bool forceHeartbeat = false}) {
    final position = _latestPosition;
    if (!_running || position == null || !_socket.isConnected) return;

    final now = DateTime.now();
    final lastAt = _lastSentAt;
    final elapsed = lastAt == null ? null : now.difference(lastAt);
    final moved = _distanceFromLastSent(position);
    final firstPoint = _lastSentLat == null || _lastSentLng == null;
    final intervalElapsed = elapsed == null || elapsed >= _minimumSendInterval;
    final movementElapsed = moved >= _minimumMovementMeters && intervalElapsed;

    if (!firstPoint && !forceHeartbeat && !movementElapsed) return;
    try {
      _socket.emitDriverLocation(
        lat: position.latitude,
        lng: position.longitude,
        accuracyMeters: accuracyMeters,
        recordedAt: _lastFixAt,
      );
      _lastSentAt = now;
      _lastSentLat = position.latitude;
      _lastSentLng = position.longitude;
    } catch (error) {
      debugPrint('driver:location emit failed: $error');
    }
  }

  double _distanceFromLastSent(Position position) {
    final lat = _lastSentLat;
    final lng = _lastSentLng;
    if (lat == null || lng == null) return double.infinity;
    return Geolocator.distanceBetween(
      lat,
      lng,
      position.latitude,
      position.longitude,
    );
  }

  bool _isValid(double lat, double lng) =>
      lat.isFinite &&
      lng.isFinite &&
      lat >= -90 &&
      lat <= 90 &&
      lng >= -180 &&
      lng <= 180 &&
      !(lat == 0 && lng == 0);

  bool _isUsable(Position position) {
    if (!_isValid(position.latitude, position.longitude)) return false;
    // 0 is reported by some providers when accuracy is unknown.
    if (position.accuracy <= 0) return true;
    return position.accuracy <= (_tripMode ? 65 : 140);
  }

  /// Immediately restores the last known coordinate after Socket.IO reconnect
  /// without restarting the GPS stream or losing trip mode.
  void onSocketReconnected() {
    if (!_running) return;
    _emitIfNeeded(forceHeartbeat: true);
  }

  void stop() {
    _tripMode = false;
    _running = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    unawaited(_positionSub?.cancel());
    _positionSub = null;
    _latestPosition = null;
    _lastFixAt = null;
    _lastSentAt = null;
    _lastSentLat = null;
    _lastSentLng = null;
    _notifyGpsState();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
