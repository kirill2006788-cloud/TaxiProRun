export type LatLng = { lat: number; lng: number };

export type TaxiTariff = {
  id: string;
  name: string;
  clientRatePerKm: number;
  driverRatePerKm?: number;
  perKm?: number;
  description?: string;
  maxPassengers?: number;
  maxBags?: number;
  icon?: string;
};

/** Kleo dispatcher tariffs — КОРОЛИ ДОРОГ (₽/km). */
export const DEFAULT_TAXI_TARIFFS: TaxiTariff[] = [
  {
    id: 'economy',
    name: 'Эконом',
    clientRatePerKm: 37,
    driverRatePerKm: 28,
    perKm: 37,
    description: 'Бюджетный класс для повседневных поездок',
    maxPassengers: 2,
    maxBags: 2,
    icon: 'economy',
  },
  {
    id: 'standard',
    name: 'Стандарт',
    clientRatePerKm: 43,
    driverRatePerKm: 33,
    perKm: 43,
    description: 'Комфортная поездка по городу',
    maxPassengers: 4,
    maxBags: 3,
    icon: 'standard',
  },
  {
    id: 'comfort',
    name: 'Комфорт',
    clientRatePerKm: 43,
    driverRatePerKm: 33,
    perKm: 43,
    description: 'Повышенный комфорт, как Стандарт',
    maxPassengers: 4,
    maxBags: 3,
    icon: 'comfort',
  },
  {
    id: 'compact_van',
    name: 'Компактвэн',
    clientRatePerKm: 55,
    driverRatePerKm: 42,
    perKm: 55,
    description: 'Просторный автомобиль для компании',
    maxPassengers: 6,
    maxBags: 4,
    icon: 'compact_van',
  },
  {
    id: 'minivan',
    name: 'Минивен',
    clientRatePerKm: 65,
    driverRatePerKm: 50,
    perKm: 65,
    description: '6–10 мест для групповых поездок',
    maxPassengers: 10,
    maxBags: 6,
    icon: 'minivan',
  },
  {
    id: 'bus',
    name: 'Автобус',
    clientRatePerKm: 180,
    driverRatePerKm: 138,
    perKm: 180,
    description: 'До 20 пассажиров',
    maxPassengers: 20,
    icon: 'bus',
  },
  {
    id: 'comfort_plus',
    name: 'Комфорт+',
    clientRatePerKm: 47,
    driverRatePerKm: 36,
    perKm: 47,
    description: 'Премиальный комфорт',
    maxPassengers: 4,
    maxBags: 3,
    icon: 'comfort_plus',
  },
  {
    id: 'gazelle',
    name: 'Газель',
    clientRatePerKm: 100,
    driverRatePerKm: 77,
    perKm: 100,
    description: 'Грузопассажирские перевозки',
    icon: 'gazelle',
  },
  {
    id: 'sober_driver',
    name: 'Трезвый водитель',
    clientRatePerKm: 120,
    driverRatePerKm: 92,
    perKm: 120,
    description: 'Водитель за рулём вашего автомобиля',
    icon: 'sober_driver',
  },
];

export const TAXI_PICKUP_KM = 3;
export const TAXI_ROAD_FACTOR = 1.35;
export const TAXI_FALLBACK_DISTANCE_KM = 12;

const KIDS_SURCHARGE = 80;
const PETS_SURCHARGE = 100;
const AC_SURCHARGE = 50;
const STOP_SURCHARGE_FACTOR = 0.05;

export function inferDriverRatePerKm(clientRatePerKm: number): number {
  return Math.round(clientRatePerKm * 33 / 43);
}

export function haversineKm(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  const earthRadiusKm = 6371.0;
  const dLat = ((lat2 - lat1) * Math.PI) / 180.0;
  const dLng = ((lng2 - lng1) * Math.PI) / 180.0;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180.0) *
      Math.cos((lat2 * Math.PI) / 180.0) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return earthRadiusKm * c;
}

export function roadDistanceKm(
  lat1: number,
  lng1: number,
  lat2: number,
  lng2: number,
): number {
  return haversineKm(lat1, lng1, lat2, lng2) * TAXI_ROAD_FACTOR;
}

export type TaxiFareInput = {
  clientRatePerKm: number;
  routeDistanceMeters?: number;
  from?: LatLng;
  to?: LatLng;
  stopsCount?: number;
  withKids?: boolean;
  withPets?: boolean;
  airConditioning?: boolean;
  discountPercent?: number;
};

export function resolveDistanceKm(input: {
  routeDistanceMeters?: number;
  from?: LatLng;
  to?: LatLng;
}): number {
  const meters = Number(input.routeDistanceMeters || 0);
  if (Number.isFinite(meters) && meters > 0) {
    return Math.max(1, meters / 1000);
  }
  const from = input.from;
  const to = input.to;
  if (
    from &&
    to &&
    Number.isFinite(from.lat) &&
    Number.isFinite(from.lng) &&
    Number.isFinite(to.lat) &&
    Number.isFinite(to.lng)
  ) {
    return Math.max(
      1,
      roadDistanceKm(from.lat, from.lng, to.lat, to.lng),
    );
  }
  return TAXI_FALLBACK_DISTANCE_KM;
}

export function computeTaxiFare(input: TaxiFareInput): {
  priceFrom: number;
  distanceKm: number;
  base: number;
  distance: number;
  options: number;
} {
  const rate = Math.max(0, Number(input.clientRatePerKm) || 0);
  const km = resolveDistanceKm(input);
  const base = Math.round(rate * TAXI_PICKUP_KM);
  const distance = Math.round(rate * km);
  let options = Math.max(0, Number(input.stopsCount) || 0) * rate * km * STOP_SURCHARGE_FACTOR;
  if (input.withKids) options += KIDS_SURCHARGE;
  if (input.withPets) options += PETS_SURCHARGE;
  if (input.airConditioning) options += AC_SURCHARGE;
  options = Math.round(options);

  const gross = base + distance + options;
  const pct = Math.max(0, Math.min(100, Number(input.discountPercent) || 0));
  const priceFrom = Math.round(gross * (1 - pct / 100));

  return {
    priceFrom: Math.max(0, priceFrom),
    distanceKm: km,
    base,
    distance,
    options,
  };
}

export function computeTaxiQuote(
  tariff: TaxiTariff,
  input: Omit<TaxiFareInput, 'clientRatePerKm'>,
): {
  priceFrom: number;
  tariffName: string;
  distanceKm: number;
} {
  const rate = Number(tariff.clientRatePerKm ?? tariff.perKm ?? 37);
  const fare = computeTaxiFare({ ...input, clientRatePerKm: rate });
  return {
    priceFrom: fare.priceFrom,
    tariffName: String(tariff.name || 'Такси'),
    distanceKm: fare.distanceKm,
  };
}
