import '../models/tariff.dart';
/// Статический список тарифов «КОРОЛИ ДОРОГ».
abstract final class Tariffs {
  static const List<Tariff> all = [
    Tariff(
      id: 'economy',
      name: 'Эконом',
      driverRatePerKm: 28,
      clientRatePerKm: 37,
      maxPassengers: 2,
      maxBags: 2,
      icon: 'economy',
      description: 'Бюджетный класс для повседневных поездок',
    ),
    Tariff(
      id: 'standard',
      name: 'Стандарт',
      driverRatePerKm: 33,
      clientRatePerKm: 43,
      maxPassengers: 4,
      maxBags: 3,
      icon: 'standard',
      description: 'Комфортная поездка по городу',
    ),
    Tariff(
      id: 'compact_van',
      name: 'Компактвэн',
      driverRatePerKm: 42,
      clientRatePerKm: 55,
      maxPassengers: 6,
      maxBags: 4,
      icon: 'compact_van',
      description: 'Просторный автомобиль для компании',
    ),
    Tariff(
      id: 'minivan',
      name: 'Минивен',
      driverRatePerKm: 50,
      clientRatePerKm: 65,
      maxPassengers: 10,
      maxBags: 6,
      icon: 'minivan',
      description: '6–10 мест для групповых поездок',
    ),
    Tariff(
      id: 'bus',
      name: 'Автобус',
      driverRatePerKm: 138,
      clientRatePerKm: 180,
      maxPassengers: 20,
      icon: 'bus',
      description: 'До 20 пассажиров',
    ),
    Tariff(
      id: 'comfort',
      name: 'Комфорт',
      driverRatePerKm: 33,
      clientRatePerKm: 43,
      maxPassengers: 4,
      maxBags: 3,
      icon: 'comfort',
      description: 'Повышенный комфорт, как Стандарт',
    ),
    Tariff(
      id: 'comfort_plus',
      name: 'Комфорт+',
      driverRatePerKm: 36,
      clientRatePerKm: 47,
      maxPassengers: 4,
      maxBags: 3,
      icon: 'comfort_plus',
      description: 'Премиальный комфорт',
    ),
    Tariff(
      id: 'gazelle',
      name: 'Газель',
      driverRatePerKm: 77,
      clientRatePerKm: 100,
      icon: 'gazelle',
      description: 'Грузопассажирские перевозки',
    ),
    Tariff(
      id: 'sober_driver',
      name: 'Трезвый водитель',
      driverRatePerKm: 92,
      clientRatePerKm: 120,
      icon: 'sober_driver',
      description: 'Водитель за рулём вашего автомобиля',
      isSoberDriver: true,
    ),
  ];

  static Tariff? byId(String id) {
    for (final tariff in all) {
      if (tariff.id == id) return tariff;
    }
    return null;
  }
}
