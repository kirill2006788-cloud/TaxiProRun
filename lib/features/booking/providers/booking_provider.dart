import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/models/api_models.dart';
import '../../../core/api/services/api_services.dart';
import '../../../core/geo/geo_math.dart';
import '../../../core/geo/yandex_routing_service.dart';
import '../../../core/pricing/fare_calculator.dart';
import '../../../core/session/active_order_store.dart';
import '../../../data/tariffs.dart';
import '../../../models/booking.dart';
import '../../../models/payment_method.dart';
import '../../../models/service_type.dart';
import '../../../models/tariff.dart';
import '../../profile/providers/settings_provider.dart';
import '../../route/booking_flow_step.dart';

/// Fallback distance when coords unknown (legacy). Prefer [BookingProvider.routeDistanceKm].
@Deprecated('Use Booking.routeDistanceKm / BookingProvider.routeDistanceKm')
const mockRouteDistanceKm = kFallbackRouteDistanceKm;

enum TariffsLoadState { idle, loading, loaded, error }

class BookingProvider extends ChangeNotifier {
  BookingProvider({
    ApiServices? apiServices,
    SettingsProvider? settingsProvider,
    YandexRoutingService? routingService,
  })  : _api = apiServices ?? ApiServices(),
        _settings = settingsProvider,
        _routing = routingService ?? YandexRoutingService(),
        _ownsRouting = routingService == null;

  final ApiServices _api;
  SettingsProvider? _settings;
  final YandexRoutingService _routing;
  final bool _ownsRouting;

  Timer? _routeDebounce;
  Timer? _quoteDebounce;
  int _routeRequestId = 0;
  int _quoteRequestId = 0;
  bool _priceFromServer = false;
  bool _priceQuoteLoading = false;
  String? _priceQuoteError;

  /// Shared API facade (mock/real) used by booking + active trip.
  ApiServices get apiServices => _api;

  Booking _booking = const Booking(
    fromAddress: '',
    toAddress: '',
  );

  TariffsLoadState _tariffsState = TariffsLoadState.idle;
  String? _tariffsError;
  List<Tariff> _remoteTariffs = const [];
  BookingFlowStep _flowStep = BookingFlowStep.pickup;

  Booking get booking => _booking;
  TariffsLoadState get tariffsState => _tariffsState;
  String? get tariffsError => _tariffsError;
  bool get priceFromServer => _priceFromServer;
  bool get priceQuoteLoading => _priceQuoteLoading;
  String? get priceQuoteError => _priceQuoteError;
  bool get canUseCurrentPrice =>
      ApiConfigStore.instance.useMockApi ||
      _settings?.demoTripEnabled == true ||
      _priceFromServer;
  BookingFlowStep get flowStep => _flowStep;

  void setFlowStep(BookingFlowStep step) {
    if (_flowStep == step) return;
    _flowStep = step;
    notifyListeners();
  }

  /// Local estimate for any tariff on the current route (instant Go prices).
  double? estimateForTariff(Tariff tariff) {
    if (!_booking.isRouteComplete) return null;
    final quote = FareCalculator.fromBooking(
      _booking.copyWith(selectedTariff: tariff),
      discountPercent: _booking.discountPercent,
    );
    return quote.total;
  }

  List<Tariff> get availableTariffs {
    if (_remoteTariffs.isNotEmpty) return _remoteTariffs;
    if (!ApiConfigStore.instance.useMockApi) return const [];
    return _booking.serviceType.isSoberMode
        ? Tariffs.all
            .where((t) => t.isSoberDriver || t.id == 'comfort')
            .toList()
        : Tariffs.all.where((t) => !t.isSoberDriver).toList();
  }

  void bindSettings(SettingsProvider settings) {
    _settings = settings;
    applyDefaultSettings();
  }

  void applyDefaultSettings() {
    final settings = _settings;
    if (settings == null || !settings.loaded) return;

    _booking = _booking.copyWith(
      serviceType: settings.defaultServiceType,
      withKids: settings.defaultWithKids,
      withPets: settings.defaultWithPets,
    );

    if (settings.defaultServiceType.isSoberMode) {
      final sober = Tariffs.byId('sober_driver');
      if (sober != null) {
        _booking = _booking.copyWith(selectedTariff: sober);
      }
    } else {
      final standard = Tariffs.byId('standard');
      if (standard != null) {
        _booking = _booking.copyWith(selectedTariff: standard);
      }
    }

    _recalculatePrice();
    notifyListeners();
  }

