import '../api_client.dart';

class OrderChatMessage {
  const OrderChatMessage({
    required this.id,
    required this.orderId,
    required this.senderRole,
    required this.senderId,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String orderId;
  final String senderRole;
  final String senderId;
  final String text;
  final String createdAt;

  bool get isDriver => senderRole == 'driver';

  factory OrderChatMessage.fromJson(Map<String, dynamic> json) {
    return OrderChatMessage(
      id: json['id']?.toString() ?? '',
      orderId: json['orderId']?.toString() ?? '',
      senderRole: json['senderRole']?.toString() ??
          json['role']?.toString() ??
          '',
      senderId: json['senderId']?.toString() ?? '',
      text: json['text']?.toString() ?? json['body']?.toString() ?? '',
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

class OrderChatService {
  OrderChatService(this._client);

  final ApiClient _client;

  Future<List<OrderChatMessage>> listMessages(
    String orderId, {
    int limit = 50,
  }) async {
    final res = await _client.getJson(
      '/orders/$orderId/chat',
      query: {'limit': '$limit'},
    );
    final raw = res['messages'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => OrderChatMessage.fromJson(Map<String, dynamic>.from(m)))
        .where((m) => m.id.isNotEmpty)
        .toList(growable: false);
  }

  Future<OrderChatMessage> sendMessage({
    required String orderId,
    required String text,
  }) async {
    final res = await _client.postJson(
      '/orders/$orderId/chat',
      body: {'text': text},
    );
    final raw = res['message'];
    if (raw is! Map) {
      throw StateError('Chat message payload missing');
    }
    return OrderChatMessage.fromJson(Map<String, dynamic>.from(raw));
  }
}
