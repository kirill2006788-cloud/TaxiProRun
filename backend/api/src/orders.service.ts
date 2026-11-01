import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { RedisService } from './redis.service';
import { DriversService } from './drivers.service';
import {
  DEFAULT_TAXI_TARIFFS,
  computeTaxiQuote,
  type TaxiTariff,
} from './pricing/taxi-pricing';
import {
  ACTIVE_TRIP_STATUSES,
  CLIENT_ACTIVE_STATUSES,
  ORDER_STATUS_TRANSITIONS,
  assertOrderStatusTransition,
  assertPaymentStatusTransition,
  normalizeOrderStatus,
  normalizePaymentStatus,
  type OrderStatus,
  type OrderStatusActor,
  type PaymentStatus,
} from './order-status';
import crypto from 'crypto';

export type { OrderStatus, OrderStatusActor, PaymentStatus };
export { ORDER_STATUS_TRANSITIONS };

export type OrderStatusHistoryEntry = {
  from: OrderStatus;
  to: OrderStatus;
  at: string;
  actor: OrderStatusActor;
  actorId?: string;
  reason?: string;
};

export type OrderChatMessage = {
  id: string;
  orderId: string;
  senderRole: 'client' | 'driver';
  senderId: string;
  text: string;
  createdAt: string;
};

export type LatLng = {
  lat: number;
  lng: number;
};

export type Order = {
  id: string;
  clientId: string;
  from: LatLng;
  to: LatLng;
  fromAddress?: string;
  toAddress?: string;
  comment?: string;
  wish?: string;
  serviceIndex?: number;
  serviceType?: 'taxi' | string;
  tariffId?: string;
  priceFrom?: number;
  priceBeforeDiscount?: number;
  priceFinal?: number;
  promoDiscountPercent?: number;
  bonusUsed?: number;
  tripMinutes?: number;
  tariffName?: string;
  paymentMethod?: 'card' | 'sbp' | 'cash';
  paymentStatus?: PaymentStatus;
  cancelReason?: string;
  canceledBy?: 'client' | 'driver' | 'admin' | 'system';
  waitingAt?: string;
  commissionPercent?: number;
  commissionAmount?: number;
  markupPercentApplied?: number;
  rating?: number;
  ratedAt?: string;
  routeDistanceMeters?: number;
  routeEtaSeconds?: number;
  kmOutsideMkad?: number;
  kmFromAToRing?: number;
  scheduledAt?: string;
  status: OrderStatus;
  driverPhone?: string;
  acceptedAt?: string;
  arrivedAt?: string;
  startedAt?: string;
  completedAt?: string;
  createdAt: string;
};

export type CreateOrderInput = {
  clientId: string;
  requestId?: string;
  from: LatLng;
  to: LatLng;
  fromAddress?: string;
  toAddress?: string;
  comment?: string;
  wish?: string;
  serviceIndex?: number;
  serviceType?: 'taxi' | string;
  tariffId?: string;
  routeDistanceMeters?: number;
  routeEtaSeconds?: number;
  kmOutsideMkad?: number;
  kmFromAToRing?: number;
  paymentMethod?: 'card' | 'sbp' | 'cash';
  scheduledAt?: string;
  discountPercent?: number;
  bonusAmount?: number;
  withKids?: boolean;
  withPets?: boolean;
  airConditioning?: boolean;
  stopsCount?: number;
  stops?: string[];
};

export type QuoteOrderInput = Omit<CreateOrderInput, 'clientId' | 'requestId' | 'bonusAmount'>;

function isFiniteNumber(v: unknown): v is number {
  return typeof v === 'number' && Number.isFinite(v);
}

function validatePoint(p: unknown, name: string): asserts p is LatLng {
  if (typeof p !== 'object' || p === null) {
    throw new BadRequestException(`${name} is required`);
  }
  const anyP = p as any;
  if (!isFiniteNumber(anyP.lat) || !isFiniteNumber(anyP.lng)) {
    throw new BadRequestException(`${name}.lat and ${name}.lng must be numbers`);
  }
  if (anyP.lat < -90 || anyP.lat > 90 || anyP.lng < -180 || anyP.lng > 180) {
    throw new BadRequestException(`${name} coordinates are out of range`);
  }
}

@Injectable()
export class OrdersService {
  constructor(
    private readonly redis: RedisService,
    private readonly drivers: DriversService,
  ) {}

  private static readonly center = { lat: 55.755864, lng: 37.617698 };
  private static readonly mkadRadiusKm = 17.0;
  private static readonly mkadToleranceKm = 2.5;
  private static readonly ckadRadiusKm = 50.0;
  private static readonly regionalBaseRub = 3300;

  private isOutsideMkadPoint(p: LatLng) {
    return (
      this.distanceKm(p, OrdersService.center) >
      OrdersService.mkadRadiusKm + OrdersService.mkadToleranceKm
    );
  }

  private isRegionalTrip(from: LatLng, to: LatLng) {
    return this.isOutsideMkadPoint(from) && this.isOutsideMkadPoint(to);
  }

  /** Км от A до ЦКАД (50 км от центра Москвы). */
  private computeKmFromAToRing(p: LatLng) {
    return Math.max(
      0,
      this.distanceKm(p, OrdersService.center) - OrdersService.ckadRadiusKm,
    );
  }

  private computeRegionalPrice(
    minutes: number,
    kmFromAToRing: number,
    routeDistanceMeters?: number,
  ) {
    const includedMin = 60;
    const extraMin = Math.max(0, minutes - includedMin);
    const kmAToB = Math.max(0, Number(routeDistanceMeters || 0) / 1000);
    const kmBillable = Math.max(0, Number(kmFromAToRing || 0)) + kmAToB;
    return OrdersService.regionalBaseRub + extraMin * 25 + this.kmFee(kmBillable);
  }

  private orderKey(orderId: string) {
    return `order:${orderId}`;
  }

  private acceptLockKey(orderId: string) {
    return `order:accept_lock:${orderId}`;
  }

  private orderLockKey(orderId: string) {
    return `order:lock:${orderId}`;
  }

  private orderRequestKey(clientId: string, requestId: string) {
    return `order:req:${clientId}:${requestId}`;
  }

  private orderRequestLockKey(clientId: string, requestId: string) {
    return `order:req_lock:${clientId}:${requestId}`;
  }

  private orderRequestPayloadKey(clientId: string, requestId: string) {
    return `order:req_payload:${clientId}:${requestId}`;
  }

  private orderStatusHistoryKey(orderId: string) {
    return `order:status_history:${orderId}`;
  }

  private orderChatKey(orderId: string) {
    return `order:chat:${orderId}`;
  }

  /** Активные статусы, в которых доступен чат поездки. */
  private static readonly CHAT_ACTIVE_STATUSES = ACTIVE_TRIP_STATUSES;

  private static readonly STATUS_HISTORY_TTL_SEC = 60 * 60 * 24 * 30;
  private static readonly CHAT_TTL_ACTIVE_SEC = 60 * 60 * 48;
  private static readonly CHAT_TTL_AFTER_TRIP_SEC = 60 * 60 * 24 * 7;
  private static readonly ORDER_REQUEST_TTL_SEC = 60 * 60 * 24;

  assertStatusTransition(
    from: OrderStatus,
    to: OrderStatus,
    actor: OrderStatusActor = 'system',
  ): void {
    assertOrderStatusTransition(from, to, actor);
  }

  /** Normalize client/driver aliases (TZ names) → wire status; reject unknowns. */
  parseStatusInput(raw: string): OrderStatus {
    const normalized = normalizeOrderStatus(raw);
    if (!normalized) {
      throw new BadRequestException(`Unknown order status: ${raw}`);
    }
    return normalized;
  }

  private hashCreatePayload(input: CreateOrderInput): string {
    const payload = {
      from: input.from,
      to: input.to,
      serviceIndex: input.serviceIndex,
      serviceType: input.serviceType,
      tariffId: input.tariffId,
      routeDistanceMeters: input.routeDistanceMeters,
      routeEtaSeconds: input.routeEtaSeconds,
      scheduledAt: input.scheduledAt,
    };
    return crypto.createHash('sha256').update(JSON.stringify(payload)).digest('hex').slice(0, 32);
  }

  async appendStatusHistory(
    orderId: string,
    from: OrderStatus,
    to: OrderStatus,
    actor: OrderStatusActor,
    meta?: { actorId?: string; reason?: string },
  ): Promise<void> {
    if (from === to) return;
    try {
      const entry: OrderStatusHistoryEntry = {
        from,
        to,
        at: new Date().toISOString(),
        actor,
        actorId: meta?.actorId,
        reason: meta?.reason,
      };
      const key = this.orderStatusHistoryKey(orderId);
      const multi = this.redis.client.multi();
      multi.lpush(key, JSON.stringify(entry));
      multi.ltrim(key, 0, 99);
      multi.expire(key, OrdersService.STATUS_HISTORY_TTL_SEC);
      await multi.exec();
    } catch {
      // История статусов — best-effort, не блокирует основной поток.
    }
  }

