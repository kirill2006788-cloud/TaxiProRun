/// Обращение в поддержку (водитель).
class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.subject,
    required this.body,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.messages = const [],
  });

  final String id;
  final String subject;
  final String body;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<SupportMessage> messages;

  bool get isClosed => status == 'closed';
  bool get isReplied => status == 'replied';

  String get statusLabelRu => switch (status) {
        'replied' => 'Есть ответ',
        'closed' => 'Закрыто',
        _ => 'Открыто',
      };

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    final raw = json['messages'];
    final messages = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => SupportMessage.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <SupportMessage>[];
    return SupportTicket(
      id: '${json['id'] ?? ''}',
      subject: '${json['subject'] ?? ''}',
      body: '${json['body'] ?? ''}',
      status: '${json['status'] ?? 'open'}',
      createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}') ?? DateTime.now(),
      updatedAt: DateTime.tryParse('${json['updatedAt'] ?? ''}') ?? DateTime.now(),
      messages: messages,
    );
  }
}

class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.from,
    required this.body,
    required this.createdAt,
    this.author,
  });

  final String id;
  final String from;
  final String body;
  final DateTime createdAt;
  final String? author;

  bool get isAdmin => from == 'admin';

  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    return SupportMessage(
      id: '${json['id'] ?? ''}',
      from: '${json['from'] ?? 'user'}',
      body: '${json['body'] ?? ''}',
      createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}') ?? DateTime.now(),
      author: json['author']?.toString(),
    );
  }
}
