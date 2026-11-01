class Tariff {
  const Tariff({
    required this.id,
    required this.name,
    this.driverRatePerKm,
    required this.clientRatePerKm,
    this.maxPassengers,
    this.maxBags,
    required this.icon,
    this.description,
    this.isSoberDriver = false,
  });

  final String id;
  final String name;
  final double? driverRatePerKm;
  final double clientRatePerKm;
  final int? maxPassengers;
  final int? maxBags;
  final String icon;
  final String? description;
  final bool isSoberDriver;

  String get clientRateLabel => '${clientRatePerKm.toStringAsFixed(0)} ₽/км';

  String? get driverRateLabel => driverRatePerKm != null
      ? '${driverRatePerKm!.toStringAsFixed(0)} ₽/км'
      : null;

  String? get capacityLabel {
    final parts = <String>[];
    if (maxPassengers != null) parts.add('$maxPassengers пасс.');
    if (maxBags != null) parts.add('$maxBags баг.');
    return parts.isEmpty ? null : parts.join(' · ');
  }
}
