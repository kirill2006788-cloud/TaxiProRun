import 'dart:convert';

import '../../../data/tariffs.dart';
import '../../../models/service_type.dart';
import '../../auth/auth_store.dart';
import '../../geo/geo_config.dart';
import '../../geo/moscow_sample_addresses.dart';
import '../api_client.dart';
import '../api_config.dart';
import '../models/api_models.dart';

abstract class OrderRepository {
  Future<List<TariffDto>> fetchTariffs({ServiceType? serviceType});
  Future<OrderDto> createOrder(CreateOrderRequest request);
  Future<OrderDto?> fetchActiveOrder();
  Future<OrderDto> fetchOrder(String orderId);
  Future<List<OrderDto>> fetchClientOrders({int limit = 50});
  Future<void> cancelOrder(String orderId, {String? reason});
  Future<void> rateOrder(String orderId,
      {required int rating, String? comment});
  Future<List<AddressSuggestionDto>> suggestAddresses(String query);
  Future<PriceQuoteDto?> fetchPriceQuote(PriceQuoteRequest request);
  Future<List<OrderChatMessageDto>> fetchOrderChat(String orderId);
  Future<void> sendOrderChat(String orderId, String text);
}

class OrderRepositoryImpl extends OrderRepository {
  OrderRepositoryImpl({OrderRepository? delegate})
      : _delegate = delegate ?? MockOrderRepository();

  final OrderRepository _delegate;

  @override
  Future<List<TariffDto>> fetchTariffs({ServiceType? serviceType}) =>
      _delegate.fetchTariffs(serviceType: serviceType);

  @override
  Future<OrderDto> createOrder(CreateOrderRequest request) =>
      _delegate.createOrder(request);

  @override
  Future<OrderDto?> fetchActiveOrder() => _delegate.fetchActiveOrder();

  @override
  Future<OrderDto> fetchOrder(String orderId) => _delegate.fetchOrder(orderId);

  @override
  Future<List<OrderDto>> fetchClientOrders({int limit = 50}) =>
      _delegate.fetchClientOrders(limit: limit);

  @override
  Future<void> cancelOrder(String orderId, {String? reason}) =>
      _delegate.cancelOrder(orderId, reason: reason);

  @override
  Future<void> rateOrder(String orderId,
          {required int rating, String? comment}) =>
      _delegate.rateOrder(orderId, rating: rating, comment: comment);

  @override
  Future<List<AddressSuggestionDto>> suggestAddresses(String query) =>
      _delegate.suggestAddresses(query);

  @override
  Future<PriceQuoteDto?> fetchPriceQuote(PriceQuoteRequest request) =>
      _delegate.fetchPriceQuote(request);

  @override
  Future<List<OrderChatMessageDto>> fetchOrderChat(String orderId) =>
      _delegate.fetchOrderChat(orderId);

  @override
  Future<void> sendOrderChat(String orderId, String text) =>
      _delegate.sendOrderChat(orderId, text);
}

class MockOrderRepository implements OrderRepository {
  static List<TariffDto> localTariffs({ServiceType? serviceType}) {
    final tariffs = serviceType?.isSoberMode == true
        ? Tariffs.all
            .where((t) => t.isSoberDriver || t.id == 'comfort')
            .toList()
        : Tariffs.all.where((t) => !t.isSoberDriver).toList();

    return tariffs
        .map(
          (t) => TariffDto(
            id: t.id,
            name: t.name,
            clientRatePerKm: t.clientRatePerKm,
            driverRatePerKm: t.driverRatePerKm,
            description: t.description,
            maxPassengers: t.maxPassengers,
            maxBags: t.maxBags,
            icon: t.icon,
            isSoberDriver: t.isSoberDriver,
            serviceIndex: t.isSoberDriver ? 0 : null,
          ),
        )
        .toList();
  }

