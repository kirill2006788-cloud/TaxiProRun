import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:koroli_dorog/core/api/api_client.dart';
import 'package:koroli_dorog/core/api/app_error_mapper.dart';

void main() {
  group('AppErrorMapper.toRussian', () {
    test('maps ApiException 401 to session message', () {
      final msg = AppErrorMapper.toRussian(
        ApiException('Unauthorized', statusCode: 401),
      );
      expect(msg, 'Сессия истекла. Войдите снова');
    });

    test('maps ApiException 404', () {
      final msg = AppErrorMapper.toRussian(
        ApiException('', statusCode: 404),
      );
      expect(msg, 'Данные не найдены');
    });

    test('maps ApiException 429', () {
      final msg = AppErrorMapper.toRussian(
        ApiException('', statusCode: 429),
      );
      expect(msg, 'Слишком много запросов. Подождите минуту');
    });

    test('maps ApiException 503', () {
      final msg = AppErrorMapper.toRussian(
        ApiException('', statusCode: 503),
      );
      expect(msg, 'Сервер временно недоступен. Попробуйте позже');
    });

    test('preserves Russian backend message', () {
      final msg = AppErrorMapper.toRussian(
        ApiException('Неверный код подтверждения', statusCode: 400),
      );
      expect(msg, 'Неверный код подтверждения');
    });

    test('maps TimeoutException', () {
      final msg = AppErrorMapper.toRussian(TimeoutException('timeout'));
      expect(msg, contains('Превышено время ожидания'));
    });

    test('maps SocketException', () {
      final msg = AppErrorMapper.toRussian(
        const SocketException('Failed host lookup'),
      );
      expect(msg, 'Нет подключения к интернету');
    });

    test('maps http.ClientException', () {
      final msg = AppErrorMapper.toRussian(
        http.ClientException('Connection closed'),
      );
      expect(msg, 'Ошибка сети. Проверьте подключение');
    });

    test('maps FormatException', () {
      final msg = AppErrorMapper.toRussian(const FormatException('bad json'));
      expect(msg, 'Сервер вернул некорректный ответ');
    });

    test('uses fallback for unknown errors', () {
      const fallback = 'Своя ошибка';
      final msg = AppErrorMapper.toRussian(Exception('xyz'), fallback: fallback);
      expect(msg, fallback);
    });
  });
}
