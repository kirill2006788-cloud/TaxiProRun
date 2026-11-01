import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:driver_app/core/api/api_client.dart';
import 'package:driver_app/core/api/api_config.dart';

void main() {
  test('a timed-out driver POST is sent only once', () async {
    var calls = 0;
    final api = ApiClient(httpClient: MockClient((request) async {
      calls++;
      throw TimeoutException('Server may have already processed the request');
    }));
    await expectLater(
        api.postJson('/driver/profile'), throwsA(isA<TimeoutException>()));
    expect(calls, 1);
    api.dispose();
  });

  test('driver can recover from a temporary read failure', () async {
    var calls = 0;
    final api = ApiClient(httpClient: MockClient((request) async {
      calls++;
      if (calls == 1) throw http.ClientException('Temporary network error');
      return http.Response('{"ok":true}', 200);
    }));
    expect((await api.getJson('/driver/profile'))['ok'], true);
    expect(calls, 2);
    api.dispose();
  });

  test('server address accepts /api without duplicating it', () {
    final previous = ApiConfig.baseUrl;
    ApiConfig.setBaseUrl('https://example.com/api/');
    expect(ApiConfig.resolveUrl('/driver/profile'),
        'https://example.com/api/driver/profile');
    ApiConfig.setBaseUrl(previous);
  });
}
