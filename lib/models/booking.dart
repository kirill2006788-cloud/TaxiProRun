import '../../features/map/map_geo.dart';
import 'payment_method.dart';
import 'service_type.dart';
import 'tariff.dart';

class Booking {
  const Booking({
    this.serviceType = ServiceType.taxi,
    this.fromAddress = '',
    this.toAddress = '',
    this.fromLat,
    this.fromLng,
    this.toLat,
    this.toLng,
    this.stops = const [],
    this.date,
    this.withKids = false,
    this.withPets = false,
    this.airConditioning = false,
    this.smokingAllowed = false,
    this.comment = '',
    this.entrance = '',
    this.selectedVehicleId,
    this.clientVehicleDescription,
    this.selectedTariff,
    this.paymentMethod = PaymentMethod.cash,
    this.estimatedPrice,
    this.promoCode = '',
    this.discountPercent = 0,
    this.orderId,
    this.isSubmitting = false,
    this.submitError,
    this.routeDistanceKm,
    this.routeDurationSec,
    this.routePoints = const [],
    this.routeSource,
  });

  final ServiceType serviceType;

  final String fromAddress;
  final String toAddress;
  final double? fromLat;
  final double? fromLng;
  final double? toLat;
  final double? toLng;
  final List<String> stops;
  final DateTime? date;
  final bool withKids;
  final bool withPets;
  final bool airConditioning;
  final bool smokingAllowed;
  final String comment;
  /// Подъезд / ориентир у точки подачи.
  final String entrance;
  final String? selectedVehicleId;
  final String? clientVehicleDescription;
  final Tariff? selectedTariff;
  final PaymentMethod paymentMethod;
  final double? estimatedPrice;
  final String promoCode;
  final int discountPercent;
  final String? orderId;
  final bool isSubmitting;
  final String? submitError;

  /// Км по Яндекс Router/Matrix или fallback.
  final double? routeDistanceKm;
  final int? routeDurationSec;
  final List<MapPoint> routePoints;
  final String? routeSource;

  Booking copyWith({
    ServiceType? serviceType,
    String? fromAddress,
    String? toAddress,
    double? fromLat,
    double? fromLng,
    double? toLat,
    double? toLng,
    List<String>? stops,
    DateTime? date,
    bool? withKids,
    bool? withPets,
    bool? airConditioning,
    bool? smokingAllowed,
    String? comment,
    String? entrance,
    String? selectedVehicleId,
    String? clientVehicleDescription,
    Tariff? selectedTariff,
    PaymentMethod? paymentMethod,
    double? estimatedPrice,
    String? promoCode,
    int? discountPercent,
    String? orderId,
    bool? isSubmitting,
    String? submitError,
    double? routeDistanceKm,
    int? routeDurationSec,
    List<MapPoint>? routePoints,
    String? routeSource,
    bool clearDate = false,
    bool clearTariff = false,
    bool clearPrice = false,
    bool clearOrderId = false,
    bool clearSubmitError = false,
    bool clearFromCoords = false,
    bool clearToCoords = false,
    bool clearRoute = false,
    bool clearVehicle = false,
  }) {
    return Booking(
      serviceType: serviceType ?? this.serviceType,
      fromAddress: fromAddress ?? this.fromAddress,
      toAddress: toAddress ?? this.toAddress,
      fromLat: clearFromCoords ? null : (fromLat ?? this.fromLat),
      fromLng: clearFromCoords ? null : (fromLng ?? this.fromLng),
      toLat: clearToCoords ? null : (toLat ?? this.toLat),
      toLng: clearToCoords ? null : (toLng ?? this.toLng),
      stops: stops ?? this.stops,
      date: clearDate ? null : (date ?? this.date),
      withKids: withKids ?? this.withKids,
      withPets: withPets ?? this.withPets,
      airConditioning: airConditioning ?? this.airConditioning,
      smokingAllowed: smokingAllowed ?? this.smokingAllowed,
      comment: comment ?? this.comment,
      entrance: entrance ?? this.entrance,
      selectedVehicleId:
          clearVehicle ? null : (selectedVehicleId ?? this.selectedVehicleId),
      clientVehicleDescription: clearVehicle
          ? null
          : (clientVehicleDescription ?? this.clientVehicleDescription),
      selectedTariff:
          clearTariff ? null : (selectedTariff ?? this.selectedTariff),
      paymentMethod: paymentMethod ?? this.paymentMethod,
      estimatedPrice:
          clearPrice ? null : (estimatedPrice ?? this.estimatedPrice),
      promoCode: promoCode ?? this.promoCode,
      discountPercent: discountPercent ?? this.discountPercent,
      orderId: clearOrderId ? null : (orderId ?? this.orderId),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitError: clearSubmitError ? null : (submitError ?? this.submitError),
      routeDistanceKm:
          clearRoute ? null : (routeDistanceKm ?? this.routeDistanceKm),
      routeDurationSec:
          clearRoute ? null : (routeDurationSec ?? this.routeDurationSec),
      routePoints: clearRoute ? const [] : (routePoints ?? this.routePoints),
      routeSource: clearRoute ? null : (routeSource ?? this.routeSource),
    );
  }

  bool get isSoberMode => serviceType.isSoberMode;

  bool get isRouteComplete => fromAddress.isNotEmpty && toAddress.isNotEmpty;

  bool get hasRouteCoords =>
      fromLat != null && fromLng != null && toLat != null && toLng != null;

  bool get isReadyToOrder {
    if (!isRouteComplete ||
        !hasRouteCoords ||
        selectedTariff == null ||
        estimatedPrice == null) {
      return false;
    }
    if (isSoberMode &&
        (clientVehicleDescription == null ||
            clientVehicleDescription!.trim().isEmpty)) {
      return false;
    }
    return true;
  }
}
