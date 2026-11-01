import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Ошибка API с кодом статуса.
class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    this.body,
    this.message,
    this.code,
  });

  final int statusCode;
  final String? body;
  final String? message;
  final String? code;

  @override
  String toString() =>
      'ApiException($statusCode${code != null ? ', $code' : ''}): ${message ?? body ?? ''}';
}

/// Централизованные русскоязычные сообщения (HTTP / сеть / сокет).
abstract final class AppErrorMapper {
  static String toRussian(
    Object error, {
    String fallback = 'Ошибка сети. Попробуйте позже',
  }) {
    if (error is ApiException) {
      if (error.statusCode == 429) {
        return 'Слишком часто. Подождите минуту';
      }
      if (error.code == 'EARNINGS_LIMIT_REACHED') {
        return 'Достигнут лимит комиссии. Обратитесь в поддержку';
      }
      if (error.code == 'DRIVER_BLOCKED') {
        return 'Аккаунт заблокирован';
      }
      if (error.code == 'ORDER_TAKEN') {
        return 'Заказ уже принят другим водителем';
      }
      final msg = error.message?.trim();
      if (msg != null && msg.isNotEmpty && _looksFriendly(msg)) {
        return msg;
      }
      return switch (error.statusCode) {
        400 => 'Некорректный запрос. Проверьте введённые данные',
        401 => 'Сессия истекла. Войдите снова',
        403 => 'Доступ запрещён',
        404 => 'Данные не найдены',
        408 => 'Превышено время ожидания. Попробуйте позже',
        500 || 502 || 503 || 504 =>
          'Сервер временно недоступен. Попробуйте позже',
        _ => msg?.isNotEmpty == true ? msg! : fallback,
      };
    }
    if (error is TimeoutException) {
      return 'Превышено время ожидания. Проверьте интернет и попробуйте снова';
    }
    if (error is SocketException) {
      return 'Нет подключения к интернету';
    }
    if (error is http.ClientException) {
      return 'Ошибка сети. Проверьте подключение';
    }
    if (error is StateError) {
      final m = error.message;
      if (m.contains('связи') || m.contains('сервер')) return m;
    }
    final text = error.toString().toLowerCase();
    if (text.contains('socket') ||
        text.contains('network') ||
        text.contains('connection') ||
        text.contains('failed host lookup')) {
      return 'Нет подключения к интернету';
    }
    if (text.contains('timeout')) {
      return 'Превышено время ожидания. Попробуйте позже';
    }
    return fallback;
  }

  static bool _looksFriendly(String msg) {
    return RegExp(r'[А-Яа-яЁё]').hasMatch(msg) ||
        msg.contains(' ') ||
        msg.length > 12;
  }
}

/// Совместимость со старыми вызовами.
String apiErrorMessage(Object error) => AppErrorMapper.toRussian(error);
