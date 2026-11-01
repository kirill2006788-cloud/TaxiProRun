import 'dart:convert';

import '../../auth/auth_store.dart';
import '../api_client.dart';
import '../api_config.dart';
import '../app_error_mapper.dart';
import '../models/support_models.dart';

abstract class SupportRepository {
  Future<List<SupportTicketDto>> fetchMine();
  Future<SupportTicketDto> createTicket({
    required String subject,
    required String body,
  });
  Future<SupportTicketDto?> fetchById(String id);
}

class SupportRepositoryImpl implements SupportRepository {
  SupportRepositoryImpl({SupportRepository? repository})
      : _inner = repository ??
            (ApiConfigStore.instance.useMockApi
                ? MockSupportRepository()
                : RealSupportRepository(ApiClient()));

  final SupportRepository _inner;

  @override
  Future<List<SupportTicketDto>> fetchMine() => _inner.fetchMine();

  @override
  Future<SupportTicketDto> createTicket({
    required String subject,
    required String body,
  }) =>
      _inner.createTicket(subject: subject, body: body);

  @override
  Future<SupportTicketDto?> fetchById(String id) => _inner.fetchById(id);
}

class MockSupportRepository implements SupportRepository {
  static final List<SupportTicketDto> _tickets = [];

  @override
  Future<List<SupportTicketDto>> fetchMine() async {
    await Future<void>.delayed(const Duration(milliseconds: 280));
    final copy = List<SupportTicketDto>.from(_tickets);
    copy.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return copy;
  }

  @override
  Future<SupportTicketDto> createTicket({
    required String subject,
    required String body,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 320));
    final now = DateTime.now();
    final ticket = SupportTicketDto(
      id: 'st_mock_${now.millisecondsSinceEpoch}',
      subject: subject.trim(),
      body: body.trim(),
      status: 'open',
      createdAt: now,
      updatedAt: now,
      messages: [
        SupportMessageDto(
          id: 'sm_mock_${now.millisecondsSinceEpoch}',
          from: 'user',
          body: body.trim(),
          createdAt: now,
        ),
      ],
    );
    _tickets.insert(0, ticket);
    return ticket;
  }

  @override
  Future<SupportTicketDto?> fetchById(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    for (final t in _tickets) {
      if (t.id == id) return t;
    }
    return null;
  }
}

class RealSupportRepository implements SupportRepository {
  RealSupportRepository(this._client, {AuthStore? authStore})
      : _auth = authStore ?? AuthStore();

  final ApiClient _client;
  final AuthStore _auth;

  Future<String?> _token() => _auth.readToken();

  @override
  Future<List<SupportTicketDto>> fetchMine() async {
    try {
      final res = await _client.get(
        ApiEndpoints.supportTicketsMine,
        token: await _token(),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw ApiException(
          AppErrorMapper.toRussian(
            ApiException('Не удалось загрузить обращения', statusCode: res.statusCode),
          ),
          statusCode: res.statusCode,
          body: res.body,
        );
      }
      final map = _decodeMap(res.body);
      final list = map['tickets'];
      if (list is! List) return const [];
      return list
          .whereType<Map>()
          .map((e) => SupportTicketDto.fromJson(Map<String, dynamic>.from(e)))
          .where((t) => t.id.isNotEmpty)
          .toList();
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(AppErrorMapper.toRussian(e));
    }
  }

  @override
  Future<SupportTicketDto> createTicket({
    required String subject,
    required String body,
  }) async {
    try {
      final res = await _client.post(
        ApiEndpoints.supportTickets,
        body: {'subject': subject.trim(), 'body': body.trim()},
        token: await _token(),
      );
      final map = _decodeMap(res.body);
      if (res.statusCode < 200 || res.statusCode >= 300 || map['ok'] == false) {
        throw ApiException(
          AppErrorMapper.toRussian(
            ApiException(
              '${map['error'] ?? 'Не удалось создать обращение'}',
              statusCode: res.statusCode,
            ),
          ),
          statusCode: res.statusCode,
          body: res.body,
        );
      }
      final ticket = map['ticket'];
      if (ticket is! Map) {
        throw ApiException('Сервер не вернул обращение');
      }
      return SupportTicketDto.fromJson(Map<String, dynamic>.from(ticket));
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(AppErrorMapper.toRussian(e));
    }
  }

  @override
  Future<SupportTicketDto?> fetchById(String id) async {
    final list = await fetchMine();
    for (final t in list) {
      if (t.id == id) return t;
    }
    return null;
  }

  Map<String, dynamic> _decodeMap(String body) {
    if (body.isEmpty) return {};
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return {};
  }
}