  void setServiceType(ServiceType type) {
    _booking = _booking.copyWith(
      serviceType: type,
      clearTariff: true,
      clearPrice: true,
      clearVehicle: !type.isSoberMode,
    );

    if (type.isSoberMode) {
      final sober = Tariffs.byId('sober_driver');
      if (sober != null) _booking = _booking.copyWith(selectedTariff: sober);
    } else {
      final standard = Tariffs.byId('standard');
      if (standard != null) {
        _booking = _booking.copyWith(selectedTariff: standard);
      }
    }

    _remoteTariffs = const [];
    _tariffsState = TariffsLoadState.idle;
    _recalculatePrice();
    notifyListeners();
  }

  Future<void> loadTariffs() async {
    _tariffsState = TariffsLoadState.loading;
    _tariffsError = null;
    notifyListeners();

    try {
      final dtos =
          await _api.order.fetchTariffs(serviceType: _booking.serviceType);
      _remoteTariffs = dtos
          .map(
            (dto) => Tariff(
              id: dto.id,
              name: dto.name,
              clientRatePerKm: dto.clientRatePerKm,
              driverRatePerKm: dto.driverRatePerKm,
              maxPassengers: dto.maxPassengers,
              maxBags: dto.maxBags,
              icon: dto.icon ?? 'standard',
              description: dto.description,
              isSoberDriver: dto.isSoberDriver,
            ),
          )
          .toList();

      if (_remoteTariffs.isNotEmpty &&
          (_booking.selectedTariff == null ||
              !_remoteTariffs
                  .any((t) => t.id == _booking.selectedTariff!.id))) {
        _booking = _booking.copyWith(selectedTariff: _remoteTariffs.first);
        _recalculatePrice();
      }

      _tariffsState = TariffsLoadState.loaded;
    } on ApiException catch (e) {
      _tariffsState = TariffsLoadState.error;
      _tariffsError = e.message;
    } catch (_) {
      _tariffsState = TariffsLoadState.error;
      _tariffsError = 'Не удалось загрузить тарифы';
    }
    notifyListeners();
  }

  void selectVehicle(String? vehicleId, {String? vehicleDescription}) {
    _booking = _booking.copyWith(
      selectedVehicleId: vehicleId,
      clientVehicleDescription: vehicleDescription,
    );
    notifyListeners();
  }

  /// Restore booking + active order after cold start.
  void restoreFromOrder(OrderDto order) {
    _booking = _booking.copyWith(
      orderId: order.id,
      fromAddress: order.fromAddress ?? _booking.fromAddress,
      toAddress: order.toAddress ?? _booking.toAddress,
      serviceType: order.serviceType ?? _booking.serviceType,
      paymentMethod: order.paymentMethod ?? _booking.paymentMethod,
      estimatedPrice: order.displayPrice?.toDouble(),
      clearSubmitError: true,
    );
    _priceFromServer = order.displayPrice != null;
    notifyListeners();
  }

