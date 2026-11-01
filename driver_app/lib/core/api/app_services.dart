import 'api_client.dart';
import 'api_config.dart';
import 'driver_location_ticker.dart';
import 'repositories/api_driver_profile_repository.dart';
import 'repositories/api_orders_repository.dart';
import 'repositories/api_settings_repository.dart';
import 'repositories/mock_driver_profile_repository.dart';
import 'repositories/mock_orders_repository.dart';
import 'repositories/mock_settings_repository.dart';
import 'repositories/repositories.dart';
import 'services/driver_profile_service.dart';
import 'services/orders_service.dart';
import 'services/settings_service.dart';
import 'services/support_service.dart';
import 'socket_service.dart';

/// Фабрика репозиториев — переключение mock ↔ API по [ApiConfig.useMock].
class AppServices {
  AppServices._({
    required this.client,
    required this.orders,
    required this.profile,
    required this.settings,
    required this.settingsService,
    required this.support,
    required this.socket,
    required this.locationTicker,
    this.mockOrders,
  });

  final ApiClient client;
  final OrdersRepository orders;
  final DriverProfileRepository profile;
  final SettingsRepository settings;
  final SettingsService settingsService;
  final SupportService support;
  final SocketService socket;
  final DriverLocationTicker locationTicker;
  final MockOrdersRepository? mockOrders;

  static AppServices? _instance;

  static AppServices get instance {
    final current = _instance;
    if (current == null) {
      throw StateError('AppServices not initialized');
    }
    return current;
  }

  static Future<AppServices> initialize({String? authToken}) async {
    final client = ApiClient();
    if (authToken != null) client.setAuthToken(authToken);

    final settingsRepo = MockSettingsRepository();
    var settings = await settingsRepo.load();
    if (settings.useMockApi || settings.serverUrl != ApiConfig.defaultBaseUrl) {
      settings = settings.copyWith(
        serverUrl: ApiConfig.defaultBaseUrl,
        useMockApi: false,
      );
      await settingsRepo.save(settings);
    }

    ApiConfig.setBaseUrl(settings.serverUrl);
    ApiConfig.setUseMock(settings.useMockApi);

    final ordersService = OrdersService(client);
    final profileService = DriverProfileService(client);
    final settingsService = SettingsService(client);
    final supportService = SupportService(client);
    final socket = SocketService();
    final locationTicker = DriverLocationTicker(socket);

    MockOrdersRepository? mockOrders;
    final OrdersRepository ordersRepo;
    final DriverProfileRepository profileRepo;
    final SettingsRepository settingsRepository;

    if (settings.useMockApi) {
      mockOrders = MockOrdersRepository();
      ordersRepo = mockOrders;
      profileRepo = MockDriverProfileRepository();
      settingsRepository = settingsRepo;
    } else {
      ordersRepo = ApiOrdersRepository(ordersService, socket);
      profileRepo = ApiDriverProfileRepository(profileService);
      settingsRepository = ApiSettingsRepository(settingsService, socket);
      if (authToken != null && authToken.trim().isNotEmpty) {
        socket.connect(token: authToken);
      }
    }

    _instance = AppServices._(
      client: client,
      orders: ordersRepo,
      profile: profileRepo,
      settings: settingsRepository,
      settingsService: settingsService,
      support: supportService,
      socket: socket,
      locationTicker: locationTicker,
      mockOrders: mockOrders,
    );
    return _instance!;
  }

  void connectSocket(String token) {
    if (ApiConfig.useMock) return;
    client.setAuthToken(token);
    socket.connect(token: token);
  }

  void disconnectSocket() {
    locationTicker.stop();
    socket.disconnect();
  }

  static void reset() {
    _instance?.locationTicker.dispose();
    _instance?.socket.dispose();
    _instance?.client.dispose();
    _instance = null;
  }
}
