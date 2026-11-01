import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

enum AppConnectivityState { online, offline, restoring, serverUnavailable }

/// Глобальный статус сети (offline / online). Soft-fail: при ошибках плагина считаем online.
class ConnectivityMonitor extends ChangeNotifier {
  ConnectivityMonitor._();

  static final ConnectivityMonitor instance = ConnectivityMonitor._();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _sub;
  Timer? _restoreTimer;
  bool _online = true;
  bool _started = false;
  AppConnectivityState _state = AppConnectivityState.online;

  bool get isOnline => _online;
  bool get isOffline => !_online;
  AppConnectivityState get state => _state;

  void reportServerUnavailable() {
    if (_state == AppConnectivityState.offline ||
        _state == AppConnectivityState.restoring) {
      return;
    }
    _online = true;
    if (_state != AppConnectivityState.serverUnavailable) {
      _state = AppConnectivityState.serverUnavailable;
      notifyListeners();
    }
  }

  void reportServerAvailable() {
    if (_state != AppConnectivityState.serverUnavailable) return;
    _online = true;
    _state = AppConnectivityState.online;
    notifyListeners();
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      final initial = await _connectivity.checkConnectivity();
      _apply(initial);
    } catch (_) {
      _online = true;
    }
    try {
      _sub = _connectivity.onConnectivityChanged.listen(
        _apply,
        onError: (_) {
          // Soft-fail: не роняем приложение при ошибках стрима.
        },
      );
    } catch (_) {
      _online = true;
    }
  }

  void _apply(List<ConnectivityResult> results) {
    final next = results.any((r) => r != ConnectivityResult.none);
    if (!next) {
      _restoreTimer?.cancel();
      _online = false;
      if (_state != AppConnectivityState.offline) {
        _state = AppConnectivityState.offline;
        notifyListeners();
      }
      return;
    }

    if (_state == AppConnectivityState.offline) {
      _online = false;
      _state = AppConnectivityState.restoring;
      notifyListeners();
      _restoreTimer?.cancel();
      _restoreTimer = Timer(const Duration(milliseconds: 1400), () {
        _online = true;
        _state = AppConnectivityState.online;
        notifyListeners();
      });
      return;
    }

    _online = true;
    if (_state != AppConnectivityState.online) {
      _state = AppConnectivityState.online;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _restoreTimer?.cancel();
    _sub?.cancel();
    _sub = null;
    _started = false;
    super.dispose();
  }
}
