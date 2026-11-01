import 'dart:convert';

import 'package:url_launcher/url_launcher.dart';

import '../../models/payment_method.dart';
import '../api/api_client.dart';
import '../api/api_config.dart';
import '../auth/auth_store.dart';

enum PaymentHandleResult { ready, openedUrl, unavailable }

/// Server-driven payment flow. The mobile app never marks an order as paid.
class PaymentService {
  PaymentService._();

  static final PaymentService instance = PaymentService._();

  final ApiClient _client = ApiClient();
  final AuthStore _auth = AuthStore();
  Map<String, bool>? _methods;
  DateTime? _methodsLoadedAt;

  String labelFor(PaymentMethod method) => method.label;

  Future<bool> isAvailable(PaymentMethod method) async {
    if (method == PaymentMethod.cash) return true;
    final loadedAt = _methodsLoadedAt;
    if (_methods == null ||
        loadedAt == null ||
        DateTime.now().difference(loadedAt) > const Duration(minutes: 5)) {
      try {
        final response = await _client.get(
          ApiEndpoints.paymentsConfig,
          token: await _auth.readToken(),
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return false;
        }
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final methods = json['methods'] as Map? ?? const {};
        _methods = {
          'cash': methods['cash'] == true,
          'card': methods['card'] == true,
          'sbp': methods['sbp'] == true,
        };
        _methodsLoadedAt = DateTime.now();
      } catch (_) {
        return false;
      }
    }
    return _methods?[method.name] == true;
  }

  Future<PaymentHandleResult> startForOrder({
    required String orderId,
    required PaymentMethod method,
  }) async {
    if (method == PaymentMethod.cash) return PaymentHandleResult.ready;
    if (!await isAvailable(method)) return PaymentHandleResult.unavailable;
    try {
      final response = await _client.post(
        ApiEndpoints.paymentIntents,
        token: await _auth.readToken(),
        body: {'orderId': orderId, 'method': method.name},
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return PaymentHandleResult.unavailable;
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final intent = json['intent'] as Map?;
      final checkoutUrl = intent?['checkoutUrl']?.toString() ?? '';
      final uri = Uri.tryParse(checkoutUrl);
      if (uri == null || uri.scheme != 'https') {
        return PaymentHandleResult.unavailable;
      }
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      return opened
          ? PaymentHandleResult.openedUrl
          : PaymentHandleResult.unavailable;
    } catch (_) {
      return PaymentHandleResult.unavailable;
    }
  }

  String unavailableMessage(PaymentMethod method) => switch (method) {
        PaymentMethod.card =>
          'Оплата картой пока недоступна: эквайринг ещё не настроен на сервере',
        PaymentMethod.sbp =>
          'Оплата через СБП пока недоступна: эквайринг ещё не настроен на сервере',
        PaymentMethod.cash => '',
      };
}
