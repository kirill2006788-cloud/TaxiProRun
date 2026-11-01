import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api_client.dart';

/// Централизованные русскоязычные сообщения об ошибках HTTP / сети / сокета.
abstract final class AppErrorMapper {
  static String toRussian(
    Object error, {
    String fallback = 'Не удалось выполнить запрос. Попробуйте позже',
  }) {
    if (error is ApiException) {
      return _fromApiException(error) ?? fallback;
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
    if (error is FormatException) {
      return 'Сервер вернул некорректный ответ';
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

  static String? _fromApiException(ApiException e) {
    final code = e.statusCode;
    final bodyMsg = e.message.trim();
    if (bodyMsg.isNotEmpty &&
        !bodyMsg.toLowerCase().startsWith('httpexception') &&
        bodyMsg != 'Internal Server Error') {
      // Уже человекочитаемое сообщение с бэкенда / репозитория.
      if (_looksRussianOrFriendly(bodyMsg)) return bodyMsg;
    }

    return switch (code) {
      400 => 'Некорректный запрос. Проверьте введённые данные',
      401 => 'Сессия истекла. Войдите снова',
      403 => 'Доступ запрещён',
      404 => 'Данные не найдены',
      408 => 'Превышено время ожидания. Попробуйте позже',
      429 => 'Слишком много запросов. Подождите минуту',
      500 || 502 || 503 || 504 => 'Сервер временно недоступен. Попробуйте позже',
      _ => bodyMsg.isNotEmpty ? bodyMsg : null,
    };
  }

  static bool _looksRussianOrFriendly(String msg) {
    return RegExp(r'[А-Яа-яЁё]').hasMatch(msg) ||
        msg.contains(' ') ||
        msg.length > 12;
  }
}
