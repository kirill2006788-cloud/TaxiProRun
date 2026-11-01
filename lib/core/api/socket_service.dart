import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'api_client.dart';
import 'api_config.dart';

/// Socket.IO клиент пассажира: JWT auth + realtime события заказа.
class SocketService extends ChangeNotifier {
  SocketService({ApiConfigStore? configStore})
      : _config = configStore ?? ApiConfigStore.instance;

  final ApiConfigStore _config;

  io.Socket? _socket;
  String? _token;
  bool _connected = false;
  String? _lastError;

  final _orderStatusController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _driverLocationController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _orderDelayController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _orderChatController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _broadcastController =
      StreamController<Map<String, dynamic>>.broadcast();

  bool get isConnected => _connected;
  String? get lastError => _lastError;

  Stream<Map<String, dynamic>> get onOrderStatus =>
      _orderStatusController.stream;
  Stream<Map<String, dynamic>> get onDriverLocation =>
      _driverLocationController.stream;
  Stream<Map<String, dynamic>> get onOrderDelay => _orderDelayController.stream;
  Stream<Map<String, dynamic>> get onOrderChat => _orderChatController.stream;
  Stream<Map<String, dynamic>> get onBroadcast => _broadcastController.stream;

  void connect({required String token}) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return;
    if (_socket != null && _token == trimmed && _connected) return;

    _token = trimmed;
    disconnect(notify: false);

    final url = _config.baseUrl.isEmpty
        ? ApiConfig.envBaseUrl
        : _config.baseUrl;

    try {
      final socket = io.io(
        url,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .enableReconnection()
            .setReconnectionAttempts(50)
            .setReconnectionDelay(1500)
            .setAuth({'token': trimmed})
            .setExtraHeaders({'Authorization': 'Bearer $trimmed'})
            .build(),
      );

      socket.onConnect((_) {
        _connected = true;
        _lastError = null;
        notifyListeners();
      });

      socket.onDisconnect((_) {
        _connected = false;
        notifyListeners();
      });

      socket.onConnectError((err) {
        _connected = false;
        _lastError = 'Нет связи с сервером. Проверьте интернет';
        notifyListeners();
      });

      socket.onReconnect((_) {
        _connected = true;
        _lastError = null;
        notifyListeners();
      });

      socket.on('order:status', (data) {
        _safeAdd(_orderStatusController, data);
      });

      socket.on('driver:location', (data) {
        _safeAdd(_driverLocationController, data);
      });

      socket.on('order:delay', (data) {
        _safeAdd(_orderDelayController, data);
      });

      socket.on('order:chat', (data) {
        _safeAdd(_orderChatController, data);
      });

      socket.on('broadcast:new', (data) {
        _safeAdd(_broadcastController, data);
      });

      _socket = socket;
      socket.connect();
    } catch (_) {
      _lastError = 'Не удалось подключиться к серверу';
      notifyListeners();
    }
  }

  void sendOrderChat({required String orderId, required String text}) {
    final socket = _socket;
    if (socket == null || !_connected) return;
    socket.emit('order:chat', {
      'orderId': orderId,
      'text': text.trim(),
      'role': 'client',
    });
  }

  void reconnect() {
    final token = _token;
    if (token == null || token.isEmpty) return;
    connect(token: token);
  }

  void disconnect({bool notify = true}) {
    final socket = _socket;
    _socket = null;
    _connected = false;
    if (socket != null) {
      try {
        socket.clearListeners();
        socket.disconnect();
        socket.dispose();
      } catch (_) {}
    }
    if (notify) notifyListeners();
  }

  Map<String, dynamic>? _asMap(dynamic data) {
    try {
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
    } catch (_) {}
    return null;
  }

  void _safeAdd(StreamController<Map<String, dynamic>> controller, dynamic data) {
    try {
      if (controller.isClosed) return;
      final map = _asMap(data);
      if (map != null) controller.add(map);
    } catch (_) {
      // Soft-fail: не роняем приложение на битых socket payload.
    }
  }

  @override
  void dispose() {
    disconnect(notify: false);
    _orderStatusController.close();
    _driverLocationController.close();
    _orderDelayController.close();
    _orderChatController.close();
    _broadcastController.close();
    super.dispose();
  }
}