  Future<bool> submitOrder() async {
    if (!_booking.isReadyToOrder || _booking.isSubmitting) return false;

    _booking = _booking.copyWith(isSubmitting: true, clearSubmitError: true);
    notifyListeners();

    try {
      if (_settings?.demoTripEnabled == true) {
        final orderId = 'demo-${DateTime.now().millisecondsSinceEpoch}';
        final routePoints = _booking.routePoints.length >= 2
            ? _booking.routePoints
            : routePointsForBooking(
                fromLat: _booking.fromLat,
                fromLng: _booking.fromLng,
                toLat: _booking.toLat,
                toLng: _booking.toLng,
              );
        await ActiveOrderStore.save(orderId);
        _booking = _booking.copyWith(
          orderId: orderId,
          isSubmitting: false,
          routePoints: routePoints,
          routeDistanceKm: routeDistanceKm,
          routeDurationSec: _booking.routeDurationSec ?? 780,
          estimatedPrice: _booking.estimatedPrice,
        );
        _priceFromServer = false;
        notifyListeners();
        return true;
      }

      final request = CreateOrderRequest(
        requestId:
            '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}',
        fromAddress: _booking.fromAddress,
        toAddress: _booking.toAddress,
        fromLat: _booking.fromLat,
        fromLng: _booking.fromLng,
        toLat: _booking.toLat,
        toLng: _booking.toLng,
        serviceType: _booking.serviceType,
        wish: _buildWishString(),
        comment: _buildOrderComment(),
        routeDistanceMeters: (routeDistanceKm * 1000).round(),
        paymentMethod: _booking.paymentMethod,
        discountPercent:
            _booking.discountPercent > 0 ? _booking.discountPercent : null,
        scheduledAt: _booking.date,
        withKids: _booking.withKids,
        withPets: _booking.withPets,
        stops: _booking.stops,
        tariffId: _booking.selectedTariff?.id,
      );

      final order = await _api.order.createOrder(request);
      await ActiveOrderStore.save(order.id);
      _booking = _booking.copyWith(
        orderId: order.id,
        isSubmitting: false,
        estimatedPrice:
            order.displayPrice?.toDouble() ?? _booking.estimatedPrice,
      );
      if (order.displayPrice != null) _priceFromServer = true;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _booking = _booking.copyWith(
        isSubmitting: false,
        submitError: e.message,
      );
      notifyListeners();
      return false;
    } catch (_) {
      _booking = _booking.copyWith(
        isSubmitting: false,
        submitError: 'Не удалось создать заказ',
      );
      notifyListeners();
      return false;
    }
  }

  String _buildWishString() {
    final parts = <String>[];
    if (_booking.withKids) parts.add('с детьми');
    if (_booking.withPets) parts.add('с животными');
    if (_booking.airConditioning) parts.add('кондиционер');
    if (_booking.smokingAllowed) parts.add('курящий салон');
    return parts.join(', ');
  }

  String? _buildOrderComment() {
    final parts = <String>[];
    final entrance = _booking.entrance.trim();
    if (entrance.isNotEmpty) parts.add('Подъезд: $entrance');
    final userComment = _booking.comment.trim();
    if (userComment.isNotEmpty) parts.add(userComment);
    final vehicle = _booking.clientVehicleDescription?.trim();
    if (_booking.isSoberMode && vehicle != null && vehicle.isNotEmpty) {
      parts.add('Автомобиль клиента: $vehicle');
    }
    if (parts.isEmpty) return null;
    return parts.join('. ');
  }

  void updateFromAddress(String value) {
    _booking = _booking.copyWith(
      fromAddress: value,
      clearFromCoords: true,
      clearRoute: true,
    );
    _routeDebounce?.cancel();
    _recalculatePrice();
    notifyListeners();
  }

  void updateFromAddressWithCoords(
    String value, {
    required double lat,
    required double lng,
  }) {
    _booking = _booking.copyWith(
      fromAddress: value,
      fromLat: lat,
      fromLng: lng,
      clearRoute: true,
    );
    _recalculatePrice();
    notifyListeners();
    _scheduleRouteRefresh();
  }

  void updateToAddress(String value) {
    _booking = _booking.copyWith(
      toAddress: value,
      clearToCoords: true,
      clearRoute: true,
    );
    _routeDebounce?.cancel();
    _recalculatePrice();
    notifyListeners();
  }

  void updateToAddressWithCoords(
    String value, {
    required double lat,
    required double lng,
  }) {
    _booking = _booking.copyWith(
      toAddress: value,
      toLat: lat,
      toLng: lng,
      clearRoute: true,
    );
    _recalculatePrice();
    notifyListeners();
    _scheduleRouteRefresh();
  }

  void addStop() {
    final label = String.fromCharCode(67 + _booking.stops.length);
    final updated = [..._booking.stops, 'Остановка $label'];
    _booking = _booking.copyWith(stops: updated);
    _recalculatePrice();
    notifyListeners();
  }

  void updateStop(int index, String value) {
    final updated = List<String>.from(_booking.stops);
    if (index < 0 || index >= updated.length) return;
    updated[index] = value;
    _booking = _booking.copyWith(stops: updated);
    _recalculatePrice();
    notifyListeners();
  }

