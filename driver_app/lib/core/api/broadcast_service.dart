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
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final String audience;

  bool get isAlert => type == 'alert' || type == 'maintenance';

  factory AppBroadcast.fromJson(Map<String, dynamic> json) {
    return AppBroadcast(
      id: '${json['id'] ?? ''}',
      title: '${json['title'] ?? ''}',
      body: '${json['body'] ?? ''}',
      type: '${json['type'] ?? 'news'}',
      audience: '${json['audience'] ?? 'all'}',
    );
  }
}

class BroadcastService {
  Future<List<AppBroadcast>> fetchActive() async {
    try {
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/broadcasts/active?audience=drivers',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
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
      return const [];
    }
  }
}
