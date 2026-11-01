/// Конфигурация API — VPS backend (эндпоинты уже с префиксом `/api`).
abstract final class ApiConfig {
  /// Базовый URL по умолчанию (хост без `/api` — пути в [ApiEndpoints]).
  static const defaultBaseUrl = 'http://161.104.19.23';

  /// Переключение mock / real через `--dart-define=USE_MOCK_API=true` (dev).
  /// По умолчанию — реальный API; mock только для локальной разработки.
  static const useMockApi = bool.fromEnvironment(
    'USE_MOCK_API',
    defaultValue: false,
  );

  /// Переопределение URL через `--dart-define=API_BASE_URL=...`.
  static const envBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: defaultBaseUrl,
  );

  static const connectTimeout = Duration(seconds: 10);
  static const orderTimeout = Duration(seconds: 25);
}

/// Константы эндпоинтов (именование как в 2048 + taxi-расширения).
abstract final class ApiEndpoints {
  // Auth
  static const authOtpRequest = '/api/auth/otp/request';
  static const authOtpVerify = '/api/auth/otp/verify';

  // Geo
  static const geoSuggest = '/api/geo/suggest';
  static const geocodeSuggest = '/api/geocode/suggest';

  // Client
  static const clientProfile = '/api/client/profile';
  static const clientPushToken = '/api/client/push-token';
  static const clientPromoActivate = '/api/client/promo/activate';

  // Orders
  static const orders = '/api/orders';
  static const ordersActiveClient = '/api/orders/active/client';
  static const ordersHistoryClient = '/api/orders/history/client';
  static String orderById(String id) => '/api/orders/$id';
  static String orderCancel(String id) => '/api/orders/$id/cancel';
  static String orderRate(String id) => '/api/orders/$id/rate';
  static String orderChat(String id) => '/api/orders/$id/chat';

  // Payments
  static const paymentsConfig = '/api/payments/config';
  static const paymentIntents = '/api/payments/intents';

  // Tariffs & driver
  static const tariffs = '/api/tariffs';
  static String driverPublic(String phone) => '/api/driver/public/$phone';

  // TaxiPro extensions
  static const taxiTariffs = '/api/taxi/tariffs';
  static const taxiQuote = '/api/taxi/quote';
  static const ordersQuote = '/api/orders/quote';
  static const appSettings = '/api/client/settings';

  // Support tickets
  static const supportTickets = '/api/support/tickets';
  static const supportTicketsMine = '/api/support/tickets/mine';
}
