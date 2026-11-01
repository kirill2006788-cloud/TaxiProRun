import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:koroli_dorog/core/api/api_client.dart';
import 'package:koroli_dorog/core/api/models/api_models.dart';
import 'package:koroli_dorog/core/api/services/api_services.dart';
import 'package:koroli_dorog/core/geo/yandex_routing_service.dart';
import 'package:koroli_dorog/data/tariffs.dart';
import 'package:koroli_dorog/features/booking/providers/booking_provider.dart';
import 'package:koroli_dorog/models/payment_method.dart';
import 'package:koroli_dorog/models/service_type.dart';
import 'package:koroli_dorog/shared/widgets/fare_breakdown_sheet.dart';

import '../helpers/fake_order_repository.dart';

class _DelayedQuoteRepository extends FakeOrderRepository {
  final pending = Completer<PriceQuoteDto?>();

  @override
  Future<PriceQuoteDto?> fetchPriceQuote(PriceQuoteRequest request) =>
      pending.future;
}

class _NoOpRoutingService extends YandexRoutingService {
  _NoOpRoutingService() : super(httpClient: http.Client());

  @override
  Future<YandexRouteResult> resolveRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    return const YandexRouteResult(
      distanceKm: 15,
      durationSec: 1200,
      source: 'test',
    );
  }
}

BookingProvider _provider({FakeOrderRepository? repo}) {
  ApiConfigStore.instance.setUseMockApi(true);
  final orderRepo = repo ?? FakeOrderRepository();
  final api = ApiServices(orderRepository: orderRepo);
  final provider = BookingProvider(
    apiServices: api,
    routingService: _NoOpRoutingService(),
  );
  // Test fixture is explicit: production BookingProvider starts with empty
  // addresses and must never display demo route data to a real passenger.
  provider.updateFromAddress('Тестовая точка А');
  provider.updateToAddress('Тестовая точка Б');
  return provider;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('a stale quote cannot restore a price after the route is cleared',
      () async {
    final repo = _DelayedQuoteRepository();
    final provider = _provider(repo: repo);
    provider.selectTariff(Tariffs.byId('economy')!);
    ApiConfigStore.instance.setUseMockApi(false);
    final refresh = provider.refreshPriceQuote();
    provider.updateToAddress('');
    repo.pending.complete(const PriceQuoteDto(priceFrom: 9999));
    await refresh;
    expect(provider.booking.estimatedPrice, isNull);
    expect(provider.priceFromServer, false);
    provider.dispose();
  });

  test('a quote completing after disposal cannot notify the closed screen',
      () async {
    final repo = _DelayedQuoteRepository();
    final provider = _provider(repo: repo);
    provider.selectTariff(Tariffs.byId('economy')!);
    ApiConfigStore.instance.setUseMockApi(false);
    final refresh = provider.refreshPriceQuote();
    provider.dispose();
    repo.pending.complete(const PriceQuoteDto(priceFrom: 9999));
    await refresh;
  });

  group('BookingProvider price recalculation', () {
    late BookingProvider provider;

    setUp(() {
      provider = _provider();
      provider.selectTariff(Tariffs.byId('economy')!);
    });

    tearDown(() => provider.dispose());

    test('uses fallback distance when coords unknown', () {
      expect(provider.routeDistanceKm, 12);
      expect(provider.booking.estimatedPrice, isNotNull);
      expect(provider.booking.estimatedPrice, 555); // 37*3 + 37*12
    });

    test('recalculates when kids and pets toggled', () {
      final basePrice = provider.booking.estimatedPrice!;
      provider.toggleWithKids(true);
      provider.toggleWithPets(true);
      expect(provider.booking.estimatedPrice, basePrice + 180);
    });

    test('applies promo discount', () {
      provider.applyPromo(code: 'TEST10', discountPercent: 10);
      final price = provider.booking.estimatedPrice!;
      expect(price, lessThan(555));
      expect(price, 500); // 555 - 10% = 499.5 → 500
    });

    test('matches FareBreakdown for same booking', () {
      provider.updateFromAddressWithCoords(
        'Красная площадь',
        lat: 55.7558,
        lng: 37.6173,
      );
      provider.updateToAddressWithCoords(
        'Шереметьево',
        lat: 55.9736,
        lng: 37.4144,
      );

      final fare = FareBreakdown.fromBooking(provider.booking);
      expect(provider.booking.estimatedPrice, closeTo(fare.total, 1));
    });

    test('clears price when route incomplete', () {
      provider.updateFromAddress('');
      expect(provider.booking.estimatedPrice, isNull);
    });
  });

  group('BookingProvider loadTariffs (mock API)', () {
    test('loads remote tariffs and recalculates price', () async {
      final repo = FakeOrderRepository(
        tariffs: const [
          TariffDto(
            id: 'premium_test',
            name: 'Премиум тест',
            clientRatePerKm: 50,
          ),
        ],
      );
      final provider = _provider(repo: repo);
      provider.selectTariff(Tariffs.byId('economy')!);

      await provider.loadTariffs();

      expect(provider.tariffsState, TariffsLoadState.loaded);
      expect(provider.availableTariffs, hasLength(1));
      expect(provider.availableTariffs.first.id, 'premium_test');
      expect(provider.booking.selectedTariff?.clientRatePerKm, 50);
      expect(provider.booking.estimatedPrice, isNotNull);
      provider.dispose();
    });
  });

  group('BookingProvider submitOrder (mock API)', () {
    test('creates order via mock repository', () async {
      final repo = FakeOrderRepository();
      final provider = _provider(repo: repo);
      provider.selectTariff(Tariffs.byId('economy')!);
      provider.selectPaymentMethod(PaymentMethod.card);
      provider.updateFromAddressWithCoords(
        'Тестовая точка А',
        lat: 55.75,
        lng: 37.61,
      );
      provider.updateToAddressWithCoords(
        'Тестовая точка Б',
        lat: 55.82,
        lng: 37.70,
      );

      expect(provider.booking.isReadyToOrder, isTrue,
          reason: 'price=${provider.booking.estimatedPrice}');

      final ok = await provider.submitOrder();

      expect(ok, isTrue);
      expect(provider.booking.orderId, startsWith('test-order'));
      expect(provider.booking.isSubmitting, isFalse);
      expect(repo.lastCreateRequest?.paymentMethod, PaymentMethod.card);
      expect(repo.lastCreateRequest?.serviceType, ServiceType.taxi);
      provider.dispose();
    });
  });
}
