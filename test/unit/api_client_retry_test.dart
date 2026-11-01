import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:koroli_dorog/core/api/api_client.dart';

void main() {
  test('a timed-out order POST is never sent twice', () async {
    var calls = 0;
    final client = ApiClient(httpClient: MockClient((request) async {
      calls++;
      throw TimeoutException('Response lost after server accepted order');
    }));
    await expectLater(
        client.post('/api/orders'), throwsA(isA<TimeoutException>()));
    expect(calls, 1);
    client.dispose();
  });

  test('a temporary read failure can recover', () async {
    var calls = 0;
    final client = ApiClient(httpClient: MockClient((request) async {
      calls++;
      if (calls == 1) throw http.ClientException('Temporary network error');
      return http.Response('{"ok":true}', 200);
    }));
    expect((await client.get('/api/health')).statusCode, 200);
    expect(calls, 2);
    client.dispose();
  });
}