  void removeStop(int index) {
    final updated = List<String>.from(_booking.stops)..removeAt(index);
    _booking = _booking.copyWith(stops: updated);
    _recalculatePrice();
    notifyListeners();
  }

  void setDate(DateTime? date) {
    _booking = date == null
        ? _booking.copyWith(clearDate: true)
        : _booking.copyWith(date: date);
    notifyListeners();
  }

  void toggleWithKids(bool value) {
    _booking = _booking.copyWith(withKids: value);
    _recalculatePrice();
    notifyListeners();
  }

  void toggleWithPets(bool value) {
    _booking = _booking.copyWith(withPets: value);
    _recalculatePrice();
    notifyListeners();
  }

  void toggleAirConditioning(bool value) {
    _booking = _booking.copyWith(airConditioning: value);
    _recalculatePrice();
    notifyListeners();
  }

  void toggleSmokingAllowed(bool value) {
    _booking = _booking.copyWith(smokingAllowed: value);
    notifyListeners();
  }

  void updateComment(String value) {
    _booking = _booking.copyWith(comment: value);
    notifyListeners();
  }

  void updateEntrance(String value) {
    _booking = _booking.copyWith(entrance: value.trim());
    notifyListeners();
  }

  void selectTariff(Tariff tariff) {
    _booking = _booking.copyWith(selectedTariff: tariff);
    _recalculatePrice();
    notifyListeners();
  }

  void selectPaymentMethod(PaymentMethod method) {
    _booking = _booking.copyWith(paymentMethod: method);
    notifyListeners();
  }

  void applyPromo({required String code, required int discountPercent}) {
    _booking = _booking.copyWith(
      promoCode: code.trim().toUpperCase(),
      discountPercent: discountPercent.clamp(0, 100),
    );
    _recalculatePrice();
    notifyListeners();
  }

  void clearPromo() {
    _booking = _booking.copyWith(promoCode: '', discountPercent: 0);
    _recalculatePrice();
    notifyListeners();
  }

  /// Повтор заказа из истории — префилл маршрута и оплаты.
  void prefillFromTrip({
    required String fromAddress,
    required String toAddress,
    PaymentMethod? paymentMethod,
  }) {
    _booking = _booking.copyWith(
      fromAddress: fromAddress,
      toAddress: toAddress,
      paymentMethod: paymentMethod ?? PaymentMethod.cash,
      clearDate: true,
      clearOrderId: true,
      clearSubmitError: true,
      clearFromCoords: true,
      clearToCoords: true,
      clearRoute: true,
    );
    _routeDebounce?.cancel();
    _recalculatePrice();
    notifyListeners();
  }

  /// Estimated road distance in km: Yandex route if set, else haversine × 1.35.
  double get routeDistanceKm => FareCalculator.distanceKmForBooking(_booking);