  @override
  Future<List<TariffDto>> fetchTariffs({ServiceType? serviceType}) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return localTariffs(serviceType: serviceType);
  }

  @override
  Future<OrderDto> createOrder(CreateOrderRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    return OrderDto(
      id: 'mock-${DateTime.now().millisecondsSinceEpoch}',
      status: 'searching',
      fromAddress: request.fromAddress,
      toAddress: request.toAddress,
      serviceType: request.serviceType,
      paymentMethod: request.paymentMethod,
      scheduledAt: request.scheduledAt,
      priceFrom: 1200,
      paymentStatus: 'unpaid',
    );
  }

  @override
  Future<OrderDto?> fetchActiveOrder() async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return null;
  }

  @override
  Future<OrderDto> fetchOrder(String orderId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return OrderDto(
      id: orderId,
      status: 'searching',
      paymentStatus: 'unpaid',
      priceFrom: 1200,
    );
  }

  @override
  Future<List<OrderDto>> fetchClientOrders({int limit = 50}) async {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    return [];
  }

  @override
  Future<void> cancelOrder(String orderId, {String? reason}) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<void> rateOrder(String orderId,
      {required int rating, String? comment}) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<List<AddressSuggestionDto>> suggestAddresses(String query) async {
    await Future<void>.delayed(const Duration(milliseconds: 280));
    final q = query.trim().toLowerCase();
    if (q.length < GeoConfig.minQueryLength) return [];
    final tokens = q.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    return moscowSampleAddresses
        .where((item) {
          final hay = '${item.title} ${item.subtitle}'.toLowerCase();
          return tokens.every((t) => hay.contains(t));
        })
        .take(GeoConfig.maxResults)
        .toList();
  }

  @override
  Future<PriceQuoteDto?> fetchPriceQuote(PriceQuoteRequest request) async {
    return null;
  }

  @override
  Future<List<OrderChatMessageDto>> fetchOrderChat(String orderId) async {
    return const [];
  }

  @override
  Future<void> sendOrderChat(String orderId, String text) async {}
}

class RealOrderRepository implements OrderRepository {
  RealOrderRepository(this._client, {AuthStore? authStore})
      : _auth = authStore ?? AuthStore();

  final ApiClient _client;
  final AuthStore _auth;

  Future<String?> _token() => _auth.readToken();

  @override
  Future<List<TariffDto>> fetchTariffs({ServiceType? serviceType}) async {
    final path = serviceType?.isTaxi == true
        ? ApiEndpoints.taxiTariffs
        : ApiEndpoints.tariffs;
    try {
      final res = await _client.get(path, token: await _token());
      if (res.statusCode < 200 || res.statusCode >= 300) {
        if (serviceType?.isTaxi == true && ApiConfig.useMockApi) {
          return MockOrderRepository.localTariffs(serviceType: serviceType);
        }
        throw ApiException(
          'Не удалось загрузить тарифы',
          statusCode: res.statusCode,
          body: res.body,
        );
      }
      final map = _decodeMap(res.body);
      final list = map['tariffs'] as List? ?? [];
      final parsed = list
          .whereType<Map>()
          .map((e) => TariffDto.fromJson(e.cast<String, dynamic>()))
          .toList();
      if (parsed.isEmpty &&
          serviceType?.isTaxi == true &&
          ApiConfig.useMockApi) {
        return MockOrderRepository.localTariffs(serviceType: serviceType);
      }
      return parsed;
    } on ApiException {
      rethrow;
    } catch (_) {
      if (serviceType?.isTaxi == true && ApiConfig.useMockApi) {
        return MockOrderRepository.localTariffs(serviceType: serviceType);
      }
      rethrow;
    }
  }

  @override
  Future<OrderDto> createOrder(CreateOrderRequest request) async {
    final res = await _client.post(
      ApiEndpoints.orders,
      body: request.toJson(),
      token: await _token(),
      timeout: ApiConfig.orderTimeout,
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(
        _messageFromBody(res.body) ?? 'Не удалось создать заказ',
        statusCode: res.statusCode,
        body: res.body,
      );
    }
    return OrderDto.fromJson(_decodeMap(res.body));
  }

