import '../api_client.dart';
import '../api_config.dart';
import '../api_exception.dart';
import '../../../models/support_ticket.dart';

class SupportService {
  SupportService(this._client);

  final ApiClient _client;

  Future<List<SupportTicket>> fetchMine() async {
    if (ApiConfig.useMock) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      return List<SupportTicket>.from(_mockTickets);
    }
    try {
      final map = await _client.getJson('/support/tickets/mine');
      final list = map['tickets'];
      if (list is! List) return const [];
      return list
          .whereType<Map>()
          .map((e) => SupportTicket.fromJson(Map<String, dynamic>.from(e)))
          .where((t) => t.id.isNotEmpty)
          .toList();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        statusCode: 0,
        message: AppErrorMapper.toRussian(e),
      );
    }
  }

  Future<SupportTicket> createTicket({
    required String subject,
    required String body,
  }) async {
    if (ApiConfig.useMock) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final now = DateTime.now();
      final ticket = SupportTicket(
        id: 'st_mock_${now.millisecondsSinceEpoch}',
        subject: subject.trim(),
        body: body.trim(),
        status: 'open',
        createdAt: now,
        updatedAt: now,
        messages: [
          SupportMessage(
            id: 'sm_mock_${now.millisecondsSinceEpoch}',
            from: 'user',
            body: body.trim(),
            createdAt: now,
          ),
        ],
      );
      _mockTickets.insert(0, ticket);
      return ticket;
    }
    try {
      final map = await _client.postJson(
        '/support/tickets',
        body: {'subject': subject.trim(), 'body': body.trim()},
      );
      if (map['ok'] == false) {
        throw ApiException(
          statusCode: 400,
          message: '${map['error'] ?? 'Не удалось создать обращение'}',
        );
      }
      final ticket = map['ticket'];
      if (ticket is! Map) {
        throw const ApiException(statusCode: 500, message: 'Сервер не вернул обращение');
      }
      return SupportTicket.fromJson(Map<String, dynamic>.from(ticket));
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
        statusCode: 0,
        message: AppErrorMapper.toRussian(e),
      );
    }
  }

  Future<SupportTicket?> fetchById(String id) async {
    final list = await fetchMine();
    for (final t in list) {
      if (t.id == id) return t;
    }
    return null;
  }

  static final List<SupportTicket> _mockTickets = [];
}
