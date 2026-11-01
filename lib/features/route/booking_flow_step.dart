/// Steps of the Yandex Go–style booking flow on the home map.
enum BookingFlowStep {
  /// Map pin = pickup; compact «Куда едем?» sheet.
  pickup,

  /// Full search UI for from / to + recent / favorites.
  destinationSearch,

  /// Map pin = destination; confirm sheet.
  destinationMap,

  /// Tariff tabs + order footer.
  tariffs,
}