  void _scheduleRouteRefresh() {
    _routeDebounce?.cancel();
    _routeRequestId++;
    if (!_booking.hasRouteCoords) return;
    _routeDebounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(_refreshYandexRoute());
    });
  }

  Future<void> _refreshYandexRoute() async {
    if (!_booking.hasRouteCoords) return;

    final requestId = ++_routeRequestId;
    final fromLat = _booking.fromLat!;
    final fromLng = _booking.fromLng!;
    final toLat = _booking.toLat!;
    final toLng = _booking.toLng!;

    try {
      final result = await _routing.resolveRoute(
        fromLat: fromLat,
        fromLng: fromLng,
        toLat: toLat,
        toLng: toLng,
      );
      if (requestId != _routeRequestId) return;

      _booking = _booking.copyWith(
        routeDistanceKm: result.distanceKm,
        routeDurationSec: result.durationSec,
        routePoints: result.points,
        routeSource: result.source,
      );
      _recalculatePrice();
      notifyListeners();
    } catch (e, st) {
      // Soft-fail: leave route unset → haversine via [routeDistanceKm].
      debugPrint('Yandex route refresh failed: $e\n$st');
      if (requestId != _routeRequestId) return;
      _recalculatePrice();
      notifyListeners();
    }
  }

  void _recalculatePrice() {
    _quoteDebounce?.cancel();
    _quoteRequestId++;
    _priceFromServer = false;
    final tariff = _booking.selectedTariff;
    if (tariff == null || !_booking.isRouteComplete) {
      _booking = _booking.copyWith(clearPrice: true);
      _priceFromServer = false;
      _priceQuoteLoading = false;
      _priceQuoteError = null;
      return;
    }

    _applyLocalPriceEstimate();
    _scheduleServerQuote();
  }

  void _applyLocalPriceEstimate() {
    final tariff = _booking.selectedTariff;
    if (tariff == null || !_booking.isRouteComplete) return;

    final quote = FareCalculator.fromBooking(
      _booking,
      discountPercent: _booking.discountPercent,
    );
    if (!_priceFromServer) {
      _booking = _booking.copyWith(estimatedPrice: quote.total);
    }
  }

  void _scheduleServerQuote() {
    _quoteDebounce?.cancel();
    if (ApiConfigStore.instance.useMockApi) return;
    _priceQuoteLoading = true;
    _priceQuoteError = null;
    _quoteDebounce = Timer(const Duration(milliseconds: 450), () {
      unawaited(_refreshServerQuote());
    });
  }

  Future<void> refreshPriceQuote() async {
    _quoteDebounce?.cancel();
    _priceQuoteLoading = true;
    _priceQuoteError = null;
    notifyListeners();
    await _refreshServerQuote();
  }

  Future<void> _refreshServerQuote() async {
    if (ApiConfigStore.instance.useMockApi) return;
    final tariff = _booking.selectedTariff;
    if (tariff == null || !_booking.isRouteComplete) return;

    final requestId = ++_quoteRequestId;
    try {
      final quote = await _api.order.fetchPriceQuote(
        PriceQuoteRequest(
          serviceType: _booking.serviceType,
          tariffId: tariff.id,
          fromLat: _booking.fromLat,
          fromLng: _booking.fromLng,
          toLat: _booking.toLat,
          toLng: _booking.toLng,
          routeDistanceMeters: (routeDistanceKm * 1000).round(),
          routeEtaSeconds: _booking.routeDurationSec,
          withKids: _booking.withKids,
          withPets: _booking.withPets,
          discountPercent:
              _booking.discountPercent > 0 ? _booking.discountPercent : null,
          scheduledAt: _booking.date,
          stopsCount: _booking.stops.length,
        ),
      );
      if (requestId != _quoteRequestId) return;
      if (quote != null && quote.priceFrom > 0) {
        _booking = _booking.copyWith(
          estimatedPrice: quote.priceFrom.toDouble(),
        );
        _priceFromServer = true;
        _priceQuoteError = null;
      } else {
        _priceFromServer = false;
        _priceQuoteError = 'Не удалось получить цену';
      }
      _priceQuoteLoading = false;
      notifyListeners();
    } catch (e, st) {
      debugPrint('Server price quote failed: $e\n$st');
      if (requestId != _quoteRequestId) return;
      _priceFromServer = false;
      _priceQuoteLoading = false;
      _priceQuoteError = 'Нет связи с сервером расчета';
      _applyLocalPriceEstimate();
      notifyListeners();
    }
  }

  void reset() {
    _routeDebounce?.cancel();
    _quoteDebounce?.cancel();
    _routeRequestId++;
    _quoteRequestId++;
    _priceFromServer = false;
    _priceQuoteLoading = false;
    _priceQuoteError = null;
    _flowStep = BookingFlowStep.pickup;
    unawaited(ActiveOrderStore.clear());
    final defaults = _settings;
    _booking = Booking(
      serviceType: defaults?.defaultServiceType ?? ServiceType.taxi,
      fromAddress: '',
      toAddress: '',
      withKids: defaults?.defaultWithKids ?? false,
      withPets: defaults?.defaultWithPets ?? false,
    );
    _remoteTariffs = const [];
    _tariffsState = TariffsLoadState.idle;
    _tariffsError = null;
    applyDefaultSettings();
    notifyListeners();
  }

  @override
  void dispose() {
    _routeDebounce?.cancel();
    _quoteDebounce?.cancel();
    _routeRequestId++;
    _quoteRequestId++;
    if (_ownsRouting) _routing.dispose();
    super.dispose();
  }
}