  async listStatusHistory(orderId: string, limit = 50): Promise<OrderStatusHistoryEntry[]> {
    const safeLimit = Math.min(100, Math.max(1, Math.floor(Number(limit) || 50)));
    const raw = await this.redis.client.lrange(this.orderStatusHistoryKey(orderId), 0, safeLimit - 1);
    const entries: OrderStatusHistoryEntry[] = [];
    for (const line of raw || []) {
      if (typeof line !== 'string') continue;
      try {
        entries.push(JSON.parse(line) as OrderStatusHistoryEntry);
      } catch {
        // skip corrupted
      }
    }
    return entries;
  }

  private assertChatAllowed(order: Order): void {
    if (!OrdersService.CHAT_ACTIVE_STATUSES.has(order.status)) {
      throw new ConflictException('Chat is only available during an active trip');
    }
  }

  async addChatMessage(input: {
    orderId: string;
    senderRole: 'client' | 'driver';
    senderId: string;
    text: string;
  }): Promise<OrderChatMessage> {
    const orderId = (input.orderId || '').trim();
    const senderId = (input.senderId || '').trim();
    const text = (input.text || '').toString().trim().slice(0, 2000);
    if (!orderId) throw new BadRequestException('orderId is required');
    if (!senderId) throw new BadRequestException('senderId is required');
    if (!text) throw new BadRequestException('text is required');

    const order = await this.getOrder(orderId);
    this.assertChatAllowed(order);

    if (input.senderRole === 'client') {
      if (order.clientId !== senderId) throw new BadRequestException('Client mismatch');
    } else if (input.senderRole === 'driver') {
      if (!order.driverPhone || order.driverPhone !== senderId) {
        throw new BadRequestException('Driver mismatch');
      }
    } else {
      throw new BadRequestException('Invalid sender role');
    }

    const message: OrderChatMessage = {
      id: crypto.randomUUID(),
      orderId,
      senderRole: input.senderRole,
      senderId,
      text,
      createdAt: new Date().toISOString(),
    };
    const key = this.orderChatKey(orderId);
    const multi = this.redis.client.multi();
    multi.lpush(key, JSON.stringify(message));
    multi.ltrim(key, 0, 199);
    multi.expire(key, OrdersService.CHAT_TTL_ACTIVE_SEC);
    await multi.exec();
    return message;
  }

  async listChatMessages(orderId: string, limit = 50): Promise<OrderChatMessage[]> {
    const safeLimit = Math.min(100, Math.max(1, Math.floor(Number(limit) || 50)));
    const raw = await this.redis.client.lrange(this.orderChatKey(orderId), 0, safeLimit - 1);
    const messages: OrderChatMessage[] = [];
    for (const line of raw || []) {
      if (typeof line !== 'string') continue;
      try {
        messages.push(JSON.parse(line) as OrderChatMessage);
      } catch {
        // skip
      }
    }
    return messages.reverse();
  }

  async quoteOrder(input: QuoteOrderInput) {
    validatePoint(input.from, 'from');
    validatePoint(input.to, 'to');
    const { priceFrom, tariffName, markupPercent } = await this.computePrice({
      ...input,
      clientId: '',
    });
    return {
      priceFrom,
      tariffName: tariffName || undefined,
      markupPercentApplied: markupPercent,
      routeDistanceMeters: input.routeDistanceMeters,
      routeEtaSeconds: input.routeEtaSeconds,
      serviceIndex: input.serviceIndex,
      serviceType: input.serviceType,
      tariffId: input.tariffId,
    };
  }

  private declineSetKey(orderId: string) {
    return `order:declines:${orderId}`;
  }

  private recentListKey() {
    return 'orders:recent';
  }

  private searchingOrdersKey() {
    return 'orders:searching';
  }

  private driverOrdersKey(phone: string) {
    return `driver:orders:${phone}`;
  }

  private driverActiveOrderKey(phone: string) {
    return `driver:active_order_id:${phone}`;
  }

  private driverStatsKey(phone: string) {
    return `driver:stats:${phone}`;
  }

  private clientOrdersKey(id: string) {
    return `client:orders:${id}`;
  }

  private clientActiveOrderKey(id: string) {
    return `client:active_order_id:${id}`;
  }

  private clientProfileKey(id: string) {
    return `client:profile:${id}`;
  }

  private clientBonusKey(id: string) {
    return `client:bonus:${id}`;
  }

  private dayStatsKey(at?: Date | string) {
    return `stats:day:${this.moscowDayString(at)}`;
  }

