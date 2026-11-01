import '../geo/geo_math.dart';
import '../../models/booking.dart';
import '../../models/tariff.dart';

/// City road distance ≈ straight-line × factor (2048 / TaxiPro scheme).
const double kRoadDistanceFactor = 1.35;

/// Pickup fee = [kPickupKm] × client rate (₽/км).
const double kPickupKm = 3;

/// Fallback distance when coordinates are unknown.
const double kDefaultQuoteDistanceKm = kFallbackRouteDistanceKm;

/// Option surcharges (₽).
const double kKidsSurchargeRub = 80;
const double kPetsSurchargeRub = 100;
const double kAirConditioningSurchargeRub = 50;

/// Stop surcharge = 5% of distance fare per stop.
const double kStopSurchargeFactor = 0.05;

/// Infer driver ₽/km from client rate using Стандарт ratio (33/43).
double inferDriverRatePerKm(double clientRatePerKm) {
  return (clientRatePerKm * 33 / 43).roundToDouble();
}

class FareQuoteInput {
  const FareQuoteInput({
    required this.clientRatePerKm,
    required this.distanceKm,
    this.stopsCount = 0,
    this.withKids = false,
    this.withPets = false,
    this.airConditioning = false,
    this.discountPercent = 0,
  });

  final double clientRatePerKm;
  final double distanceKm;
  final int stopsCount;
  final bool withKids;
  final bool withPets;
  final bool airConditioning;
  final int discountPercent;
}

class FareQuote {
  const FareQuote({
    required this.base,
    required this.distance,
    required this.options,
    required this.discount,
    required this.total,
    required this.distanceKm,
    this.discountPercent = 0,
  });

  final double base;
  final double distance;
  final double options;
  final double discount;
  final double total;
  final double distanceKm;
  final int discountPercent;
}

abstract final class FareCalculator {
  /// Road distance in km from coordinates (haversine × [kRoadDistanceFactor]).
  static double distanceKmFromCoords({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) {
    return roadDistanceKm(fromLat, fromLng, toLat, toLng).clamp(1.0, 500.0);
  }

  static double distanceKmForBooking(Booking booking) {
    final stored = booking.routeDistanceKm;
    if (stored != null && stored > 0) {
      return stored.clamp(0.1, 500.0);
    }
    if (booking.hasRouteCoords) {
      return distanceKmFromCoords(
        fromLat: booking.fromLat!,
        fromLng: booking.fromLng!,
        toLat: booking.toLat!,
        toLng: booking.toLng!,
      );
    }
    return kDefaultQuoteDistanceKm;
  }

  static FareQuoteInput inputFromBooking(
    Booking booking, {
    int discountPercent = 0,
  }) {
    final rate = booking.selectedTariff?.clientRatePerKm ?? 0;
    return FareQuoteInput(
      clientRatePerKm: rate,
      distanceKm: distanceKmForBooking(booking),
      stopsCount: booking.stops.length,
      withKids: booking.withKids,
      withPets: booking.withPets,
      airConditioning: booking.airConditioning,
      discountPercent: discountPercent,
    );
  }

  static FareQuote compute(FareQuoteInput input) {
    final rate = input.clientRatePerKm;
    final km = input.distanceKm.clamp(0.1, 500.0);
    final base = (rate * kPickupKm).roundToDouble();
    final distance = (rate * km).roundToDouble();
    var options = input.stopsCount * (rate * km * kStopSurchargeFactor);
    if (input.withKids) options += kKidsSurchargeRub;
    if (input.withPets) options += kPetsSurchargeRub;
    if (input.airConditioning) options += kAirConditioningSurchargeRub;
    options = options.roundToDouble();

    final gross = base + distance + options;
    final pct = input.discountPercent.clamp(0, 100);
    final discount = pct > 0 ? gross * pct / 100 : 0.0;
    final total =
        (gross - discount).clamp(0, double.infinity).roundToDouble();
    final discountRounded = total < gross ? (gross - total).roundToDouble() : 0.0;

    return FareQuote(
      base: base,
      distance: distance,
      options: options,
      discount: discountRounded,
      total: total,
      distanceKm: km,
      discountPercent: pct,
    );
  }

  static FareQuote fromBooking(
    Booking booking, {
    int discountPercent = 0,
  }) {
    return compute(
      inputFromBooking(booking, discountPercent: discountPercent),
    );
  }

  static FareQuote fromTariff({
    required Tariff tariff,
    required double distanceKm,
    int stopsCount = 0,
    bool withKids = false,
    bool withPets = false,
    bool airConditioning = false,
    int discountPercent = 0,
  }) {
    return compute(
      FareQuoteInput(
        clientRatePerKm: tariff.clientRatePerKm,
        distanceKm: distanceKm,
        stopsCount: stopsCount,
        withKids: withKids,
        withPets: withPets,
        airConditioning: airConditioning,
        discountPercent: discountPercent,
      ),
    );
  }
}