  @override
  Future<OrderDto?> fetchActiveOrder() async {
    final res = await _client.get(
      ApiEndpoints.ordersActiveClient,
      token: await _token(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) return null;
    final map = _decodeMap(res.body);
    final order = map['order'];
    if (order == null) return null;
    return OrderDto.fromJson(map);
  }

  @override
  Future<OrderDto> fetchOrder(String orderId) async {
    final res = await _client.get(
      ApiEndpoints.orderById(orderId),
      token: await _token(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(
        'Заказ не найден',
        statusCode: res.statusCode,
        body: res.body,
      );
    }
    return OrderDto.fromJson(_decodeMap(res.body));
  }

  @override
  Future<List<OrderDto>> fetchClientOrders({int limit = 50}) async {
    final res = await _client.get(
      ApiEndpoints.ordersHistoryClient,
      query: {'limit': '$limit'},
      token: await _token(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) return [];
    final map = _decodeMap(res.body);
    final list = map['orders'] ?? map['items'] ?? map['history'];
    if (list is! List) return [];
    return list
        .whereType<Map>()
        .map((e) => OrderDto.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<void> cancelOrder(String orderId, {String? reason}) async {
    final res = await _client.post(
      ApiEndpoints.orderCancel(orderId),
      body: {if (reason != null) 'reason': reason},
      token: await _token(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(
        _messageFromBody(res.body) ?? 'Не удалось отменить заказ',
        statusCode: res.statusCode,
        body: res.body,
      );
    }
  }

  @override
  Future<void> rateOrder(String orderId,
      {required int rating, String? comment}) async {
    final res = await _client.post(
      ApiEndpoints.orderRate(orderId),
      body: {'rating': rating, if (comment != null) 'comment': comment},
      token: await _token(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(
        _messageFromBody(res.body) ?? 'Не удалось отправить оценку',
        statusCode: res.statusCode,
        body: res.body,
      );
    }
  }

  @override
  Future<List<AddressSuggestionDto>> suggestAddresses(String query) async {
    final params = {'q': query, 'query': query, 'text': query};
    final body = {'q': query, 'query': query, 'text': query};

    for (final path in [ApiEndpoints.geoSuggest, ApiEndpoints.geocodeSuggest]) {
      for (final usePost in [false, true]) {
        try {
          final res = usePost
              ? await _client.post(
                  path,
                  body: body,
                  token: await _token(),
                )
              : await _client.get(
                  path,
                  query: params,
                  token: await _token(),
                );
          if (res.statusCode == 404 || res.statusCode == 405) continue;
          if (res.statusCode < 200 || res.statusCode >= 300) continue;
          final map = _decodeMap(res.body);
          final items = map['items'] ??
              map['suggestions'] ??
              map['results'] ??
              map['data'];
          if (items is List) {
            final parsed = items
                .whereType<Map>()
                .map(
                  (e) => AddressSuggestionDto.fromJson(
                    e.cast<String, dynamic>(),
                  ),
                )
                .where((e) => e.title.isNotEmpty)
                .toList();
            if (parsed.isNotEmpty) return parsed;
          }
        } catch (_) {}
      }
    }
    return [];
  }

  @override
  Future<PriceQuoteDto?> fetchPriceQuote(PriceQuoteRequest request) async {
    final paths = request.serviceType.isTaxi
        ? [ApiEndpoints.taxiQuote, ApiEndpoints.ordersQuote]
        : [ApiEndpoints.ordersQuote, ApiEndpoints.taxiQuote];
    for (final path in paths) {
      try {
        final res = await _client.post(
          path,
          body: request.toJson(),
          token: await _token(),
        );
        if (res.statusCode == 404 || res.statusCode == 405) continue;
        if (res.statusCode < 200 || res.statusCode >= 300) continue;
        final map = _decodeMap(res.body);
        final quote = PriceQuoteDto.fromJson(map);
        if (quote.priceFrom > 0) return quote;
      } catch (_) {}
    }
    return null;
  }

  @override
  Future<List<OrderChatMessageDto>> fetchOrderChat(String orderId) async {
    try {
      final res = await _client.get(
        ApiEndpoints.orderChat(orderId),
        token: await _token(),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) return [];
      final map = _decodeMap(res.body);
      final list = map['messages'] ?? map['items'] ?? map['chat'];
      if (list is! List) return [];
      return list
          .whereType<Map>()
          .map((e) => OrderChatMessageDto.fromJson(e.cast<String, dynamic>()))
          .where((m) => m.body.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> sendOrderChat(String orderId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final res = await _client.post(
      ApiEndpoints.orderChat(orderId),
      body: {'text': trimmed, 'body': trimmed},
      token: await _token(),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(
        _messageFromBody(res.body) ?? 'Не удалось отправить сообщение',
        statusCode: res.statusCode,
        body: res.body,
      );
    }
  }

  Map<String, dynamic> _decodeMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map) return decoded.cast<String, dynamic>();
    return {};
  }

  String? _messageFromBody(String body) {
    try {
      final map = _decodeMap(body);
      final message = map['message'];
      if (message is String && message.trim().isNotEmpty) return message.trim();
      if (message is List && message.isNotEmpty) {
        return message.map((e) => e.toString()).join(', ');
      }
    } catch (_) {}
    return null;
  }
}