  moscowDayString(at?: Date | string) {
    const date = at ? new Date(at) : new Date();
    const safe = Number.isNaN(date.getTime()) ? new Date() : date;
    return new Intl.DateTimeFormat('en-CA', {
      timeZone: 'Europe/Moscow',
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).format(safe);
  }

  private sanitizeCancelReason(reason?: string): string | undefined {
    const raw = (reason || '').toString().trim().replace(/\s+/g, ' ');
    if (!raw) return undefined;
    return raw.slice(0, 240);
  }

  async incrDayStats(
    fields: { orders?: number; completed?: number; canceled?: number; revenue?: number },
    at?: Date | string,
  ): Promise<void> {
    try {
      const key = this.dayStatsKey(at);
      const ordersDelta = Math.round(Number(fields.orders) || 0);
      const completedDelta = Math.round(Number(fields.completed) || 0);
      const canceledDelta = Math.round(Number(fields.canceled) || 0);
      const revenueDelta = Math.round(Number(fields.revenue) || 0);
      if (!ordersDelta && !completedDelta && !canceledDelta && !revenueDelta) return;
      const multi = this.redis.client.multi();
      if (ordersDelta) multi.hincrby(key, 'orders', ordersDelta);
      if (completedDelta) multi.hincrby(key, 'completed', completedDelta);
      if (canceledDelta) multi.hincrby(key, 'canceled', canceledDelta);
      if (revenueDelta) multi.hincrby(key, 'revenue', revenueDelta);
      multi.expire(key, 60 * 60 * 24 * 400);
      await multi.exec();
    } catch {
      // Durable stats are best-effort and must not break order flow.
    }
  }

  async getDayStats(dayYmd: string): Promise<{
    orders: number;
    completed: number;
    canceled: number;
    revenue: number;
  } | null> {
    const key = dayYmd.startsWith('stats:day:') ? dayYmd : `stats:day:${dayYmd}`;
    const raw = await this.redis.client.hgetall(key);
    if (!raw || Object.keys(raw).length === 0) return null;
    const orders = Number(raw.orders || 0);
    const completed = Number(raw.completed || 0);
    const canceled = Number(raw.canceled || 0);
    const revenue = Number(raw.revenue || 0);
    if (!orders && !completed && !canceled && !revenue) return null;
    return { orders, completed, canceled, revenue };
  }

  private driverEarningsKey(phone: string) {
    return `driver:earnings:${phone}`;
  }

  private payoutsListKey() {
    return 'payouts:recent';
  }

  private payoutKey(id: string) {
    return `payout:${id}`;
  }

  async listSearchingOrderIds(): Promise<string[]> {
    const ids = await this.redis.client.smembers(this.searchingOrdersKey());
    return (ids || []).map((id: string) => String(id || '').trim()).filter(Boolean);
  }

  async markOrderSearching(orderId: string): Promise<void> {
    if (!orderId) return;
    await this.redis.client.sadd(this.searchingOrdersKey(), orderId);
  }

  async unmarkOrderSearching(orderId: string): Promise<void> {
    if (!orderId) return;
    await this.redis.client.srem(this.searchingOrdersKey(), orderId);
    await this.redis.client.del(this.declineSetKey(orderId));
  }

  private driverRatingKey(phone: string) {
    return `driver:rating:${phone}`;
  }

  async getDriverRating(phone: string) {
    const raw = await this.redis.client.hgetall(this.driverRatingKey(phone));
    const sum = Number(raw.sum || 0);
    const count = Number(raw.count || 0);
    const avg = Number(raw.avg || 0);
    const computed = count > 0 ? Math.round((sum / count) * 10) / 10 : avg;
    return { avg: computed, count };
  }

  private routeMinutes(seconds?: number) {
    const s = Number(seconds || 0);
    if (!Number.isFinite(s) || s <= 0) return 0;
    return Math.ceil(s / 60);
  }

  private computePriceByMinutes(
    serviceIndex: number,
    from: LatLng,
    to: LatLng,
    minutes: number,
    routeDistanceMeters?: number,
    kmOutsideMkad = 0,
    kmFromAToRing = 0,
  ) {
    const safeMinutes = Math.max(1, Math.ceil(minutes));

    if (serviceIndex === 1) {
      const includedMin = 5 * 60;
      const extraMin = Math.max(0, safeMinutes - includedMin);
      return 9000 + extraMin * 25;
    }

    if (this.isRegionalTrip(from, to)) {
      return this.computeRegionalPrice(safeMinutes, kmFromAToRing, routeDistanceMeters);
    }

    // serviceIndex 0 (Трезвый водитель) и 2 (Перегон) — одна формула
    const outsideMkad = kmOutsideMkad > 0.5; // >500m = выезд за МКАД
    const includedMin = 60;
    const extraMin = Math.max(0, safeMinutes - includedMin);
    const base = outsideMkad ? 2900 : 2500;
    const kmCharge = outsideMkad ? this.kmFee(kmOutsideMkad) : 0;
    return base + extraMin * 25 + kmCharge;
  }

  private async computeFinalPrice(order: Order) {
    if (!order.startedAt || !order.completedAt) return null;
    const start = Date.parse(order.startedAt);
    const end = Date.parse(order.completedAt);
    if (!Number.isFinite(start) || !Number.isFinite(end)) return null;
    const minutes = Math.max(1, Math.ceil((end - start) / 60000));
    if (order.serviceType === 'taxi') {
      // Taxi keeps its accepted route price; sober-driver time rates do not apply.
      return { price: Math.max(0, Math.round(Number(order.priceFrom) || 0)), minutes };
    }
    const serviceIndex = Number(order.serviceIndex ?? 0);
    const kmOutside = Number(order.kmOutsideMkad || 0);
    const kmFromAToRing = Number(order.kmFromAToRing || 0);
    const calculated = this.computePriceByMinutes(
      serviceIndex,
      order.from,
      order.to,
      minutes,
      order.routeDistanceMeters,
      kmOutside,
      kmFromAToRing,
    );
    const priceFrom = this.safeNum(order.priceBeforeDiscount ?? order.priceFrom, 0);
    let price = calculated;
    const promoPercent = Math.max(0, Math.min(100, Number(order.promoDiscountPercent || 0)));
    if (promoPercent > 0) {
      price = Math.round(price * (1 - promoPercent / 100));
    }
    let markupPercent = Number(order.markupPercentApplied);
    if (!Number.isFinite(markupPercent)) {
      const tariffs = await this.loadTariffs();
      const tariff = tariffs[this.safeNum(order.serviceIndex, 0)];
      markupPercent = this.dailyMarkupForOrder(tariff, order.scheduledAt);
    }
    price = this.applyMarkupPercent(price, markupPercent);
    const minimumPrice = promoPercent > 0
      ? Math.round(priceFrom * (1 - promoPercent / 100))
      : priceFrom;
    price = Math.max(price, minimumPrice);
    const bonusUsed = Math.max(0, Math.round(Number(order.bonusUsed) || 0));
    if (bonusUsed > 0) price = Math.max(0, price - bonusUsed);
    return { price, minutes };
  }

  private kmFee(km: number) {
    const k = km <= 0 ? 0 : Math.ceil(km);
    return k * 50;
  }

  private distanceKm(a: LatLng, b: LatLng) {
    const earthRadiusKm = 6371.0;
    const lat1 = (a.lat * Math.PI) / 180.0;
    const lat2 = (b.lat * Math.PI) / 180.0;
    const dLat = lat2 - lat1;
    const dLon = ((b.lng - a.lng) * Math.PI) / 180.0;

    const sinDLat = Math.sin(dLat / 2);
    const sinDLon = Math.sin(dLon / 2);
    const h = sinDLat * sinDLat + Math.cos(lat1) * Math.cos(lat2) * sinDLon * sinDLon;
    const c = 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h));
    return earthRadiusKm * c;
  }

  private computeLegacyPrice(input: CreateOrderInput) {
    const minutes = this.routeMinutes(input.routeEtaSeconds);
    const kmOutside = Math.max(0, Number(input.kmOutsideMkad || 0));
    const kmFromAToRing = Math.max(0, Number(input.kmFromAToRing || 0));

    if (Number(input.serviceIndex) === 1) {
      const includedMin = 5 * 60;
      const extraMin = Math.max(0, minutes - includedMin);
      const priceFrom = 9000 + extraMin * 25;
      return { priceFrom, tariffName: 'Личный водитель' };
    }

    const tariffName = Number(input.serviceIndex) === 2 ? 'Перегон автомобиля' : 'Трезвый водитель';

    if (this.isRegionalTrip(input.from, input.to)) {
      const kmToRing = this.computeKmFromAToRing(input.from);
      const priceFrom = this.computeRegionalPrice(
        minutes,
        kmToRing,
        input.routeDistanceMeters,
      );
      return { priceFrom, tariffName };
    }

    const outsideMkad = kmOutside > 0.5;
    const includedMin = 60;
    const extraMin = Math.max(0, minutes - includedMin);
    const base = outsideMkad ? 2900 : 2500;
    const kmCharge = outsideMkad ? this.kmFee(kmOutside) : 0;
    const priceFrom = base + extraMin * 25 + kmCharge;
    return { priceFrom, tariffName };
  }

  private pricingDayMoscow(scheduledAt?: string) {
    const raw = String(scheduledAt || '').trim();
    // Flutter sends local DateTime without a timezone offset. Treat its calendar
    // date as Moscow time instead of letting the server's timezone shift the day.
    const localDate = raw.match(/^(\d{4})-(\d{2})-(\d{2})T/);
    const hasExplicitZone = /(?:Z|[+-]\d{2}:?\d{2})$/i.test(raw);
    if (localDate && !hasExplicitZone) {
      const date = new Date(Date.UTC(Number(localDate[1]), Number(localDate[2]) - 1, Number(localDate[3])));
      if (!Number.isNaN(date.getTime())) return date.getUTCDay();
    }
    const date = raw ? new Date(raw) : new Date();
    const safeDate = Number.isNaN(date.getTime()) ? new Date() : date;
    const weekday = new Intl.DateTimeFormat('en-US', {
      timeZone: 'Europe/Moscow',
      weekday: 'short',
    }).format(safeDate);
    return ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].indexOf(weekday);
  }

  private dailyMarkupForOrder(tariff: any, scheduledAt?: string) {
    if (!tariff) return 0;
    const day = this.pricingDayMoscow(scheduledAt);
    const daily = Array.isArray(tariff.dailyMarkupPercent) ? tariff.dailyMarkupPercent : [];
    const legacy = day === 6 ? tariff.saturdayMarkupPercent : day === 0 ? tariff.sundayMarkupPercent : 0;
    return Math.max(0, Math.min(300, this.safeNum(daily[day], this.safeNum(legacy))));
  }

  private applyMarkupPercent(priceFrom: number, percent: number) {
    if (!Number.isFinite(priceFrom) || priceFrom <= 0 || percent <= 0) return priceFrom;
    return Math.round(priceFrom * (1 + percent / 100));
  }

  private applyDailyMarkup(priceFrom: number, tariff: any, scheduledAt?: string) {
    return this.applyMarkupPercent(priceFrom, this.dailyMarkupForOrder(tariff, scheduledAt));
  }

  private defaultTariffs() {
    return [
      {
        name: 'Трезвый водитель',
        mode: 'system',
        base: 2500,
        perMin: 25,
        perKm: 50,
        includedMin: 60,
        commission: 33.3,
        dailyMarkupPercent: [0, 0, 0, 0, 0, 0, 0],
        saturdayMarkupPercent: 0,
        sundayMarkupPercent: 0,
      },
      {
        name: 'Личный водитель',
        mode: 'system',
        base: 9000,
        perMin: 25,
        includedMin: 300,
        commission: 33.3,
        dailyMarkupPercent: [0, 0, 0, 0, 0, 0, 0],
        saturdayMarkupPercent: 0,
        sundayMarkupPercent: 0,
      },
      {
        name: 'Перегон автомобиля',
        mode: 'system',
        base: 2500,
        perMin: 25,
        perKm: 50,
        includedMin: 60,
        commission: 33.3,
        dailyMarkupPercent: [0, 0, 0, 0, 0, 0, 0],
        saturdayMarkupPercent: 0,
        sundayMarkupPercent: 0,
      },
    ];
  }

  private async loadTariffs() {
    try {
      const raw = await this.redis.client.get('tariffs:list');
      const list = raw ? (JSON.parse(raw) as any[]) : [];
      if (Array.isArray(list) && list.length) return list;
    } catch {
      // Ignore corrupted Redis value and use built-in defaults.
    }
    return this.defaultTariffs();
  }

  private safeNum(v: any, fallback = 0): number {
    const n = Number(v);
    return Number.isFinite(n) ? n : fallback;
  }

  private async computeCommission(order: Order) {
    const list = await this.loadTariffs();
    const index = this.safeNum(order.serviceIndex, 0);
    const tariff = list[index];
    const rawPercent = Number(tariff?.commission);
    // 0% is a valid explicit value. Fallback is used only for invalid/missing values.
    const percent = Number.isFinite(rawPercent) && rawPercent >= 0 && rawPercent <= 100 ? rawPercent : 33.3;
    const price = this.safeNum(order.priceFinal || order.priceFrom, 0);
    const amount = Math.max(0, Math.round(price * (percent / 100)));
    return { percent, amount: Number.isFinite(amount) ? amount : 0 };
  }

  private async pushOrderIndex(key: string, orderId: string) {
    await this.redis.client.lpush(key, orderId);
    await this.redis.client.ltrim(key, 0, 99);
  }

  private async computeTaxiPrice(input: CreateOrderInput) {
    let list: TaxiTariff[] = [];
    try {
      const raw = await this.redis.client.get('taxi_tariffs:list');
      if (raw) list = JSON.parse(raw);
    } catch {
      list = [];
    }
    if (!Array.isArray(list) || !list.length) {
      list = DEFAULT_TAXI_TARIFFS;
    }
    const tariff =
      list.find((t) => String(t?.id || '') === String(input.tariffId || '')) || list[0];
    const stopsCount = Array.isArray(input.stops)
      ? input.stops.length
      : this.safeNum(input.stopsCount, 0);
    const result = computeTaxiQuote(tariff, {
      routeDistanceMeters: input.routeDistanceMeters,
      from: input.from,
      to: input.to,
      stopsCount,
      withKids: input.withKids === true,
      withPets: input.withPets === true,
      airConditioning: input.airConditioning === true,
      discountPercent: input.discountPercent,
    });
    return {
      priceFrom: result.priceFrom,
      tariffName: result.tariffName,
      markupPercent: 0,
    };
  }

  private async computePrice(input: CreateOrderInput) {
    if (String(input.serviceType || '').toLowerCase() === 'taxi') {
      return this.computeTaxiPrice(input);
    }
    const list = await this.loadTariffs();
    const index = this.safeNum(input.serviceIndex, 0);
    const tariff = list[index];
    const mode = tariff ? String(tariff.mode || '').trim().toLowerCase() : '';

    if (!tariff || mode !== 'custom') {
      const legacy = this.computeLegacyPrice(input);
      return {
        ...legacy,
        priceFrom: this.applyDailyMarkup(legacy.priceFrom, tariff, input.scheduledAt),
        markupPercent: this.dailyMarkupForOrder(tariff, input.scheduledAt),
      };
    }

    const base = this.safeNum(tariff.base);
    const perKm = this.safeNum(tariff.perKm);
    const perMin = this.safeNum(tariff.perMin);
    const includedMin = this.safeNum(tariff.includedMin);
    const distanceKm = Math.max(0, this.safeNum(input.routeDistanceMeters) / 1000);
    const minutes = this.routeMinutes(input.routeEtaSeconds);
    const extraMin = Math.max(0, minutes - includedMin);
    const priceFrom = Math.max(0, Math.round(base + perKm * distanceKm + perMin * extraMin));
    if (!Number.isFinite(priceFrom) || priceFrom <= 0) {
      const legacy = this.computeLegacyPrice(input);
      return {
        ...legacy,
        priceFrom: this.applyDailyMarkup(legacy.priceFrom, tariff, input.scheduledAt),
        markupPercent: this.dailyMarkupForOrder(tariff, input.scheduledAt),
      };
    }
    return {
      priceFrom: this.applyDailyMarkup(priceFrom, tariff, input.scheduledAt),
      markupPercent: this.dailyMarkupForOrder(tariff, input.scheduledAt),
      tariffName: String(tariff.name || ''),
    };
  }

  async createOrder(input: CreateOrderInput): Promise<Order> {
    const clientId = (input.clientId || '').trim();
    if (!clientId) throw new BadRequestException('clientId is required');
    const requestIdRaw = (input.requestId || '').toString().trim();
    const requestId = /^[a-zA-Z0-9_-]{8,64}$/.test(requestIdRaw) ? requestIdRaw : '';

    if (requestId) {
      const existingOrderId = await this.redis.client.get(this.orderRequestKey(clientId, requestId));
      if (existingOrderId) {
        try {
          const existingOrder = await this.getOrder(existingOrderId);
          if (existingOrder.clientId === clientId) {
            return existingOrder;
          }
        } catch {
          await this.redis.client.del(this.orderRequestKey(clientId, requestId));
          await this.redis.client.del(this.orderRequestPayloadKey(clientId, requestId));
        }
      }
      const payloadHash = this.hashCreatePayload({ ...input, clientId });
      const storedHash = await this.redis.client.get(this.orderRequestPayloadKey(clientId, requestId));
      if (storedHash && storedHash !== payloadHash) {
        throw new ConflictException('requestId reused with different order payload');
      }
    }

    let requestLockKey = '';
    if (requestId) {
      requestLockKey = this.orderRequestLockKey(clientId, requestId);
      const requestLockOk = await (this.redis.client as any).set(requestLockKey, '1', 'EX', 20, 'NX');
      if (!requestLockOk) {
        const orderId = await this.redis.client.get(this.orderRequestKey(clientId, requestId));
        if (orderId) {
          try {
            const order = await this.getOrder(orderId);
            if (order.clientId === clientId) return order;
          } catch {
            await this.redis.client.del(this.orderRequestKey(clientId, requestId));
          }
        }
        throw new ConflictException('Order create already in progress');
      }
    }

    try {
      const blocked = await this.redis.client.exists(`client:block:${clientId}`);
      if (blocked) throw new BadRequestException('Client is blocked');

      // Защита от дублей — нельзя создать заказ, если уже есть активный
      const existingActive = await this.findActiveOrderForClient(clientId);
      if (existingActive) {
        throw new ConflictException('Client already has an active order');
      }

      validatePoint(input.from, 'from');
      validatePoint(input.to, 'to');

      const id = crypto.randomUUID();
      // A request's discount is a preview hint; only the server profile grants it.
      const { priceFrom, tariffName, markupPercent } = await this.computePrice({ ...input, discountPercent: 0 });

    // Скидка берётся только из серверного профиля клиента и сгорает после 1 заказа.
    let discountPercent = 0;
    const profileRaw = await this.redis.client.get(this.clientProfileKey(clientId));
    if (profileRaw) {
      try {
        const profile = JSON.parse(profileRaw) as Record<string, unknown>;
        discountPercent = Math.max(
          0,
          Math.min(100, Number((profile as any).promoDiscountPercent || 0)),
        );
        if (discountPercent > 0) {
          (profile as any).promoDiscountPercent = 0;
          (profile as any).promoCode = '';
          (profile as any).updatedAt = new Date().toISOString();
          await this.redis.client.set(this.clientProfileKey(clientId), JSON.stringify(profile));
        }
      } catch {
        discountPercent = 0;
      }
    }
    const priceAfterPromo = Math.round(priceFrom * (1 - Math.max(0, Math.min(100, discountPercent)) / 100));
    let bonusUsed = 0;
    const requestedBonus = Math.max(0, Math.round(Number(input.bonusAmount) || 0));
    if (requestedBonus > 0) {
      const bonusKey = this.clientBonusKey(clientId);
      const available = Number((await this.redis.client.hget(bonusKey, 'available')) || 0);
      if (requestedBonus > available) {
        throw new BadRequestException('Insufficient bonus balance');
      }
      if (requestedBonus > priceAfterPromo) {
        throw new BadRequestException('Bonus cannot exceed order price');
      }
      await this.redis.client.hincrby(bonusKey, 'available', -requestedBonus);
      bonusUsed = requestedBonus;
    }
    const order: Order = {
      id,
      clientId,
      from: input.from,
      to: input.to,
      fromAddress: input.fromAddress?.trim() ? input.fromAddress.trim() : undefined,
      toAddress: input.toAddress?.trim() ? input.toAddress.trim() : undefined,
      comment: input.comment?.trim() ? input.comment.trim() : undefined,
      wish: input.wish?.trim() ? input.wish.trim() : undefined,
      serviceType: String(input.serviceType || '').toLowerCase() === 'taxi' ? 'taxi' : undefined,
      tariffId: input.tariffId?.toString().trim() ? input.tariffId.toString().trim() : undefined,
      serviceIndex:
        String(input.serviceType || '').toLowerCase() === 'taxi'
          ? undefined
          : Number.isFinite(Number(input.serviceIndex))
            ? Number(input.serviceIndex)
            : undefined,
      priceFrom: Math.max(0, priceAfterPromo - bonusUsed),
      priceBeforeDiscount: priceFrom,
      markupPercentApplied: markupPercent,
      promoDiscountPercent: discountPercent > 0 ? discountPercent : undefined,
      bonusUsed: bonusUsed > 0 ? bonusUsed : undefined,
      tariffName: tariffName || undefined,
      paymentMethod: input.paymentMethod === 'card'
        ? 'card'
        : input.paymentMethod === 'sbp'
          ? 'sbp'
          : 'cash',
      paymentStatus: 'unpaid',
      routeDistanceMeters: Number.isFinite(Number(input.routeDistanceMeters))
        ? Number(input.routeDistanceMeters)
        : undefined,
      routeEtaSeconds: Number.isFinite(Number(input.routeEtaSeconds))
        ? Number(input.routeEtaSeconds)
        : undefined,
      kmOutsideMkad: Number.isFinite(Number(input.kmOutsideMkad))
        ? Number(input.kmOutsideMkad)
        : 0,
      kmFromAToRing: this.isRegionalTrip(input.from, input.to)
        ? this.computeKmFromAToRing(input.from)
        : Number.isFinite(Number(input.kmFromAToRing))
          ? Number(input.kmFromAToRing)
          : 0,
      scheduledAt: input.scheduledAt?.trim() ? input.scheduledAt.trim() : undefined,
      status: 'searching',
      createdAt: new Date().toISOString(),
    };

      await this.redis.client.set(this.orderKey(id), JSON.stringify(order), 'EX', 60 * 60 * 24 * 30);
      await this.markOrderSearching(id);
      await this.redis.client.lpush(this.recentListKey(), id);
      await this.redis.client.ltrim(this.recentListKey(), 0, 1999);
      await this.redis.client.sadd('clients:all', clientId);
      await this.pushOrderIndex(this.clientOrdersKey(clientId), id);
      await this.incrDayStats({ orders: 1 }, order.createdAt);
      if (requestId) {
        await this.redis.client.set(this.orderRequestKey(clientId, requestId), id, 'EX', OrdersService.ORDER_REQUEST_TTL_SEC);
        await this.redis.client.set(
          this.orderRequestPayloadKey(clientId, requestId),
          this.hashCreatePayload({ ...input, clientId }),
          'EX',
          OrdersService.ORDER_REQUEST_TTL_SEC,
        );
      }
      return order;
    } finally {
      if (requestLockKey) {
        await this.redis.client.del(requestLockKey);
      }
    }
  }

  async getOrder(orderId: string): Promise<Order> {
    const raw = await this.redis.client.get(this.orderKey(orderId));
    if (!raw) throw new NotFoundException('Order not found');
    try {
      return JSON.parse(raw) as Order;
    } catch {
      throw new NotFoundException('Order data corrupted');
    }
  }

  async acceptOrder(orderId: string, driverPhone: string): Promise<Order> {
    const order = await this.getOrder(orderId);

    if (order.status !== 'searching') {
      throw new ConflictException('Order is not available');
    }

    if (await this.drivers.isBlocked(driverPhone)) {
      throw new ConflictException('DRIVER_BLOCKED');
    }

    // Проверка регистрации водителя
    const driverProfile = await this.drivers.getProfile(driverPhone);
    if (driverProfile && typeof driverProfile === 'object') {
      const regStatus = (driverProfile as any).registrationStatus || 'incomplete';
      if (regStatus !== 'completed') {
        throw new ConflictException('Driver registration not completed');
      }
    }

    // Проверка лимита заработка
    const earnings = await this.getDriverEarnings(driverPhone);
    const earningsLimit = Number(await this.redis.client.get('settings:earnings_limit') || 15000);
    if (Number(earnings.commission || 0) >= earningsLimit) {
      throw new ConflictException('EARNINGS_LIMIT_REACHED');
    }

    // Атомарный лок через SET NX — только один водитель пройдёт дальше
    const lockOk = await (this.redis.client as any).set(
      this.orderLockKey(orderId),
      driverPhone,
      'EX',
      30,
      'NX',
    );
    if (!lockOk) {
      throw new ConflictException('Order already taken');
    }

    try {
      // Перечитываем статус ПОСЛЕ получения лока — защита от race condition с cancelOrder
      const freshOrder = await this.getOrder(orderId);
      if (freshOrder.status !== 'searching') {
        throw new ConflictException('Order is not available');
      }

      const commission = await this.computeCommission(freshOrder);
      const next: Order = {
        ...freshOrder,
        status: 'accepted',
        driverPhone,
        commissionPercent: commission.percent,
        commissionAmount: commission.amount,
        acceptedAt: new Date().toISOString(),
      };

      await this.redis.client.set(this.orderKey(orderId), JSON.stringify(next), 'EX', 60 * 60 * 24 * 30);
      await this.unmarkOrderSearching(orderId);
      await this.appendStatusHistory(orderId, freshOrder.status, 'accepted', 'driver', {
        actorId: driverPhone,
      });

      // Определяем, является ли заказ предзаказом
      const isPreorder = freshOrder.scheduledAt
        ? new Date(freshOrder.scheduledAt).getTime() > Date.now() + 15 * 60 * 1000
        : false;

      if (isPreorder) {
        // Предзаказ — водитель остаётся online и может принимать другие заказы
        await this.drivers.setStatus(driverPhone, 'online');
        // НЕ добавляем в drivers:active_order — водитель свободен для новых заказов
      } else {
        // Обычный заказ — водитель busy
        await this.drivers.setStatus(driverPhone, 'busy');
        // Трекинг активного заказа водителя — O(1) проверка через SET
        await this.redis.client.sadd('drivers:active_order', driverPhone);
      }

      await this.pushOrderIndex(this.driverOrdersKey(driverPhone), orderId);
      await this.redis.client.hincrby(this.driverStatsKey(driverPhone), 'acceptedOrders', 1);
      // Заработок начисляется при ЗАВЕРШЕНИИ заказа, а не при принятии
      return next;
    } finally {
      // Гарантированно освобождаем лок
      await this.redis.client.del(this.orderLockKey(orderId));
    }
  }

  async declineOrder(orderId: string, driverPhone: string): Promise<void> {
    await this.getOrder(orderId);
    await this.redis.client.sadd(this.declineSetKey(orderId), driverPhone);
    await this.redis.client.expire(this.declineSetKey(orderId), 60 * 60);
  }

  async getDeclinedDrivers(orderId: string): Promise<Set<string>> {
    const phones = await this.redis.client.smembers(this.declineSetKey(orderId));
    return new Set((phones || []).map((phone) => String(phone || '').trim()).filter(Boolean));
  }

  async updateOrderStatus(
    orderId: string,
    driverPhone: string,
    statusRaw: OrderStatus | string,
    actor: OrderStatusActor = 'driver',
  ): Promise<Order> {
    const status = this.parseStatusInput(String(statusRaw));
    // Drivers may not jump into searching/accepted via free-form update — use acceptOrder.
    if (actor === 'driver' && (status === 'searching' || status === 'accepted' || status === 'draft' || status === 'quoted')) {
      throw new ConflictException(`Driver cannot set status "${status}" via update`);
    }
    // Атомарный лок — защита от двойного начисления при повторных запросах
    const lockOk = await (this.redis.client as any).set(
      this.orderLockKey(orderId),
      'status_update',
      'EX',
      30,
      'NX',
    );
    if (!lockOk) {
      throw new ConflictException('Order update already in progress');
    }
    try {
      const order = await this.getOrder(orderId);
      if (order.driverPhone && order.driverPhone !== driverPhone) {
        throw new ConflictException('Driver mismatch');
      }
      if (!order.driverPhone) {
        throw new ConflictException('Order has no driver');
      }
      this.assertStatusTransition(order.status, status, actor);
      const now = new Date().toISOString();
      const next: Order = {
        ...order,
        status,
        arrivedAt: status === 'arrived' ? now : order.arrivedAt,
        waitingAt: status === 'waiting' ? now : order.waitingAt,
        startedAt: status === 'started' ? now : order.startedAt,
        completedAt: status === 'completed' ? now : order.completedAt,
        canceledBy: status === 'canceled' ? (actor === 'driver' ? 'driver' : order.canceledBy) : order.canceledBy,
      };
      if (status === 'enroute' && !next.acceptedAt) {
        next.acceptedAt = now;
      }
      if (status === 'completed' && next.paymentMethod === 'cash') {
        next.paymentStatus = 'paid';
      }
      if (status === 'completed') {
        const finalPrice = await this.computeFinalPrice(next);
        if (finalPrice) {
          next.priceFinal = finalPrice.price;
          next.tripMinutes = finalPrice.minutes;
        }
      }
      await this.redis.client.set(this.orderKey(orderId), JSON.stringify(next), 'EX', 60 * 60 * 24 * 30);
      await this.appendStatusHistory(orderId, order.status, status, actor, {
        actorId: driverPhone,
      });
      if (status === 'completed' || status === 'canceled') {
        await this.redis.client.expire(this.orderChatKey(orderId), OrdersService.CHAT_TTL_AFTER_TRIP_SEC);
      }
      if (order.status === 'searching' && status !== 'searching') {
        await this.unmarkOrderSearching(orderId);
      }
      // При переходе в enroute — водитель становится busy (важно для предзаказов)
      if (status === 'enroute' && order.driverPhone) {
        await this.drivers.setStatus(order.driverPhone, 'busy');
        await this.redis.client.sadd('drivers:active_order', order.driverPhone);
      }
      if (status === 'completed') {
        const price = Number(next.priceFinal || next.priceFrom || 0);
        await this.incrDayStats(
          { completed: 1, revenue: Number.isFinite(price) && price > 0 ? price : 0 },
          next.completedAt || next.createdAt,
        );
      }
      if (status === 'completed' && order.driverPhone) {
        await this.redis.client.hincrby(this.driverStatsKey(order.driverPhone), 'trips', 1);
        await this.drivers.setStatus(order.driverPhone, 'online');
        await this.redis.client.srem('drivers:active_order', order.driverPhone);
        // Пересчитываем комиссию от финальной цены
        const price = Number(next.priceFinal || next.priceFrom || 0);
        if (Number.isFinite(price) && price > 0) {
          const commission = await this.computeCommission(next);
          const commAmount = Number.isFinite(commission.amount) ? commission.amount : 0;
          const safeComm = Math.min(commAmount, Math.round(price));
          const net = Math.round(price) - safeComm;
          // Обновляем комиссию в заказе
          next.commissionPercent = commission.percent;
          next.commissionAmount = safeComm;
          await this.redis.client.set(this.orderKey(orderId), JSON.stringify(next), 'EX', 60 * 60 * 24 * 30);
          // Начисляем заработок
          await this.redis.client.hincrby(this.driverEarningsKey(order.driverPhone), 'gross', Math.round(price));
          await this.redis.client.hincrby(this.driverEarningsKey(order.driverPhone), 'commission', safeComm);
          await this.redis.client.hincrby(this.driverEarningsKey(order.driverPhone), 'net', net > 0 ? net : 0);
        }
      }
      if (status === 'canceled') {
        await this.incrDayStats({ canceled: 1 }, order.createdAt);
      }
      if (status === 'canceled' && order.driverPhone) {
        await this.drivers.setStatus(order.driverPhone, 'online');
        await this.redis.client.srem('drivers:active_order', order.driverPhone);
      }
      return next;
    } finally {
      await this.redis.client.del(this.orderLockKey(orderId));
    }
  }

  async cancelOrder(orderId: string, clientId: string, reason?: string): Promise<Order> {
    const order = await this.getOrder(orderId);
    if (order.clientId !== clientId) {
      throw new BadRequestException('Client mismatch');
    }
    if (order.status === 'canceled' || order.status === 'completed') return order;

    // Лок для защиты от race condition с acceptOrder
    const lockOk = await (this.redis.client as any).set(
      this.orderLockKey(orderId),
      `cancel:${clientId}`,
      'EX',
      30,
      'NX',
    );
    if (!lockOk) {
      // Лок занят — водитель сейчас принимает заказ, перечитаем статус
      const fresh = await this.getOrder(orderId);
      if (fresh.status === 'canceled' || fresh.status === 'completed') return fresh;
      throw new ConflictException('Order is being processed, try again');
    }

    try {
      // Перечитываем статус ПОСЛЕ получения лока
      const freshOrder = await this.getOrder(orderId);
      if (freshOrder.clientId !== clientId) {
        throw new BadRequestException('Client mismatch');
      }
      if (freshOrder.status === 'canceled' || freshOrder.status === 'completed') return freshOrder;

      this.assertStatusTransition(freshOrder.status, 'canceled', 'client');
      const cancelReason = this.sanitizeCancelReason(reason) || freshOrder.cancelReason;
      const next: Order = {
        ...freshOrder,
        status: 'canceled',
        cancelReason,
        canceledBy: 'client',
      };
      await this.redis.client.set(this.orderKey(orderId), JSON.stringify(next), 'EX', 60 * 60 * 24 * 30);
      await this.unmarkOrderSearching(orderId);
      await this.appendStatusHistory(orderId, freshOrder.status, 'canceled', 'client', {
        actorId: clientId,
        reason: cancelReason,
      });
      await this.redis.client.expire(this.orderChatKey(orderId), OrdersService.CHAT_TTL_AFTER_TRIP_SEC);
      await this.incrDayStats({ canceled: 1 }, freshOrder.createdAt);
      if (freshOrder.driverPhone) {
        await this.drivers.setStatus(freshOrder.driverPhone, 'online');
        await this.redis.client.srem('drivers:active_order', freshOrder.driverPhone);
      }
      return next;
    } finally {
      await this.redis.client.del(this.orderLockKey(orderId));
    }
  }

  async adminCancel(orderId: string, reason?: string): Promise<Order> {
    const order = await this.getOrder(orderId);
    if (order.status === 'canceled' || order.status === 'completed') return order;

    // Лок для защиты от race condition
    const lockOk = await (this.redis.client as any).set(
      this.orderLockKey(orderId),
      'cancel:admin',
      'EX',
      30,
      'NX',
    );
    if (!lockOk) {
      const fresh = await this.getOrder(orderId);
      if (fresh.status === 'canceled' || fresh.status === 'completed') return fresh;
      throw new ConflictException('Order is being processed, try again');
    }

    try {
      const freshOrder = await this.getOrder(orderId);
      if (freshOrder.status === 'canceled' || freshOrder.status === 'completed') return freshOrder;

      this.assertStatusTransition(freshOrder.status, 'canceled', 'admin');
      const next: Order = { ...freshOrder, status: 'canceled' };
      next.cancelReason = this.sanitizeCancelReason(reason) || freshOrder.cancelReason;
      next.canceledBy = reason === 'Водитель не найден' ? 'system' : 'admin';
      await this.redis.client.set(this.orderKey(orderId), JSON.stringify(next), 'EX', 60 * 60 * 24 * 30);
      await this.unmarkOrderSearching(orderId);
      await this.appendStatusHistory(orderId, freshOrder.status, 'canceled', 'admin', {
        reason: next.cancelReason,
      });
      await this.redis.client.expire(this.orderChatKey(orderId), OrdersService.CHAT_TTL_AFTER_TRIP_SEC);
      await this.incrDayStats({ canceled: 1 }, freshOrder.createdAt);
      if (freshOrder.driverPhone) {
        await this.drivers.setStatus(freshOrder.driverPhone, 'online');
        await this.redis.client.srem('drivers:active_order', freshOrder.driverPhone);
      }
      return next;
    } finally {
      await this.redis.client.del(this.orderLockKey(orderId));
    }
  }

  async listRecentOrders(limit = 50): Promise<Order[]> {
    const ids = await this.redis.client.lrange(this.recentListKey(), 0, Math.max(0, limit - 1));
    if (ids.length === 0) return [];
    const raws = await this.redis.client.mget(ids.map((id) => this.orderKey(id)));
    return raws
      .filter((raw): raw is string => typeof raw === 'string')
      .map((raw) => JSON.parse(raw) as Order);
  }

  async findActiveOrderForDriver(phone: string): Promise<Order | null> {
    const normalized = phone.trim();
    const activeKey = this.driverActiveOrderKey(normalized);
    const cachedId = await this.redis.client.get(activeKey);
    if (cachedId) {
      const raw = await this.redis.client.get(this.orderKey(cachedId));
      if (raw) {
        const cached = JSON.parse(raw) as Order;
        if (
          cached.driverPhone === normalized &&
          ACTIVE_TRIP_STATUSES.has(cached.status)
        ) {
          return cached;
        }
      }
      await this.redis.client.del(activeKey);
    }

    // Per-driver index is much smaller than the global recent-orders list and
    // keeps the hot GPS path from loading/parsing up to 200 unrelated orders.
    const ids = await this.redis.client.lrange(this.driverOrdersKey(normalized), 0, 49);
    if (!ids.length) return null;
    const raws = await this.redis.client.mget(ids.map((id) => this.orderKey(id)));
    const orders = raws
      .filter((raw): raw is string => typeof raw === 'string')
      .map((raw) => JSON.parse(raw) as Order);
    const active =
      orders.find(
        (o) =>
          o.driverPhone === normalized &&
          ACTIVE_TRIP_STATUSES.has(o.status),
      ) || null;
    if (active) {
      await this.redis.client.set(activeKey, active.id, 'EX', 21_600);
    }
    return active;
  }

  async findActiveOrderForClient(clientId: string): Promise<Order | null> {
    const normalized = clientId.trim();
    const activeKey = this.clientActiveOrderKey(normalized);
    const cachedId = await this.redis.client.get(activeKey);
    if (cachedId) {
      const raw = await this.redis.client.get(this.orderKey(cachedId));
      if (raw) {
        const cached = JSON.parse(raw) as Order;
        if (
          cached.clientId === normalized &&
          CLIENT_ACTIVE_STATUSES.has(cached.status)
        ) {
          return cached;
        }
      }
      await this.redis.client.del(activeKey);
    }

    const ids = await this.redis.client.lrange(this.clientOrdersKey(normalized), 0, 49);
    if (!ids.length) return null;
    const raws = await this.redis.client.mget(ids.map((id) => this.orderKey(id)));
    const orders = raws
      .filter((raw): raw is string => typeof raw === 'string')
      .map((raw) => JSON.parse(raw) as Order)
      .filter(
        (o) =>
          o.clientId === normalized &&
          CLIENT_ACTIVE_STATUSES.has(o.status),
      );
    if (!orders.length) return null;
    orders.sort((a, b) => Date.parse(b.createdAt) - Date.parse(a.createdAt));
    const active = orders[0] || null;
    if (active) {
      await this.redis.client.set(activeKey, active.id, 'EX', 21_600);
    }
    return active;
  }

  private parseDateValue(value?: string, endOfDay = false) {
    if (!value) return undefined;
    const date = new Date(value);
    if (Number.isNaN(date.getTime())) return undefined;
    if (value.length === 10) {
      if (endOfDay) {
        date.setHours(23, 59, 59, 999);
      } else {
        date.setHours(0, 0, 0, 0);
      }
    }
    return date.getTime();
  }

  async listRecentOrdersFiltered(input: {
    limit?: number;
    status?: string;
    active?: boolean;
    paymentStatus?: string;
    clientId?: string;
    driverPhone?: string;
    from?: string;
    to?: string;
    priceMin?: number;
    priceMax?: number;
  }): Promise<Order[]> {
    const limit = Math.min(200, Math.max(1, input.limit || 50));
    const fetchLimit = Math.max(200, limit * 4);
    const ids = await this.redis.client.lrange(this.recentListKey(), 0, fetchLimit - 1);
    if (!ids.length) return [];
    const raws = await this.redis.client.mget(ids.map((id) => this.orderKey(id)));
    const orders = raws
      .filter((raw): raw is string => typeof raw === 'string')
      .map((raw) => JSON.parse(raw) as Order);

    const status = (input.status || '').trim();
    const paymentStatus = (input.paymentStatus || '').trim();
    const clientId = (input.clientId || '').trim();
    const driverPhone = (input.driverPhone || '').trim();
    const fromTs = this.parseDateValue(input.from, false);
    const toTs = this.parseDateValue(input.to, true);
    const priceMin = Number.isFinite(Number(input.priceMin)) ? Number(input.priceMin) : undefined;
    const priceMax = Number.isFinite(Number(input.priceMax)) ? Number(input.priceMax) : undefined;

    const filtered = orders.filter((o) => {
      if (input.active) {
        if (!CLIENT_ACTIVE_STATUSES.has(o.status)) return false;
      }
      if (status && o.status !== status) return false;
      if (paymentStatus && o.paymentStatus !== paymentStatus) return false;
      if (clientId && o.clientId !== clientId) return false;
      if (driverPhone && o.driverPhone !== driverPhone) return false;
      if (fromTs || toTs) {
        const ts = Date.parse(o.createdAt);
        if (Number.isNaN(ts)) return false;
        if (fromTs && ts < fromTs) return false;
        if (toTs && ts > toTs) return false;
      }
      if (priceMin != null) {
        const price = Number(o.priceFrom || 0);
        if (price < priceMin) return false;
      }
      if (priceMax != null) {
        const price = Number(o.priceFrom || 0);
        if (price > priceMax) return false;
      }
      return true;
    });

    return filtered.slice(0, limit);
  }

  async listOrdersForDriver(phone: string, limit = 50, globalFallback = true, offset = 0): Promise<Order[]> {
    const safeLimit = Math.min(100, Math.max(1, Math.floor(Number(limit) || 50)));
    const safeOffset = Math.max(0, Math.floor(Number(offset) || 0));
    const ids = await this.redis.client.lrange(
      this.driverOrdersKey(phone),
      safeOffset,
      safeOffset + safeLimit - 1,
    );
    if (!ids.length) {
      if (!globalFallback) return [];
      const fallback = await this.getAllOrdersForStats(2000);
      return fallback
        .filter((o) => (o.driverPhone || '').trim() === phone)
        .sort((a, b) => new Date(b.createdAt || 0).getTime() - new Date(a.createdAt || 0).getTime())
        .slice(safeOffset, safeOffset + safeLimit);
    }
    const raws = await this.redis.client.mget(ids.map((id) => this.orderKey(id)));
    return raws
      .filter((raw): raw is string => typeof raw === 'string')
      .map((raw) => JSON.parse(raw) as Order);
  }

  async listOrdersForClient(clientId: string, limit = 50, offset = 0): Promise<Order[]> {
    const safeLimit = Math.min(100, Math.max(1, Math.floor(Number(limit) || 50)));
    const safeOffset = Math.max(0, Math.floor(Number(offset) || 0));
    const ids = await this.redis.client.lrange(
      this.clientOrdersKey(clientId),
      safeOffset,
      safeOffset + safeLimit - 1,
    );
    if (!ids.length) {
      const fallback = await this.getAllOrdersForStats(2000);
      return fallback
        .filter((o) => (o.clientId || '').trim() === clientId)
        .sort((a, b) => new Date(b.createdAt || 0).getTime() - new Date(a.createdAt || 0).getTime())
        .slice(safeOffset, safeOffset + safeLimit);
    }
    const raws = await this.redis.client.mget(ids.map((id) => this.orderKey(id)));
    return raws
      .filter((raw): raw is string => typeof raw === 'string')
      .map((raw) => JSON.parse(raw) as Order);
  }

  async getClientOrderCount(clientId: string): Promise<number> {
    const n = await this.redis.client.llen(this.clientOrdersKey(clientId));
    return Number.isFinite(n) ? n : 0;
  }

  async findNearbySearchingOrderForDriver(phone: string, radiusKm = 2.5): Promise<Order | null> {
    const loc = await this.drivers.getLocation(phone);
    if (!loc) return null;
    const ids = await this.redis.client.lrange(this.recentListKey(), 0, 199);
    if (!ids.length) return null;
    const raws = await this.redis.client.mget(ids.map((id) => this.orderKey(id)));
    const orders = raws
      .filter((raw): raw is string => typeof raw === 'string')
      .map((raw) => JSON.parse(raw) as Order)
      .filter((o) => o.status === 'searching');
    let best: Order | null = null;
    let bestDist = Number.POSITIVE_INFINITY;
    for (const o of orders) {
      const dist = this.distanceKm(loc, o.from);
      if (dist <= radiusKm && dist < bestDist) {
        bestDist = dist;
        best = o;
      }
    }
    return best;
  }

  async listPayouts(limit = 50, driverPhone?: string) {
    const ids = await this.redis.client.lrange(this.payoutsListKey(), 0, Math.max(0, limit - 1));
    if (!ids.length) return [];
    const raws = await this.redis.client.mget(ids.map((id) => this.payoutKey(id)));
    const payouts = raws
      .filter((raw): raw is string => typeof raw === 'string')
      .map((raw) => JSON.parse(raw) as any);
    if (!driverPhone) return payouts;
    return payouts.filter((p) => p?.driverPhone === driverPhone);
  }

  async assignDriver(orderId: string, driverPhone: string) {
    // Лок для защиты от race condition с acceptOrder
    const lockOk = await (this.redis.client as any).set(
      this.orderLockKey(orderId),
      'assign',
      'EX',
      30,
      'NX',
    );
    if (!lockOk) {
      throw new ConflictException('Order update already in progress');
    }
    try {
      const normalizedDriverPhone = await this.drivers.resolveProfilePhone(driverPhone);
      if (!normalizedDriverPhone) {
        throw new ConflictException('Driver phone required');
      }
      const order = await this.getOrder(orderId);
      if (order.status === 'canceled' || order.status === 'completed') {
        throw new ConflictException('Order is not available');
      }
      const driverProfile = await this.drivers.getProfile(normalizedDriverPhone);
      if (!driverProfile || typeof driverProfile !== 'object') {
        throw new ConflictException('Driver not found');
      }
      if ((driverProfile as any).registrationStatus !== 'completed') {
        throw new ConflictException('Driver registration not completed');
      }
      if (await this.drivers.isBlocked(normalizedDriverPhone)) {
        throw new ConflictException('Driver is blocked');
      }
      if (order.driverPhone && order.driverPhone === normalizedDriverPhone) return order;
      if (order.driverPhone && order.driverPhone !== normalizedDriverPhone) {
        await this.drivers.setStatus(order.driverPhone, 'online');
        await this.redis.client.srem('drivers:active_order', order.driverPhone);
      }
      const prevStatus = order.status;
      if (prevStatus !== 'accepted') {
        this.assertStatusTransition(prevStatus, 'accepted', 'admin');
      }
      const commission = await this.computeCommission(order);
      const next: Order = {
        ...order,
        status: 'accepted',
        driverPhone: normalizedDriverPhone,
        commissionPercent: commission.percent,
        commissionAmount: commission.amount,
        acceptedAt: new Date().toISOString(),
      };
      await this.redis.client.set(this.orderKey(orderId), JSON.stringify(next), 'EX', 60 * 60 * 24 * 30);
      await this.unmarkOrderSearching(orderId);
      if (prevStatus !== 'accepted') {
        await this.appendStatusHistory(orderId, prevStatus, 'accepted', 'admin', {
          actorId: normalizedDriverPhone,
        });
      }
      await this.drivers.setStatus(normalizedDriverPhone, 'busy');
      await this.pushOrderIndex(this.driverOrdersKey(normalizedDriverPhone), orderId);
      await this.redis.client.sadd('drivers:active_order', normalizedDriverPhone);
      return next;
    } finally {
      await this.redis.client.del(this.orderLockKey(orderId));
    }
  }

  async markPaid(orderId: string) {
    const order = await this.getOrder(orderId);
    if (order.paymentStatus === 'paid') return order;
    if (order.status !== 'completed') {
      throw new ConflictException('Only completed orders can be marked as paid');
    }
    const from = (order.paymentStatus || 'unpaid') as PaymentStatus;
    assertPaymentStatusTransition(from, 'paid');
    const next: Order = {
      ...order,
      paymentStatus: 'paid',
    };
    await this.redis.client.set(this.orderKey(orderId), JSON.stringify(next), 'EX', 60 * 60 * 24 * 30);
    return next;
  }

  async setPaymentStatus(orderId: string, statusRaw: PaymentStatus | string) {
    const status = normalizePaymentStatus(String(statusRaw));
    if (!status) throw new BadRequestException(`Unknown payment status: ${statusRaw}`);
    const order = await this.getOrder(orderId);
    if (order.paymentMethod === 'cash' && status === 'paid') {
      throw new ConflictException('Cash order cannot be paid by online webhook');
    }
    const from = (order.paymentStatus || 'unpaid') as PaymentStatus;
    if (from === status) return order;
    assertPaymentStatusTransition(from, status);
    const next: Order = { ...order, paymentStatus: status };
    await this.redis.client.set(this.orderKey(orderId), JSON.stringify(next), 'EX', 60 * 60 * 24 * 30);
    return next;
  }

  async createPayout(input: { driverPhone: string; amount: number; orderId?: string }) {
    const id = crypto.randomUUID();
    const payout = {
      id,
      driverPhone: input.driverPhone,
      amount: Math.round(Number(input.amount) || 0),
      orderId: input.orderId || undefined,
      createdAt: new Date().toISOString(),
      status: 'paid',
    };
    await this.redis.client.set(this.payoutKey(id), JSON.stringify(payout), 'EX', 60 * 60 * 24 * 365);
    await this.redis.client.lpush(this.payoutsListKey(), id);
    await this.redis.client.ltrim(this.payoutsListKey(), 0, 199);
    await this.redis.client.hincrby(this.driverEarningsKey(input.driverPhone), 'paid', payout.amount);
    return payout;
  }

  /** Откатить начисленный заработок при отмене заказа (не допускаем уход в минус) */
  private async rollbackEarnings(order: Order): Promise<void> {
    if (!order.driverPhone || !order.priceFrom) return;
    const gross = Math.round(Number(order.priceFrom) || 0);
    if (gross <= 0) return;
    const commissionAmount = Math.round(Number(order.commissionAmount) || 0);
    const net = gross - commissionAmount;
    // Читаем текущие значения чтобы не уйти в минус
    const current = await this.redis.client.hgetall(this.driverEarningsKey(order.driverPhone));
    const curGross = Number(current.gross || 0);
    const curCommission = Number(current.commission || 0);
    const curNet = Number(current.net || 0);
    // Вычитаем не больше чем есть
    const subGross = Math.min(gross, curGross);
    const subCommission = Math.min(commissionAmount, curCommission);
    const subNet = Math.min(net, curNet);
    if (subGross > 0) await this.redis.client.hincrby(this.driverEarningsKey(order.driverPhone), 'gross', -subGross);
    if (subCommission > 0) await this.redis.client.hincrby(this.driverEarningsKey(order.driverPhone), 'commission', -subCommission);
    if (subNet > 0) await this.redis.client.hincrby(this.driverEarningsKey(order.driverPhone), 'net', -subNet);
  }

  async getEarningsLimit(): Promise<number> {
    return Number(await this.redis.client.get('settings:earnings_limit') || 15000);
  }

  async getDriverEarnings(phone: string) {
    const raw = await this.redis.client.hgetall(this.driverEarningsKey(phone));
    const gross = this.safeNum(raw.gross);
    const commission = this.safeNum(raw.commission);
    const net = this.safeNum(raw.net);
    const paid = this.safeNum(raw.paid);
    return {
      gross,
      commission,
      net,
      paid,
      available: Math.max(0, net - paid),
    };
  }

  /** Batch eligibility check for dispatch; a single Redis pipeline for all drivers. */
  async filterDriversBelowEarningsLimit(phones: string[], limit: number): Promise<string[]> {
    if (!phones.length) return [];
    const pipeline = this.redis.client.pipeline();
    phones.forEach((phone) => pipeline.hget(this.driverEarningsKey(phone), 'commission'));
    const results = await pipeline.exec();
    return phones.filter((_, index) => Number(results?.[index]?.[1] || 0) < limit);
  }

  async getDriverStats(phone: string, limit = 50) {
    const cached = await this.redis.client.hgetall(this.driverStatsKey(phone));
    if (cached.acceptedOrders != null || cached.trips != null) {
      return {
        acceptedOrders: Number(cached.acceptedOrders || 0),
        trips: Number(cached.trips || 0),
      };
    }
    const orders = await this.listOrdersForDriver(phone, limit, false);
    let trips = 0;
    let acceptedOrders = 0;
    for (const o of orders) {
      if (o.status === 'canceled') continue;
      acceptedOrders += 1;
      if (o.status === 'completed') trips += 1;
    }
    if (acceptedOrders > 0 || trips > 0) {
      await this.redis.client.hset(this.driverStatsKey(phone), {
        acceptedOrders: String(acceptedOrders),
        trips: String(trips),
      });
    }
    return { acceptedOrders, trips };
  }

  async getAllOrdersForStats(limit = 2000): Promise<Order[]> {
    const ids = await this.redis.client.lrange(this.recentListKey(), 0, Math.max(0, limit - 1));
    if (!ids.length) return [];
    // Fetch in batches to avoid huge mget
    const batchSize = 200;
    const orders: Order[] = [];
    for (let i = 0; i < ids.length; i += batchSize) {
      const batch = ids.slice(i, i + batchSize);
      const raws = await this.redis.client.mget(batch.map((id) => this.orderKey(id)));
      for (const raw of raws) {
        if (typeof raw === 'string') {
          try {
            orders.push(JSON.parse(raw) as Order);
          } catch {}
        }
      }
    }
    return orders;
  }

  async rateOrder(orderId: string, clientId: string, rating: number) {
    const order = await this.getOrder(orderId);
    if (order.clientId !== clientId) {
      throw new BadRequestException('Client mismatch');
    }
    if (order.status !== 'completed') {
      throw new ConflictException('Order not completed');
    }
    if (order.ratedAt) {
      throw new ConflictException('Order already rated');
    }
    const r = Math.max(1, Math.min(5, Math.round(rating)));
    const next: Order = {
      ...order,
      rating: r,
      ratedAt: new Date().toISOString(),
    };
    await this.redis.client.set(this.orderKey(orderId), JSON.stringify(next), 'EX', 60 * 60 * 24 * 30);

    if (order.driverPhone) {
      const key = this.driverRatingKey(order.driverPhone);
      const multi = this.redis.client.multi();
      multi.hincrby(key, 'sum', r);
      multi.hincrby(key, 'count', 1);
      const res = await multi.exec();
      const sum = Number(res?.[0]?.[1] || 0);
      const count = Number(res?.[1]?.[1] || 0);
      const avg = count > 0 ? Math.round((sum / count) * 10) / 10 : r;
      await this.redis.client.hset(key, 'avg', avg);
    }
    return next;
  }
}
