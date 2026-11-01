import {
  ConnectedSocket,
  MessageBody,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
  OnGatewayConnection,
  OnGatewayDisconnect,
} from '@nestjs/websockets';
import { OnModuleInit, OnModuleDestroy, Logger } from '@nestjs/common';
import { Server, Socket } from 'socket.io';
import jwt from 'jsonwebtoken';
import { corsOrigin } from './cors-policy';

import { Order, OrdersService } from './orders.service';
import { DriversService } from './drivers.service';
import { RedisService } from './redis.service';
import { PushService } from './push.service';

/** Расширяющиеся радиусы поиска (метры) */
const SEARCH_RADII = [1000, 3000, 5000, 10000, 15000, 20000];
/** Задержка между раундами поиска (мс) */
const SEARCH_INTERVAL_MS = 10_000;
/** Автоотмена заказа если водитель не найден (мс) — 5 минут */
const AUTO_CANCEL_DELAY_MS = 5 * 60 * 1000;
/** Интервал очистки стухших Map-записей (мс) — 60 секунд */
const MAP_CLEANUP_INTERVAL_MS = 60_000;

@WebSocketGateway({
  cors: {
    origin: corsOrigin,
    credentials: true,
  },
})
export class EventsGateway implements OnGatewayConnection, OnGatewayDisconnect, OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(EventsGateway.name);
  constructor(
    private readonly orders: OrdersService,
    private readonly drivers: DriversService,
    private readonly redis: RedisService,
    private readonly push: PushService,
  ) {}

  @WebSocketServer()
  server!: Server;

  /** Активные таймеры расширяющегося поиска: orderId → timerId */
  private searchTimers = new Map<string, ReturnType<typeof setTimeout>>();
  /** Множество уже уведомлённых водителей по заказу */
  private notifiedDrivers = new Map<string, Set<string>>();
  /** Таймеры автоотмены заказов (когда водитель не найден) */
  private autoCancelTimers = new Map<string, ReturnType<typeof setTimeout>>();
  /** Offer timeouts: `${orderId}:${phone}` → timer (reassign on no-accept) */
  private offerTimeoutTimers = new Map<string, ReturnType<typeof setTimeout>>();
  /** Интервал периодической очистки Maps */
  private cleanupInterval: ReturnType<typeof setInterval> | null = null;
  /** Отложенный offline после disconnect — даёт Android/iOS переподключить сокет */
  private disconnectOfflineTimers = new Map<string, ReturnType<typeof setTimeout>>();
  private static readonly DISCONNECT_OFFLINE_GRACE_MS = 45_000;

  private notifiedSetKey(orderId: string) {
    return `order:notified:${orderId}`;
  }

  async onModuleInit() {
    // Запуск периодической очистки стухших записей в Maps
    this.cleanupInterval = setInterval(() => this.cleanupStaleMaps(), MAP_CLEANUP_INTERVAL_MS);
    this.logger.log('Map cleanup interval started (every 60s)');
    await this.restoreSearchingOrders();
  }

  onModuleDestroy() {
    if (this.cleanupInterval) {
      clearInterval(this.cleanupInterval);
      this.cleanupInterval = null;
    }
    // Очищаем все таймеры
    for (const timer of this.searchTimers.values()) clearTimeout(timer);
    this.searchTimers.clear();
    for (const timer of this.autoCancelTimers.values()) clearTimeout(timer);
    this.autoCancelTimers.clear();
    for (const timer of this.offerTimeoutTimers.values()) clearTimeout(timer);
    this.offerTimeoutTimers.clear();
    for (const timer of this.disconnectOfflineTimers.values()) clearTimeout(timer);
    this.disconnectOfflineTimers.clear();
    this.notifiedDrivers.clear();
  }

  private clearDisconnectOfflineTimer(phone: string) {
    const timer = this.disconnectOfflineTimers.get(phone);
    if (timer) {
      clearTimeout(timer);
      this.disconnectOfflineTimers.delete(phone);
    }
  }

  private scheduleDriverOffline(phone: string) {
    this.clearDisconnectOfflineTimer(phone);
    const timer = setTimeout(() => {
      this.disconnectOfflineTimers.delete(phone);
      if (!this.hasLiveDriverSocket(phone)) {
        void this.drivers.setStatus(phone, 'offline');
      }
    }, EventsGateway.DISCONNECT_OFFLINE_GRACE_MS);
    this.disconnectOfflineTimers.set(phone, timer);
  }

  /** Периодическая очистка: если заказ больше не в searching, удаляем из Maps */
  private async cleanupStaleMaps() {
    const orderIds = new Set([
      ...this.searchTimers.keys(),
      ...this.notifiedDrivers.keys(),
      ...this.autoCancelTimers.keys(),
    ]);
    if (orderIds.size === 0) return;

    let cleaned = 0;
    for (const orderId of orderIds) {
      try {
        const order = await this.orders.getOrder(orderId);
        if (order.status !== 'searching') {
          this.stopExpandingSearch(orderId);
          this.stopAutoCancel(orderId);
          cleaned++;
        }
      } catch {
        // Заказ не найден — тоже очищаем
        this.stopExpandingSearch(orderId);
        this.stopAutoCancel(orderId);
        cleaned++;
      }
    }
    if (cleaned > 0) {
      this.logger.log(`Map cleanup: removed ${cleaned} stale entries`);
    }
  }

  private async restoreSearchingOrders() {
    try {
      const searchingIds = await this.orders.listSearchingOrderIds();
      const activeSearches: Order[] = [];
      for (const orderId of searchingIds) {
        try {
          const order = await this.orders.getOrder(orderId);
          if (order.status === 'searching') {
            activeSearches.push(order);
          } else {
            await this.orders.unmarkOrderSearching(orderId);
          }
        } catch {
          await this.orders.unmarkOrderSearching(orderId);
        }
      }
      if (!activeSearches.length) return;
      activeSearches.forEach((order) => this.startExpandingSearch(order));
      this.logger.log(`Restored ${activeSearches.length} searching orders after restart`);
    } catch (err) {
      this.logger.warn(`Failed to restore searching orders: ${err}`);
    }
  }

  private async retrySearchingOrdersForDriver(phone: string) {
    for (const [orderId, notified] of this.notifiedDrivers.entries()) {
      if (!notified.has(phone)) continue;
      try {
        const order = await this.orders.getOrder(orderId);
        if (order.status !== 'searching') continue;
        this.stopExpandingSearch(orderId);
        this.notifiedDrivers.set(orderId, notified);
        await this.runSearchRound(order, 0, notified);
      } catch (err) {
        this.logger.warn(`Failed to retry searching order ${orderId} after driver disconnect ${phone}: ${err}`);
      }
    }
  }

  private async deliverNearbySearchingOrderToDriver(phone: string) {
    try {
      const nearby = await this.orders.findNearbySearchingOrderForDriver(phone, 8);
      if (nearby) {
        this.server.to(`driver:${phone}`).emit('order:nearby', { order: nearby });
      }
    } catch (err) {
      this.logger.warn(`Failed to deliver nearby searching order to ${phone}: ${err}`);
    }
  }

  handleConnection(client: Socket) {
    const token =
      (client.handshake.auth && (client.handshake.auth as any).token) ||
      (typeof client.handshake.headers.authorization === 'string'
        ? client.handshake.headers.authorization.replace(/^Bearer\s+/i, '')
        : undefined);
    const secret = process.env.JWT_SECRET;
    if (!secret || !token) {
      this.logger.warn(`Socket rejected: missing auth token from ${client.handshake.address}`);
      client.disconnect(true);
      return;
    }
    try {
      const payload = jwt.verify(token, secret) as any;
      (client.data as any).user = payload;
    } catch (err) {
      const message = err instanceof Error ? err.message : String(err);
      this.logger.warn(`Socket rejected: invalid token from ${client.handshake.address}: ${message}`);
      client.disconnect(true);
      return;
    }

    const user = (client.data as any).user as undefined | { phone?: string; role?: string };
    if (user?.role === 'driver') {
      if (user.phone) {
        this.clearDisconnectOfflineTimer(user.phone);
        client.join(`driver:${user.phone}`);
      }
      client.join('drivers');
      return;
    }
    if (user?.role === 'client' && typeof user.phone === 'string' && user.phone.trim()) {
      client.join(`client:${user.phone.trim()}`);
      client.join('clients');
      return;
    }
    this.logger.warn(`Socket rejected: unsupported role from ${client.handshake.address}`);
    client.disconnect(true);
  }

  handleDisconnect(client: Socket) {
    const user = (client.data as any).user as undefined | { phone?: string; role?: string };
    if (user?.role === 'driver' && typeof user.phone === 'string') {
      this.scheduleDriverOffline(user.phone);
    }
  }

  // ─── Отправка заказа водителям ───────────────────────────────

  private hasLiveDriverSocket(phone: string): boolean {
    const room = this.server.sockets.adapter.rooms.get(`driver:${phone}`);
    return Boolean(room && room.size > 0);
  }

  async emitOrderNew(order: Order, driverPhones?: string[]): Promise<string[]> {
    const orderAcceptTimeoutSec = await this.drivers.getOrderAcceptTimeoutSec();
    // Не шлём notifiedAt: водительское приложение 1.0.0+6 при отсутствии поля
    // ставит DateTime.now() на устройстве — полный таймер без потери на задержку сокета.
    const payload = {
      order,
      orderAcceptTimeoutSec,
    };
    if (driverPhones && driverPhones.length) {
      const delivered: string[] = [];
      driverPhones.forEach((phone) => {
        if (!this.hasLiveDriverSocket(phone)) return;
        this.server.to(`driver:${phone}`).emit('order:new', payload);
        delivered.push(phone);
      });
      void this.push.notifyDriversNewOrder(order, driverPhones);
      return delivered;
    }
    this.server.to('drivers').emit('order:new', payload);
    return [];
  }

  // ─── Расширяющийся поиск водителей ──────────────────────────

  /**
   * Запускает каскадный поиск: сначала ближайшие водители,
   * если никто не принял — расширяем радиус, и так до "все онлайн".
   */
  startExpandingSearch(order: Order) {
    // Очищаем предыдущий поиск для этого заказа если был
    this.stopExpandingSearch(order.id);
    const notified = new Set<string>();
    this.notifiedDrivers.set(order.id, notified);

    // Запускаем первый раунд немедленно
    this.runSearchRound(order, 0, notified);
  }

  stopExpandingSearch(orderId: string) {
    const timer = this.searchTimers.get(orderId);
    if (timer) {
      clearTimeout(timer);
      this.searchTimers.delete(orderId);
    }
    this.notifiedDrivers.delete(orderId);
    this.clearOfferTimeoutsForOrder(orderId);
  }

  private offerKey(orderId: string, phone: string) {
    return `${orderId}:${phone}`;
  }

  private clearOfferTimeoutsForOrder(orderId: string) {
    for (const [key, timer] of this.offerTimeoutTimers.entries()) {
      if (key.startsWith(`${orderId}:`)) {
        clearTimeout(timer);
        this.offerTimeoutTimers.delete(key);
      }
    }
  }

  private clearOfferTimeout(orderId: string, phone: string) {
    const key = this.offerKey(orderId, phone);
    const timer = this.offerTimeoutTimers.get(key);
    if (timer) {
      clearTimeout(timer);
      this.offerTimeoutTimers.delete(key);
    }
  }

  /**
   * If driver neither accepts nor declines within offer timeout,
   * mark declined and continue search (reassign).
   */
  private scheduleOfferTimeouts(order: Order, phones: string[], timeoutSec: number) {
    const ms = Math.max(5, timeoutSec) * 1000;
    for (const phone of phones) {
      this.clearOfferTimeout(order.id, phone);
      const key = this.offerKey(order.id, phone);
      const timer = setTimeout(() => {
        this.offerTimeoutTimers.delete(key);
        void this.onOfferTimedOut(order.id, phone);
      }, ms);
      this.offerTimeoutTimers.set(key, timer);
    }
  }

  private async onOfferTimedOut(orderId: string, phone: string) {
    try {
      const order = await this.orders.getOrder(orderId);
      if (order.status !== 'searching') return;
      await this.orders.declineOrder(orderId, phone);
      const strike = await this.drivers.registerMissedOrder(phone);
      if (strike.blocked) {
        this.emitDriverBlocked(phone, {
          reason: strike.reason || 'missed_orders',
          until: strike.until || null,
        });
      }
      this.server.to(`driver:${phone}`).emit('order:offer_expired', { orderId });
      const existing = this.notifiedDrivers.get(orderId) ?? new Set<string>();
      existing.add(phone);
      this.stopExpandingSearch(orderId);
      this.notifiedDrivers.set(orderId, existing);
      await this.runSearchRound(order, 0, existing);
      this.logger.log(`Offer timeout → reassign order ${orderId} (driver ${phone})`);
    } catch (err) {
      this.logger.warn(`Offer timeout handler failed for ${orderId}/${phone}: ${err}`);
    }
  }

  /** Запуск таймера автоотмены заказа через 5 минут */
  private startAutoCancel(order: Order) {
    this.stopAutoCancel(order.id);
    const timer = setTimeout(async () => {
      this.autoCancelTimers.delete(order.id);
      try {
        const current = await this.orders.getOrder(order.id);
        if (current.status !== 'searching') return;
        // Автоотмена — водитель не найден
        const canceled = await this.orders.adminCancel(order.id, 'Водитель не найден');
        this.emitOrderStatus(canceled);
        this.emitOrderDelay(order, 'К сожалению, свободных водителей не найдено. Попробуйте позже.');
        this.logger.log(`Auto-canceled order ${order.id} — no driver found`);
      } catch (err) {
        this.logger.warn(`Auto-cancel failed for order ${order.id}: ${err}`);
      }
    }, AUTO_CANCEL_DELAY_MS);
    this.autoCancelTimers.set(order.id, timer);
  }

  stopAutoCancel(orderId: string) {
    const timer = this.autoCancelTimers.get(orderId);
    if (timer) {
      clearTimeout(timer);
      this.autoCancelTimers.delete(orderId);
    }
  }

  private async runSearchRound(order: Order, roundIndex: number, notified: Set<string>) {
    try {
      const persisted = await this.redis.client.smembers(this.notifiedSetKey(order.id));
      (persisted || []).forEach((phone: string) => {
        const p = String(phone || '').trim();
        if (p) notified.add(p);
      });
    } catch {
      // ignore redis issues, in-memory dedupe still works within process lifetime
    }

    // Проверяем актуальность заказа
    try {
      const current = await this.orders.getOrder(order.id);
      if (current.status !== 'searching') {
        this.stopExpandingSearch(order.id);
        return;
      }
    } catch {
      this.stopExpandingSearch(order.id);
      return;
    }

    let candidateDrivers: string[] = [];
    const declinedDrivers = await this.orders.getDeclinedDrivers(order.id);

    // Лимит заработка — не отправляем заказ водителям с достигнутым лимитом
    const earningsLimit = Number(
      (await this.orders.getEarningsLimit()) || 15000,
    );

    if (roundIndex < SEARCH_RADII.length) {
      const radius = SEARCH_RADII[roundIndex];
      const nearby = await this.drivers.getNearbyDrivers(
        order.from.lat,
        order.from.lng,
        radius,
        200,
      );
      // Фильтруем: только ещё не уведомлённые, без активных заказов и без лимита
      for (const phone of nearby) {
        if (notified.has(phone)) continue;
        if (declinedDrivers.has(phone)) continue;
        candidateDrivers.push(phone);
      }
    } else {
      // Финальный раунд — все онлайн водители
      const all = await this.drivers.listOnlineDrivers();
      for (const phone of all) {
        if (notified.has(phone)) continue;
        if (declinedDrivers.has(phone)) continue;
        candidateDrivers.push(phone);
      }
    }

    // Two pipelined Redis checks instead of 2*N sequential network calls.
    candidateDrivers = await this.drivers.filterWithoutActiveOrders(candidateDrivers);
    candidateDrivers = await this.orders.filterDriversBelowEarningsLimit(
      candidateDrivers,
      earningsLimit,
    );
    candidateDrivers = await this.drivers.filterByTariffOrService(candidateDrivers, {
      tariffId: order.tariffId,
      serviceIndex: order.serviceIndex,
      serviceType: order.serviceType,
    });

    // Отправляем заказ только реально подключенным водителям.
    // В notified попадают только те, кто действительно получил событие.
    let deliveredDrivers: string[] = [];
    if (candidateDrivers.length > 0) {
      deliveredDrivers = await this.emitOrderNew(order, candidateDrivers);
      deliveredDrivers.forEach((phone) => notified.add(phone));
      if (deliveredDrivers.length) {
        await this.redis.client.sadd(this.notifiedSetKey(order.id), ...deliveredDrivers);
        await this.redis.client.expire(this.notifiedSetKey(order.id), 60 * 60 * 2);
        const orderAcceptTimeoutSec = await this.drivers.getOrderAcceptTimeoutSec();
        this.scheduleOfferTimeouts(order, deliveredDrivers, orderAcceptTimeoutSec);
      }

      // Не сбрасываем offline водителей без доставки: сокет мог кратко отвалиться.
      // Следующий раунд поиска или reconnect повторит попытку.
    }

    // Сообщение для клиента о ходе поиска + реальное число водителей,
    // которым заказ доставлен в текущем раунде. Клиент рисует только
    // приблизительные маркеры, не раскрывая точные координаты водителей.
    if (deliveredDrivers.length > 0) {
      const candidateLocations = await this.driverLocationsForClient(deliveredDrivers);
      this.emitOrderDelay(
        order,
        'Рядом есть подходящие машины',
        deliveredDrivers.length,
        roundIndex,
        candidateLocations,
      );
    } else if (roundIndex === 0) {
      this.emitOrderDelay(order, 'Ищем водителя поблизости…', 0, roundIndex);
    } else if (roundIndex > 0 && roundIndex < SEARCH_RADII.length && deliveredDrivers.length === 0) {
      this.emitOrderDelay(order, 'Расширяем зону поиска…', 0, roundIndex);
    }

    // Планируем следующий раунд если ещё есть куда расширять
    if (roundIndex <= SEARCH_RADII.length) {
      const timer = setTimeout(() => {
        this.runSearchRound(order, roundIndex + 1, notified);
      }, SEARCH_INTERVAL_MS);
      this.searchTimers.set(order.id, timer);
    } else {
      // Все раунды завершены — запуск таймера автоотмены через 5 минут
      this.emitOrderDelay(order, 'Ожидайте, все водители получили ваш заказ.');
      this.stopExpandingSearch(order.id);
      this.startAutoCancel(order);
    }
  }

  // ─── Уведомления о статусе ──────────────────────────────────

  emitOrderStatus(order: Order) {
    const payload = {
      orderId: order.id,
      status: order.status,
      driverPhone: order.driverPhone,
      paymentStatus: order.paymentStatus,
      cancelReason: order.cancelReason,
      canceledBy: order.canceledBy,
    };
    this.server.to(`client:${order.clientId}`).emit('order:status', payload);
    this.server.to('drivers').emit('order:status', payload);
    if (order.driverPhone) {
      this.server.to(`driver:${order.driverPhone}`).emit('order:status', payload);
    }
    void this.push.notifyClientOrderStatus(order);

    // Если заказ принят — остановить поиск + автоотмену + уведомить конкретного водителя
    if (order.status === 'accepted' && order.driverPhone) {
      this.stopExpandingSearch(order.id);
      this.stopAutoCancel(order.id);
      this.clearOfferTimeoutsForOrder(order.id);
      void this.redis.client.del(this.notifiedSetKey(order.id));
      this.joinOrderChatRoom(order);
      // Дополнительно — отправить order:taken всем водителям чтобы убрали заказ с экрана
      this.server.to('drivers').emit('order:taken', {
        orderId: order.id,
        driverPhone: order.driverPhone,
      });
    }

    // Если заказ отменён — остановить поиск + автоотмену + уведомить конкретного водителя
    if (order.status === 'canceled') {
      this.stopExpandingSearch(order.id);
      this.stopAutoCancel(order.id);
      this.clearOfferTimeoutsForOrder(order.id);
      void this.redis.client.del(this.notifiedSetKey(order.id));
      if (order.driverPhone) {
        this.server.to(`driver:${order.driverPhone}`).emit('order:canceled', {
          orderId: order.id,
          reason: order.cancelReason || 'Клиент отменил заказ',
          canceledBy: order.canceledBy || 'client',
        });
      }
      this.server.to(`client:${order.clientId}`).emit('order:canceled', {
        orderId: order.id,
        reason: order.cancelReason || 'Заказ отменён',
        canceledBy: order.canceledBy || 'system',
      });
    }
  }

  emitPaymentStatus(order: Order) {
    const payload = {
      orderId: order.id,
      paymentStatus: order.paymentStatus,
      paymentMethod: order.paymentMethod,
      amount: order.priceFinal ?? order.priceFrom,
    };
    this.server.to(`client:${order.clientId}`).emit('payment:status', payload);
    if (order.driverPhone) {
      this.server.to(`driver:${order.driverPhone}`).emit('payment:status', payload);
    }
  }

  // ─── Блокировка водителя ────────────────────────────────────

  emitDriverBlocked(phone: string, payload?: { reason?: string; until?: string | null }) {
    this.server.to(`driver:${phone}`).emit('driver:blocked', {
      phone,
      reason: payload?.reason || 'manual',
      until: payload?.until || null,
    });
  }

  emitDriverUnblocked(phone: string) {
    this.server.to(`driver:${phone}`).emit('driver:unblocked', { phone });
  }

  emitDriverSubscriptionOverdue(phone: string) {
    this.server.to(`driver:${phone}`).emit('driver:subscription_overdue', { phone });
  }

  emitDriverSubscriptionPaid(phone: string) {
    this.server.to(`driver:${phone}`).emit('driver:subscription_paid', { phone });
  }

  /** Комиссия погашена — водитель снова может принимать заказы */
  emitCommissionCleared(phone: string) {
    this.server.to(`driver:${phone}`).emit('commission:cleared', { phone });
  }

  private async driverLocationsForClient(phones: string[]) {
    const locations = [];
    for (const phone of phones.slice(0, 12)) {
      const loc = await this.drivers.getLocation(phone);
      if (!loc) continue;
      locations.push({
        lat: Number(loc.lat),
        lng: Number(loc.lng),
      });
    }
    return locations;
  }

  emitOrderDelay(
    order: Order,
    message: string,
    candidateCount?: number,
    searchRound?: number,
    candidateLocations?: Array<{ lat: number; lng: number }>,
  ) {
    this.server.to(`client:${order.clientId}`).emit('order:delay', {
      orderId: order.id,
      message,
      ...(Number.isFinite(candidateCount) ? { candidateCount } : {}),
      ...(Number.isFinite(searchRound) ? { searchRound } : {}),
      ...(candidateLocations?.length ? { candidateLocations } : {}),
    });
  }

  private orderChatRoom(orderId: string) {
    return `order:${orderId}`;
  }

  /** Join client + assigned driver sockets into room `order:{id}`. */
  private joinOrderChatRoom(order: Order) {
    this.server.in(`client:${order.clientId}`).socketsJoin(this.orderChatRoom(order.id));
    if (order.driverPhone) {
      this.server.in(`driver:${order.driverPhone}`).socketsJoin(this.orderChatRoom(order.id));
    }
  }

  /** In-trip chat: broadcast to room `order:{id}` (also legacy client/driver rooms). */
  emitOrderChat(orderId: string, message: Record<string, unknown>) {
    void this.orders.getOrder(orderId).then((order) => {
      this.joinOrderChatRoom(order);
      const payload = {
        orderId,
        message,
        text: message['text'],
        role: message['senderRole'],
        senderId: message['senderId'],
        createdAt: message['createdAt'],
      };
      // Room unions deliver once, including peers that reconnect during a trip.
      const rooms = [this.orderChatRoom(orderId), `client:${order.clientId}`];
      if (order.driverPhone) {
        rooms.push(`driver:${order.driverPhone}`);
      }
      this.server.to(rooms).emit('order:chat', payload);
      void this.push.notifyChatMessage(order, message);
    }).catch((err) => {
      this.logger.warn(`emitOrderChat failed for ${orderId}: ${err}`);
    });
  }

  @SubscribeMessage('order:chat')
  async orderChat(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: { orderId?: string; text?: string; role?: string },
  ) {
    const user = (client.data as any).user as undefined | { phone?: string; role?: string };
    if (!user || typeof user.phone !== 'string' || !user.phone.trim()) {
      return { ok: false, error: 'UNAUTHORIZED' };
    }
    const orderId = (body?.orderId || '').trim();
    const text = (body?.text || '').toString();
    if (!orderId) return { ok: false, error: 'orderId required' };
    try {
      // JWT role is authoritative; body.role is optional client hint.
      const role = user.role === 'driver' ? 'driver' : user.role === 'client' ? 'client' : null;
      if (!role) return { ok: false, error: 'UNAUTHORIZED' };
      const message = await this.orders.addChatMessage({
        orderId,
        senderRole: role,
        senderId: user.phone.trim(),
        text,
      });
      // Grant room membership only after participant authorization succeeds.
      await client.join(this.orderChatRoom(orderId));
      this.emitOrderChat(orderId, message as unknown as Record<string, unknown>);
      return { ok: true, message };
    } catch (err: any) {
      return { ok: false, error: err?.message || 'CHAT_FAILED' };
    }
  }

  // ─── Обработчики сообщений от водителей ─────────────────────

  @SubscribeMessage('driver:location')
  async driverLocation(
    @ConnectedSocket() client: Socket,
    @MessageBody()
    body: {
      lat?: number;
      lng?: number;
      accuracyMeters?: number;
      recordedAt?: string;
    },
  ) {
    const user = (client.data as any).user as undefined | { phone?: string; role?: string };
    if (!user || user.role !== 'driver' || typeof user.phone !== 'string') {
      return { ok: false, error: 'UNAUTHORIZED' };
    }
    const lat = Number(body?.lat);
    const lng = Number(body?.lng);
    if (
      !Number.isFinite(lat) ||
      !Number.isFinite(lng) ||
      lat < -90 ||
      lat > 90 ||
      lng < -180 ||
      lng > 180 ||
      (lat === 0 && lng === 0)
    ) {
      return { ok: false, error: 'invalid coords' };
    }

    const accuracyMeters = Number(body?.accuracyMeters);
    if (
      Number.isFinite(accuracyMeters) &&
      (accuracyMeters <= 0 || accuracyMeters > 250)
    ) {
      return { ok: false, error: 'INACCURATE_LOCATION' };
    }

    const recordedAt = body?.recordedAt
      ? Date.parse(String(body.recordedAt))
      : Date.now();
    const locationAgeMs = Date.now() - recordedAt;
    if (
      !Number.isFinite(recordedAt) ||
      locationAgeMs > 120_000 ||
      locationAgeMs < -30_000
    ) {
      return { ok: false, error: 'STALE_LOCATION' };
    }

    const now = Date.now();
    const lastLocationAt = Number((client.data as any).lastLocationAt || 0);
    if (lastLocationAt && now - lastLocationAt < 2_000) {
      return { ok: true, throttled: true };
    }
    (client.data as any).lastLocationAt = now;

      const recordedAtIso = new Date(recordedAt).toISOString();
      const updated = await this.drivers.updateLocation(user.phone, lat, lng, {
        ...(Number.isFinite(accuracyMeters) ? { accuracyMeters } : {}),
        recordedAt: recordedAtIso,
      });
    if (!updated) return { ok: false, error: 'DRIVER_OFFLINE' };
    const active = await this.orders.findActiveOrderForDriver(user.phone);
    if (active) {
      this.server.to(`client:${active.clientId}`).emit('driver:location', {
        orderId: active.id,
        driverPhone: user.phone,
          status: active.status,
          lat,
          lng,
          ...(Number.isFinite(accuracyMeters) ? { accuracyMeters } : {}),
          recordedAt: recordedAtIso,
        });
    }
    return { ok: true };
  }

  @SubscribeMessage('driver:status')
  async driverStatus(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: { status?: 'online' | 'offline' | 'busy' },
  ) {
    const user = (client.data as any).user as undefined | { phone?: string; role?: string };
    if (!user || user.role !== 'driver' || typeof user.phone !== 'string') {
      return { ok: false, error: 'UNAUTHORIZED' };
    }
    // Проверяем блокировку
    const isBlocked = await this.drivers.isBlocked(user.phone);
    if (isBlocked) {
      const meta = await this.drivers.getBlockMeta(user.phone);
      client.emit('driver:blocked', {
        phone: user.phone,
        reason: meta?.reason || 'manual',
        until: meta?.until || null,
      });
      await this.drivers.setStatus(user.phone, 'offline');
      return { ok: false, error: 'BLOCKED', blocked: true };
    }
    const status = body?.status;
    if (status !== 'online' && status !== 'offline' && status !== 'busy') {
      return { ok: false, error: 'invalid status' };
    }
    if (status === 'online') {
      const earnings = await this.orders.getDriverEarnings(user.phone);
      const earningsLimit = await this.orders.getEarningsLimit();
      const commission = Number(earnings.commission || 0);
      if (commission >= earningsLimit) {
        await this.drivers.setStatus(user.phone, 'offline');
        client.emit('driver:earnings-limit', {
          phone: user.phone,
          commission,
          limit: earningsLimit,
        });
        return {
          ok: false,
          error: 'EARNINGS_LIMIT_REACHED',
          commission,
          limit: earningsLimit,
        };
      }
      const subOverdue = await this.drivers.isSubscriptionOverdue(user.phone);
      const hasActiveOrder = await this.drivers.hasActiveOrder(user.phone);
      if (subOverdue && !hasActiveOrder) {
        await this.drivers.setStatus(user.phone, 'offline');
        client.emit('driver:subscription_overdue', { phone: user.phone });
        return { ok: false, error: 'SUBSCRIPTION_OVERDUE' };
      }
    }
    await this.drivers.setStatus(user.phone, status);
    if (status === 'online') {
      void this.retrySearchingOrdersForDriver(user.phone);
      void this.deliverNearbySearchingOrderToDriver(user.phone);
    }
    return { ok: true };
  }

  @SubscribeMessage('order:accept')
  async accept(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: { orderId?: string },
  ) {
    const user = (client.data as any).user as undefined | { phone?: string; role?: string };
    if (!user || user.role !== 'driver' || typeof user.phone !== 'string' || !user.phone.trim()) {
      return { ok: false, error: 'UNAUTHORIZED' };
    }
    const orderId = (body?.orderId || '').trim();
    if (!orderId) return { ok: false, error: 'orderId required' };

    try {
      const order = await this.orders.acceptOrder(orderId, user.phone.trim());
      this.clearOfferTimeoutsForOrder(orderId);
      this.emitOrderStatus(order);
      return { ok: true, order };
    } catch (err: any) {
      const message = err?.message || err?.response?.message || 'Order already taken';
      if (message === 'DRIVER_BLOCKED') {
        const meta = await this.drivers.getBlockMeta(user.phone.trim());
        client.emit('driver:blocked', {
          phone: user.phone.trim(),
          reason: meta?.reason || 'manual',
          until: meta?.until || null,
        });
        return { ok: false, error: 'DRIVER_BLOCKED', message };
      }
      // Лимит заработка — отдельный код ошибки для водителя
      if (message === 'EARNINGS_LIMIT_REACHED') {
        return { ok: false, error: 'EARNINGS_LIMIT_REACHED', message };
      }
      // Race condition — заказ уже принят другим водителем
      return { ok: false, error: 'ORDER_TAKEN', message };
    }
  }

  @SubscribeMessage('order:decline')
  async decline(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: { orderId?: string },
  ) {
    const user = (client.data as any).user as undefined | { phone?: string; role?: string };
    if (!user || user.role !== 'driver' || typeof user.phone !== 'string' || !user.phone.trim()) {
      return { ok: false, error: 'UNAUTHORIZED' };
    }
    const orderId = (body?.orderId || '').trim();
    if (!orderId) return { ok: false, error: 'orderId required' };

    await this.orders.declineOrder(orderId, user.phone.trim());
    this.clearOfferTimeout(orderId, user.phone.trim());
    const strike = await this.drivers.registerMissedOrder(user.phone.trim());
    if (strike.blocked) {
      client.emit('driver:blocked', {
        phone: user.phone.trim(),
        reason: strike.reason || 'missed_orders',
        until: strike.until || null,
      });
    }
    try {
      const order = await this.orders.getOrder(orderId);
      if (order.status === 'searching') {
        const existing = this.notifiedDrivers.get(order.id) ?? new Set<string>();
        this.stopExpandingSearch(order.id);
        this.notifiedDrivers.set(order.id, existing);
        await this.runSearchRound(order, 0, existing);
      }
    } catch (err) {
      this.logger.warn(`Failed to continue search for declined order ${orderId}: ${err}`);
    }
    return { ok: true };
  }

  @SubscribeMessage('order:update')
  async update(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: { orderId?: string; status?: string },
  ) {
    const user = (client.data as any).user as undefined | { phone?: string; role?: string };
    if (!user || user.role !== 'driver' || typeof user.phone !== 'string' || !user.phone.trim()) {
      return { ok: false, error: 'UNAUTHORIZED' };
    }
    const orderId = (body?.orderId || '').trim();
    const status = (body?.status || '').trim();
    if (!orderId || !status) return { ok: false, error: 'orderId and status required' };
    let order: Order;
    try {
      order = await this.orders.updateOrderStatus(orderId, user.phone.trim(), status as any);
    } catch (err: any) {
      return { ok: false, error: err?.message || 'UPDATE_FAILED' };
    }
    this.emitOrderStatus(order);
    if (order.status === 'completed') {
      const nearby = await this.orders.findNearbySearchingOrderForDriver(user.phone.trim(), 2.5);
      if (nearby) {
        this.server.to(`driver:${user.phone.trim()}`).emit('order:nearby', { order: nearby });
      }
    }
    return { ok: true, order };
  }

  /** Admin broadcast to apps (all / clients / drivers) */
  emitBroadcast(broadcast: {
    id: string;
    title: string;
    body: string;
    type: string;
    audience: string;
    active?: boolean;
    startsAt?: string | null;
    endsAt?: string | null;
    createdAt?: string;
  }) {
    const payload = { broadcast };
    const audience = broadcast.audience === 'drivers' ? ['drivers']
      : broadcast.audience === 'clients' ? ['clients'] : ['drivers', 'clients'];
    this.server.to(audience).emit('broadcast:new', payload);
    this.logger.log(`Broadcast pushed: ${broadcast.id} (${broadcast.type})`);
  }

  emitBroadcastDeactivated(broadcast: { id: string; title?: string }) {
    const payload = { broadcastId: broadcast.id, broadcast };
    this.server.to(['drivers', 'clients']).emit('broadcast:deactivated', payload);
  }

}
