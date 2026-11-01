import '../../../models/service_type.dart';
import '../../geo/geo_search_service.dart';
import '../api_client.dart';
import '../models/api_models.dart';
import '../models/support_models.dart';
import '../repositories/order_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/support_repository.dart';
import '../repositories/user_repository.dart';

class OrderService {
  OrderService({
    OrderRepository? repository,
    GeoSearchService? geoSearch,
  })  : _repository = repository ?? OrderRepositoryImpl(),
        _geo = geoSearch;

  final OrderRepository _repository;
  final GeoSearchService? _geo;

  Future<List<TariffDto>> fetchTariffs({ServiceType? serviceType}) {
    return _repository.fetchTariffs(serviceType: serviceType);
  }

  Future<OrderDto> createOrder(CreateOrderRequest request) {
    return _repository.createOrder(request);
  }

  Future<OrderDto?> fetchActiveOrder() => _repository.fetchActiveOrder();

  Future<OrderDto> fetchOrder(String orderId) =>
      _repository.fetchOrder(orderId);

  Future<List<OrderDto>> fetchClientOrders({int limit = 50}) {
    return _repository.fetchClientOrders(limit: limit);
  }

  Future<void> cancelOrder(String orderId, {String? reason}) {
    return _repository.cancelOrder(orderId, reason: reason);
  }

  Future<void> rateOrder(String orderId,
      {required int rating, String? comment}) {
    return _repository.rateOrder(orderId, rating: rating, comment: comment);
  }

  Future<List<AddressSuggestionDto>> suggestAddresses(String query) {
    final geo = _geo;
    if (geo != null) return geo.suggest(query);
    return _repository.suggestAddresses(query);
  }

  Future<PriceQuoteDto?> fetchPriceQuote(PriceQuoteRequest request) {
    return _repository.fetchPriceQuote(request);
  }

  Future<List<OrderChatMessageDto>> fetchOrderChat(String orderId) {
    return _repository.fetchOrderChat(orderId);
  }

  Future<void> sendOrderChat(String orderId, String text) {
    return _repository.sendOrderChat(orderId, text);
  }
}

class UserService {
  UserService({UserRepository? repository})
      : _repository = repository ?? UserRepositoryImpl();

  final UserRepository _repository;

  Future<ClientProfileDto> fetchProfile({String? token}) {
    return _repository.fetchProfile(token: token);
  }

  Future<ClientProfileDto> updateProfile({
    required String clientId,
    required String fullName,
    required String phone,
    String? referralCode,
    String? addressHome,
    String? addressWork,
    String? addressFavorite,
    String? avatarBase64,
    String? token,
  }) {
    return _repository.updateProfile(
      clientId: clientId,
      fullName: fullName,
      phone: phone,
      referralCode: referralCode,
      addressHome: addressHome,
      addressWork: addressWork,
      addressFavorite: addressFavorite,
      avatarBase64: avatarBase64,
      token: token,
    );
  }

  Future<void> syncPushToken({
    required String clientId,
    required String token,
    required bool enabled,
    String? authToken,
  }) {
    return _repository.syncPushToken(
      clientId: clientId,
      token: token,
      enabled: enabled,
      authToken: authToken,
    );
  }

  Future<int> requestOtp(String phone) => _repository.requestOtp(phone);

  Future<String> verifyOtp({required String phone, required String code}) {
    return _repository.verifyOtp(phone: phone, code: code);
  }

  Future<int> activatePromo({
    required String clientId,
    required String code,
    String? token,
  }) {
    return _repository.activatePromo(
      clientId: clientId,
      code: code,
      token: token,
    );
  }
}

class SettingsService {
  SettingsService({SettingsRepository? repository})
      : _repository = repository ?? SettingsRepositoryImpl();

  final SettingsRepository _repository;

  Future<AppSettingsDto> loadLocalSettings() => _repository.loadLocalSettings();

  Future<void> saveLocalSettings(AppSettingsDto settings) {
    return _repository.saveLocalSettings(settings);
  }

  Future<AppSettingsDto?> fetchRemoteSettings({String? token}) {
    return _repository.fetchRemoteSettings(token: token);
  }

  Future<void> saveRemoteSettings(AppSettingsDto settings, {String? token}) {
    return _repository.saveRemoteSettings(settings, token: token);
  }
}

class SupportService {
  SupportService({SupportRepository? repository})
      : _repository = repository ?? SupportRepositoryImpl();

  final SupportRepository _repository;

  Future<List<SupportTicketDto>> fetchMine() => _repository.fetchMine();

  Future<SupportTicketDto> createTicket({
    required String subject,
    required String body,
  }) {
    return _repository.createTicket(subject: subject, body: body);
  }

  Future<SupportTicketDto?> fetchById(String id) => _repository.fetchById(id);
}

/// Фабрика сервисов с учётом mock/real переключателя.
class ApiServices {
  ApiServices({
    ApiClient? client,
    ApiConfigStore? config,
    GeoSearchService? geoSearch,
    OrderRepository? orderRepository,
  })  : _client = client ?? ApiClient(configStore: config),
        _config = config ?? ApiConfigStore.instance {
    final useMock = _config.useMockApi;
    geo = geoSearch ??
        GeoSearchService(
          apiClient: _client,
          configStore: _config,
        );
    order = OrderService(
      repository: orderRepository ??
          (useMock ? MockOrderRepository() : RealOrderRepository(_client)),
      geoSearch: geo,
    );
    user = UserService(
      repository: useMock ? MockUserRepository() : RealUserRepository(_client),
    );
    settings = SettingsService(
      repository:
          useMock ? MockSettingsRepository() : RealSettingsRepository(_client),
    );
    support = SupportService(
      repository:
          useMock ? MockSupportRepository() : RealSupportRepository(_client),
    );
  }

  final ApiClient _client;
  final ApiConfigStore _config;

  late final GeoSearchService geo;
  late final OrderService order;
  late final UserService user;
  late final SettingsService settings;
  late final SupportService support;

  void dispose() {
    geo.dispose();
    _client.dispose();
  }
}
