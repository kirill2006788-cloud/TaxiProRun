import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import 'api_config.dart';

/// Socket.IO клиент водителя: JWT auth + emit/listen по контракту backend_vps.
class SocketService extends ChangeNotifier {
  SocketService();

  io.Socket? _socket;
  String? _token;
  bool _connected = false;
  String? _lastError;

  final _orderNewController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _orderTakenController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _orderCanceledController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _broadcastController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _orderNearbyController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _orderChatController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _connectedController = StreamController<void>.broadcast();

  bool get isConnected => _connected;
  String? get lastError => _lastError;

  Stream<void> get onConnected => _connectedController.stream;

  Stream<Map<String, dynamic>> get onOrderNew => _orderNewController.stream;
  Stream<Map<String, dynamic>> get onOrderNearby =>
      _orderNearbyController.stream;
  Stream<Map<String, dynamic>> get onOrderTaken => _orderTakenController.stream;
  Stream<Map<String, dynamic>> get onOrderCanceled =>
      _orderCanceledController.stream;
  Stream<Map<String, dynamic>> get onBroadcast => _broadcastController.stream;
  Stream<Map<String, dynamic>> get onOrderChat => _orderChatController.stream;

  void connect({required String token}) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return;
    if (_socket != null && _token == trimmed && _connected) return;

    _token = trimmed;
    disconnect(notify: false);

    final url = ApiConfig.baseUrl;

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
        if (!_connectedController.isClosed) {
          _connectedController.add(null);
        }
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
        if (!_connectedController.isClosed) {
          _connectedController.add(null);
        }
      });

      socket.on('order:new', (data) {
        _safeAdd(_orderNewController, data);
      });

      socket.on('order:nearby', (data) {
        try {
          final map = _asMap(data);
          if (map != null) {
            _safeAddMap(_orderNearbyController, map);
            _safeAddMap(_orderNewController, map);
          }
        } catch (_) {}
      });

      socket.on('order:taken', (data) {
        _safeAdd(_orderTakenController, data);
      });

      socket.on('order:canceled', (data) {
        _safeAdd(_orderCanceledController, data);
      });

      socket.on('broadcast:new', (data) {
        _safeAdd(_broadcastController, data);
      });

      socket.on('order:chat', (data) {
        _safeAdd(_orderChatController, data);
      });

      _socket = socket;
      socket.connect();
    } catch (_) {
      _lastError = 'Не удалось подключиться к серверу';
      notifyListeners();
    }
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

  void emitDriverStatus(String status) {
    _socket?.emit('driver:status', {'status': status});
  }

  void emitDriverLocation({
    required double lat,
    required double lng,
    double? accuracyMeters,
    DateTime? recordedAt,
  }) {
    _socket?.emit('driver:location', {
      'lat': lat,
      'lng': lng,
      if (accuracyMeters != null && accuracyMeters.isFinite)
        'accuracyMeters': accuracyMeters,
      if (recordedAt != null)
        'recordedAt': recordedAt.toUtc().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>> emitOrderAccept(String orderId) {
    return _emitWithAck('order:accept', {'orderId': orderId});
  }

  Future<Map<String, dynamic>> emitOrderDecline(
    String orderId, {
    String? reason,
  }) {
    return _emitWithAck('order:decline', {
      'orderId': orderId,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
    });
  }

  Future<Map<String, dynamic>> emitOrderUpdate({
    required String orderId,
    required String status,
  }) {
    return _emitWithAck('order:update', {
      'orderId': orderId,
      'status': status,
    });
  }

  Future<Map<String, dynamic>> emitOrderChat({
    required String orderId,
    required String text,
  }) {
    return _emitWithAck('order:chat', {
      'orderId': orderId,
      'text': text,
      'role': 'driver',
    });
  }

  Future<Map<String, dynamic>> _emitWithAck(
    String event,
    Map<String, dynamic> payload,
  ) {
    final socket = _socket;
    if (socket == null || !_connected) {
      return Future.error(
        StateError('Нет связи с сервером. Попробуйте ещё раз'),
      );
    }

    final completer = Completer<Map<String, dynamic>>();
    try {
      socket.emitWithAck(event, payload, ack: (dynamic data) {
        final map = _asMap(data) ?? <String, dynamic>{};
        if (!completer.isCompleted) completer.complete(map);
      });
    } catch (e) {
      if (!completer.isCompleted) completer.completeError(e);
    }

    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw TimeoutException(
        'Сервер не ответил. Попробуйте ещё раз',
      ),
    );
  }

  Map<String, dynamic>? _asMap(dynamic data) {
    try {
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
    } catch (_) {}
    return null;
  }

  void _safeAdd(
      StreamController<Map<String, dynamic>> controller, dynamic data) {
    try {
      if (controller.isClosed) return;
      final map = _asMap(data);
      if (map != null) controller.add(map);
    } catch (_) {}
  }

  void _safeAddMap(
    StreamController<Map<String, dynamic>> controller,
    Map<String, dynamic> map,
  ) {
    try {
      if (!controller.isClosed) controller.add(map);
    } catch (_) {}
  }

  @override
  void dispose() {
    disconnect(notify: false);
    _orderNewController.close();
    _orderTakenController.close();
    _orderCanceledController.close();
    _broadcastController.close();
    _orderNearbyController.close();
    _orderChatController.close();
    _connectedController.close();
    super.dispose();
  }
}
