import { ConflictException, ForbiddenException } from '@nestjs/common';

/**
 * Wire statuses stored in Redis and emitted to Flutter clients.
 * TZ aliases (driver_arriving, in_progress, …) normalize into these.
 */
export type OrderStatus =
  | 'draft'
  | 'quoted'
  | 'searching'
  | 'accepted'
  | 'enroute'
  | 'arrived'
  | 'waiting'
  | 'started'
  | 'completed'
  | 'canceled';

export type OrderStatusActor = 'client' | 'driver' | 'admin' | 'system';

export type PaymentStatus = 'unpaid' | 'pending' | 'paid' | 'failed' | 'refunded';

/** Canonical lifecycle (clients must not invent transitions). */
export const ORDER_STATUS_TRANSITIONS: Readonly<Record<OrderStatus, readonly OrderStatus[]>> = {
  draft: ['quoted', 'searching', 'canceled'],
  quoted: ['searching', 'canceled'],
  searching: ['accepted', 'canceled'],
  accepted: ['enroute', 'canceled'],
  enroute: ['arrived', 'canceled'],
  arrived: ['waiting', 'started', 'canceled'],
  waiting: ['started', 'canceled'],
  started: ['completed', 'canceled'],
  completed: [],
  canceled: [],
};

/** Who may request each target status (in addition to transition graph). */
export const ORDER_STATUS_ACTORS: Readonly<Record<OrderStatus, readonly OrderStatusActor[]>> = {
  draft: ['system', 'admin'],
  quoted: ['system', 'admin', 'client'],
  searching: ['system', 'admin', 'client'],
  accepted: ['driver', 'admin', 'system'],
  enroute: ['driver', 'admin'],
  arrived: ['driver', 'admin'],
  waiting: ['driver', 'admin'],
  started: ['driver', 'admin'],
  completed: ['driver', 'admin'],
  canceled: ['client', 'driver', 'admin', 'system'],
};

export const PAYMENT_STATUS_TRANSITIONS: Readonly<Record<PaymentStatus, readonly PaymentStatus[]>> = {
  unpaid: ['pending', 'paid', 'failed'],
  pending: ['paid', 'failed', 'unpaid'],
  paid: ['refunded'],
  failed: ['pending', 'unpaid', 'paid'],
  refunded: [],
};

/** Map TZ / synonym names → stored wire status. */
const STATUS_ALIASES: Readonly<Record<string, OrderStatus>> = {
  draft: 'draft',
  quoted: 'quoted',
  searching: 'searching',
  assigned: 'accepted',
  driver_assigned: 'accepted',
  driver_accepted: 'accepted',
  accepted: 'accepted',
  arriving: 'enroute',
  driver_arriving: 'enroute',
  enroute: 'enroute',
  arrived: 'arrived',
  driver_arrived: 'arrived',
  waiting: 'waiting',
  in_progress: 'started',
  started: 'started',
  completed: 'completed',
  canceled: 'canceled',
  cancelled: 'canceled',
  cancelled_by_client: 'canceled',
  cancelled_by_driver: 'canceled',
  cancelled_by_dispatch: 'canceled',
  canceled_by_client: 'canceled',
  canceled_by_driver: 'canceled',
  canceled_by_dispatch: 'canceled',
};

const PAYMENT_ALIASES: Readonly<Record<string, PaymentStatus>> = {
  unpaid: 'unpaid',
  payment_pending: 'pending',
  pending: 'pending',
  paid: 'paid',
  payment_failed: 'failed',
  failed: 'failed',
  refunded: 'refunded',
  refund: 'refunded',
};

export function normalizeOrderStatus(raw: string): OrderStatus | null {
  const key = String(raw || '')
    .trim()
    .toLowerCase()
    .replace(/-/g, '_');
  return STATUS_ALIASES[key] ?? null;
}

export function normalizePaymentStatus(raw: string): PaymentStatus | null {
  const key = String(raw || '')
    .trim()
    .toLowerCase()
    .replace(/-/g, '_');
  return PAYMENT_ALIASES[key] ?? null;
}

export function assertOrderStatusTransition(
  from: OrderStatus,
  to: OrderStatus,
  actor: OrderStatusActor,
): void {
  if (from === to) return;
  const allowed = ORDER_STATUS_TRANSITIONS[from] || [];
  if (!allowed.includes(to)) {
    throw new ConflictException(`Invalid status transition: ${from} → ${to}`);
  }
  const actors = ORDER_STATUS_ACTORS[to] || [];
  if (!actors.includes(actor)) {
    throw new ForbiddenException(`Actor "${actor}" cannot set status "${to}"`);
  }
  // Clients may only cancel — never advance trip lifecycle.
  if (actor === 'client' && to !== 'canceled') {
    throw new ForbiddenException('Client cannot set trip status');
  }
}

export function assertPaymentStatusTransition(from: PaymentStatus, to: PaymentStatus): void {
  if (from === to) return;
  const allowed = PAYMENT_STATUS_TRANSITIONS[from] || [];
  if (!allowed.includes(to)) {
    throw new ConflictException(`Invalid payment transition: ${from} → ${to}`);
  }
}

export const ACTIVE_TRIP_STATUSES: ReadonlySet<OrderStatus> = new Set([
  'accepted',
  'enroute',
  'arrived',
  'waiting',
  'started',
]);

export const CLIENT_ACTIVE_STATUSES: ReadonlySet<OrderStatus> = new Set([
  'searching',
  'accepted',
  'enroute',
  'arrived',
  'waiting',
  'started',
]);
