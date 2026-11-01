/// Обращение в поддержку (клиент / водитель).
class SupportTicketDto {
  const SupportTicketDto({
    required this.id,
    required this.subject,
    required this.body,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.authorRole,
    this.authorPhone,
    this.authorName,
    this.messages = const [],
  });

  final String id;
  final String subject;
  final String body;
  final String status; // open | replied | closed
  final String? authorRole;
  final String? authorPhone;
  final String? authorName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<SupportMessageDto> messages;

  bool get isClosed => status == 'closed';
  bool get isReplied => status == 'replied';
  bool get isOpen => status == 'open' || status.isEmpty;

  String get statusLabelRu => switch (status) {
        'replied' => 'Есть ответ',
        'closed' => 'Закрыто',
        _ => 'Открыто',
      };

  factory SupportTicketDto.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'];
    final messages = rawMessages is List
        ? rawMessages
            .whereType<Map>()
            .map((e) => SupportMessageDto.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <SupportMessageDto>[];

    return SupportTicketDto(
      id: '${json['id'] ?? ''}',
      subject: '${json['subject'] ?? ''}',
      body: '${json['body'] ?? ''}',
      status: '${json['status'] ?? 'open'}',
      authorRole: json['authorRole']?.toString(),
      authorPhone: json['authorPhone']?.toString(),
      authorName: json['authorName']?.toString(),
      createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}') ?? DateTime.now(),
      updatedAt: DateTime.tryParse('${json['updatedAt'] ?? ''}') ?? DateTime.now(),
      messages: messages,
    );
  }
}

class SupportMessageDto {
  const SupportMessageDto({
    required this.id,
    required this.from,
    required this.body,
    required this.createdAt,
    this.author,
  });

  final String id;
  final String from; // user | admin
  final String body;
  final DateTime createdAt;
  final String? author;

  bool get isAdmin => from == 'admin';
  bool get isUser => from == 'user';

  factory SupportMessageDto.fromJson(Map<String, dynamic> json) {
    return SupportMessageDto(
      id: '${json['id'] ?? ''}',
      from: '${json['from'] ?? 'user'}',
      body: '${json['body'] ?? ''}',
      createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}') ?? DateTime.now(),
      author: json['author']?.toString(),
    );
  }
}
