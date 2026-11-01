import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/api/socket_service.dart';

class TripChatMessage {
  const TripChatMessage({
    required this.id,
    required this.from,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String from;
  final String body;
  final DateTime createdAt;

  bool get isMine => from == 'client' || from == 'passenger' || from == 'user';
  bool get isDriver => from == 'driver';

  factory TripChatMessage.fromSocket(Map<String, dynamic> data) {
    final nested = data['message'];
    final Map<String, dynamic> src;
    if (nested is Map) {
      src = {
        ...data,
        ...Map<String, dynamic>.from(nested),
      };
    } else {
      src = data;
    }

    final createdRaw = src['createdAt']?.toString() ??
        src['timestamp']?.toString() ??
        src['sentAt']?.toString();
    return TripChatMessage(
      id: src['id']?.toString() ??
          '${src['from'] ?? src['role']}_${createdRaw ?? DateTime.now().millisecondsSinceEpoch}',
      from: src['senderRole']?.toString() ??
          src['from']?.toString() ??
          src['sender']?.toString() ??
          src['role']?.toString() ??
          'unknown',
      body: src['text']?.toString() ?? src['body']?.toString() ?? '',
      createdAt: DateTime.tryParse(createdRaw ?? '') ?? DateTime.now(),
    );
  }
}

/// In-trip chat: Socket.IO `order:chat` + REST history fallback + local mock.
class TripChatProvider extends ChangeNotifier {
  TripChatProvider({
    required String orderId,
    required SocketService socket,
    required Future<List<TripChatMessage>> Function() loadHistory,
    required Future<void> Function(String text) sendRest,
    required bool useMockApi,
  })  : _orderId = orderId,
        _socket = socket,
        _loadHistory = loadHistory,
        _sendRest = sendRest,
        _useMockApi = useMockApi;

  final String _orderId;
  final SocketService _socket;
  final Future<List<TripChatMessage>> Function() _loadHistory;
  final Future<void> Function(String text) _sendRest;
  final bool _useMockApi;

  final List<TripChatMessage> _messages = [];
  StreamSubscription<Map<String, dynamic>>? _sub;
  bool _loading = true;
  bool _sending = false;
  String? _error;
  bool _offlineHint = false;

  List<TripChatMessage> get messages => List.unmodifiable(_messages);
  bool get loading => _loading;
  bool get sending => _sending;
  String? get error => _error;
  bool get offlineHint => _offlineHint || _useMockApi;
  bool get canSend => true;

  Future<void> start() async {
    _loading = true;
    _error = null;
    notifyListeners();

    await _sub?.cancel();
    _sub = _socket.onOrderChat.listen(_onIncoming);

    try {
      final history = await _loadHistory();
      _messages
        ..clear()
        ..addAll(history);
    } catch (_) {
      // Soft-fail: history optional — live socket / local still works.
      _offlineHint = true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void _onIncoming(Map<String, dynamic> data) {
    final msgOrderId = data['orderId']?.toString();
    if (msgOrderId != null && msgOrderId.isNotEmpty && msgOrderId != _orderId) {
      return;
    }
    final msg = TripChatMessage.fromSocket(data);
    if (msg.body.trim().isEmpty) return;
    if (_messages.any((m) => m.id == msg.id)) return;
    // Drop optimistic local twin with same body/from within a few seconds.
    _messages.removeWhere(
      (m) =>
          m.id.startsWith('local_') && m.from == msg.from && m.body == msg.body,
    );
    _messages.add(msg);
    notifyListeners();
  }

  Future<bool> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _sending) return false;

    _sending = true;
    _error = null;
    notifyListeners();

    final optimistic = TripChatMessage(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      from: 'client',
      body: trimmed,
      createdAt: DateTime.now(),
    );
    _messages.add(optimistic);
    notifyListeners();

    if (_useMockApi) {
      _offlineHint = true;
      _sending = false;
      notifyListeners();
      Timer(const Duration(milliseconds: 900), () {
        if (!hasListeners) return;
        _messages.add(
          TripChatMessage(
            id: 'demo_driver_${DateTime.now().millisecondsSinceEpoch}',
            from: 'driver',
            body: _mockDriverReply(trimmed),
            createdAt: DateTime.now(),
          ),
        );
        notifyListeners();
      });
      return true;
    }

    try {
      if (_socket.isConnected) {
        _socket.sendOrderChat(orderId: _orderId, text: trimmed);
        return true;
      }
      await _sendRest(trimmed);
      return true;
    } catch (e) {
      // Soft-fail: keep local bubble so UI stays usable without API/socket.
      _offlineHint = true;
      _error = 'Нет связи — сообщение только на этом устройстве';
      debugPrint('Trip chat send failed: $e');
      return true;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  String _mockDriverReply(String message) {
    final lower = message.toLowerCase();
    if (lower.contains('выхожу') || message.contains('👋')) {
      return 'Хорошо, жду у точки подачи';
    }
    if (lower.contains('где') || lower.contains('подъезд')) {
      return 'Я у указанного подъезда, белый Solaris';
    }
    if (message.contains('❤️') || message.contains('👍')) {
      return 'Спасибо!';
    }
    return 'Принял, буду через пару минут';
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    _sub = null;
    super.dispose();
  }
}
