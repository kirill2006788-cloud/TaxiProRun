import 'package:koroli_dorog/core/api/models/api_models.dart';
import 'package:koroli_dorog/core/api/repositories/order_repository.dart';
import 'package:koroli_dorog/models/service_type.dart';

/// Configurable [OrderRepository] for unit tests (no network).
class FakeOrderRepository implements OrderRepository {
  FakeOrderRepository({
    this.activeOrder,
    this.orderById,
    this.tariffs = const [],
    this.createDelay = Duration.zero,
  });

  OrderDto? activeOrder;
  OrderDto? orderById;
  List<TariffDto> tariffs;
  Duration createDelay;

  CreateOrderRequest? lastCreateRequest;

  @override
  Future<List<TariffDto>> fetchTariffs({ServiceType? serviceType}) async {
    return tariffs;
  }

  @override
  Future<OrderDto> createOrder(CreateOrderRequest request) async {
    lastCreateRequest = request;
    if (createDelay > Duration.zero) {
      await Future<void>.delayed(createDelay);
    }
    return OrderDto(
      id: 'test-order-1',
      status: 'searching',
      fromAddress: request.fromAddress,
      toAddress: request.toAddress,
      serviceType: request.serviceType,
      paymentMethod: request.paymentMethod,
      priceFrom: 900,
      paymentStatus: 'unpaid',
    );
  }

  @override
  Future<OrderDto?> fetchActiveOrder() async => activeOrder;

  @override
  Future<OrderDto> fetchOrder(String orderId) async {
    return orderById ??
        OrderDto(id: orderId, status: 'searching', paymentStatus: 'unpaid');
  }

  @override
  Future<List<OrderDto>> fetchClientOrders({int limit = 50}) async => [];

  @override
  Future<void> cancelOrder(String orderId, {String? reason}) async {}

  @override
  Future<void> rateOrder(
    String orderId, {
    required int rating,
    String? comment,
  }) async {}

  @override
  Future<List<AddressSuggestionDto>> suggestAddresses(String query) async => [];

  @override
  Future<PriceQuoteDto?> fetchPriceQuote(PriceQuoteRequest request) async =>
      null;

  @override
  Future<List<OrderChatMessageDto>> fetchOrderChat(String orderId) async => [];

  @override
  Future<void> sendOrderChat(String orderId, String text) async {}
}
