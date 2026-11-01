import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

class AppBroadcast {
  const AppBroadcast({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.audience,
    this.endsAt,
    this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final String audience;
  final DateTime? endsAt;
  final DateTime? createdAt;

  bool get isMaintenance => type == 'maintenance';
  bool get isAlert => type == 'alert' || type == 'maintenance';
  bool get isSurge =>
      type == 'surge' ||
      type == 'busy' ||
      title.toLowerCase().contains('спрос') ||
      title.toLowerCase().contains('surge') ||
      body.toLowerCase().contains('высокий спрос');

  factory AppBroadcast.fromJson(Map<String, dynamic> json) {
    return AppBroadcast(
      id: '${json['id'] ?? ''}',
      title: '${json['title'] ?? ''}',
      body: '${json['body'] ?? ''}',
      type: '${json['type'] ?? 'news'}',
      audience: '${json['audience'] ?? 'all'}',
      endsAt: DateTime.tryParse('${json['endsAt'] ?? ''}'),
      createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}'),
    );
  }
}

class BroadcastService {
  BroadcastService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<AppBroadcast>> fetchActive({required String audience}) async {
    try {
      final base = ApiConfig.envBaseUrl.replaceAll(RegExp(r'/+$'), '');
      final uri = Uri.parse(
        '$base/api/broadcasts/active?audience=${Uri.encodeQueryComponent(audience)}',
      );
      final res = await _client.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        return const [];
      }
      final data = jsonDecode(res.body);
      final list = (data is Map && data['broadcasts'] is List)
          ? data['broadcasts'] as List
          : const [];
      return list
          .whereType<Map>()
          .map((e) => AppBroadcast.fromJson(Map<String, dynamic>.from(e)))
          .where((b) => b.id.isNotEmpty && b.title.isNotEmpty)
          .toList();
    } catch (_) {
      // Soft-fail: баннер просто скрывается.
      return const [];
    }
  }
}
