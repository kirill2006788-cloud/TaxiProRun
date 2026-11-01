import '../models/tariff.dart';

/// Tabs for the Go-style tariff picker.
enum TariffTab { all, taxi, delivery }

extension TariffTabX on TariffTab {
  String get label => switch (this) {
        TariffTab.all => 'Все',
        TariffTab.taxi => 'Такси',
        TariffTab.delivery => 'Доставка',
      };
}

abstract final class TariffGroups {
  static const taxiIds = {
    'economy',
    'standard',
    'comfort',
    'comfort_plus',
    'compact_van',
    'minivan',
    'bus',
  };

  static const deliveryIds = {'gazelle'};

  static List<Tariff> filter(List<Tariff> tariffs, TariffTab tab) {
    return switch (tab) {
      TariffTab.all => List<Tariff>.from(tariffs),
      TariffTab.taxi =>
        tariffs.where((t) => taxiIds.contains(t.id)).toList(growable: false),
      TariffTab.delivery => tariffs
          .where((t) => deliveryIds.contains(t.id))
          .toList(growable: false),
    };
  }
}
