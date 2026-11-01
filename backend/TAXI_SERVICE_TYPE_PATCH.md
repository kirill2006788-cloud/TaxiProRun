# Backend patches for TaxiPro taxi flow

## Files to apply on VPS `/opt/koroli-dorog-api`

1. Copy `api/src/taxi.controller.ts` into the NestJS `src/` folder.
2. Register `TaxiController` in `app.module.ts` controllers array.
3. Patch `orders.service.ts` for `serviceType: 'taxi'` (see below).
4. Rebuild: `npm run build && pm2 restart koroli-dorog-api` (or your process name).

## orders.service.ts — type changes

```ts
export type Order = {
  // ...existing...
  serviceIndex?: number;
  serviceType?: 'taxi' | string;
  tariffId?: string;
  // ...
};

export type CreateOrderInput = {
  // ...existing...
  serviceIndex?: number;
  serviceType?: 'taxi' | string;
  tariffId?: string;
  // ...
};
```

## orders.service.ts — pricing branch

In `computePrice`, at the start:

```ts
if (String(input.serviceType || '').toLowerCase() === 'taxi') {
  return this.computeTaxiPrice(input);
}
```

Add method:

```ts
private async computeTaxiPrice(input: CreateOrderInput) {
  let list: any[] = [];
  try {
    const raw = await this.redis.client.get('taxi_tariffs:list');
    if (raw) list = JSON.parse(raw);
  } catch {}
  if (!Array.isArray(list) || !list.length) {
    list = [
      { id: 'economy', name: 'Эконом', clientRatePerKm: 25, perKm: 25, base: 199 },
      { id: 'comfort', name: 'Комфорт', clientRatePerKm: 35, perKm: 35, base: 299 },
      { id: 'business', name: 'Бизнес', clientRatePerKm: 55, perKm: 55, base: 499 },
    ];
  }
  const tariff =
    list.find((t) => String(t.id) === String(input.tariffId || '')) || list[0];
  const distanceKm = Math.max(1, this.safeNum(input.routeDistanceMeters) / 1000);
  const rate = this.safeNum(tariff?.clientRatePerKm ?? tariff?.perKm, 25);
  const base = this.safeNum(tariff?.base, 0);
  const priceFrom = Math.max(150, Math.round(base + rate * distanceKm));
  return {
    priceFrom,
    tariffName: String(tariff?.name || 'Такси'),
    markupPercent: 0,
  };
}
```

In `createOrder` when building `order`:

```ts
serviceType: String(input.serviceType || '').toLowerCase() === 'taxi' ? 'taxi' : undefined,
serviceIndex:
  String(input.serviceType || '').toLowerCase() === 'taxi'
    ? undefined
    : Number.isFinite(Number(input.serviceIndex))
      ? Number(input.serviceIndex)
      : undefined,
tariffId: input.tariffId?.toString().trim() || undefined,
```

## app.module.ts

```ts
import { TaxiController } from './taxi.controller';
// controllers: [ ..., TaxiController ]
```

## Verify

```bash
curl -s http://127.0.0.1:3000/api/taxi/tariffs
# or whatever port /api prefix the app uses
```
