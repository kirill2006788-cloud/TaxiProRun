import { Body, Controller, ForbiddenException, Get, Headers, Param, Post, Query, UnauthorizedException } from '@nestjs/common';
import { EventsGateway } from './events.gateway';
import { DriversService } from './drivers.service';
import { CreateOrderInput, OrdersService, QuoteOrderInput } from './orders.service';
import { RedisService } from './redis.service';
import jwt from 'jsonwebtoken';

@Controller('orders')
export class OrdersController {
  constructor(
    private readonly orders: OrdersService,
    private readonly events: EventsGateway,
    private readonly drivers: DriversService,
    private readonly redis: RedisService,
  ) {}

  private verifyToken(auth?: string) {
    const token = auth?.replace(/^Bearer\s+/i, '').trim();
    if (!token) throw new UnauthorizedException('Authorization required');
    const secret = process.env.JWT_SECRET;
    if (!secret) throw new UnauthorizedException('Server configuration error');
    try {
      const payload = jwt.verify(token, secret) as any;
      if (payload?.role === 'client' || payload?.role === 'driver') return payload;
    } catch {
      // Admin JWTs can be signed with an independent secret.
    }
    return this.requireAdmin(auth);
  }

  private requireAdmin(auth?: string) {
    const token = auth?.replace(/^Bearer\s+/i, '').trim();
    if (!token) throw new UnauthorizedException('Admin token required');
    const secret = process.env.ADMIN_JWT_SECRET || process.env.JWT_SECRET;
    if (!secret) throw new UnauthorizedException('Server configuration error');
    let payload: any;
    try {
      payload = jwt.verify(token, secret, {
        issuer: 'prostotaxi-admin',
        audience: 'prostotaxi-admin-panel',
      }) as any;
    } catch {
      throw new UnauthorizedException('Invalid token');
    }
    if (!payload || payload.role !== 'admin' || payload.scope !== 'admin:full') {
      throw new UnauthorizedException('Admin token required');
    }
    return payload;
  }

  private driverProfileKey(phone: string) {
    return `driver:profile:${phone}`;
  }

  private clientProfileKey(id: string) {
    return `client:profile:${id}`;
  }

  private requireClientId(auth?: string) {
    const payload = this.verifyToken(auth);
    if (!payload || payload.role !== 'client' || typeof payload.phone !== 'string' || !payload.phone.trim()) {
      throw new UnauthorizedException('Client token required');
    }
    return payload.phone.trim();
  }

  private requireDriverPhone(auth?: string) {
    const payload = this.verifyToken(auth);
    if (!payload || payload.role !== 'driver' || typeof payload.phone !== 'string' || !payload.phone.trim()) {
      throw new UnauthorizedException('Driver token required');
    }
    return payload.phone.trim();
  }

  @Post()
  async create(@Body() body: CreateOrderInput, @Headers('authorization') auth?: string) {
    const clientId = this.requireClientId(auth);
    const order = await this.orders.createOrder({
      ...body,
      clientId,
    });
    // Запускаем расширяющийся поиск водителей (2→4→6→8→15→all км)
    this.events.startExpandingSearch(order);
    return { ok: true, order };
  }

  /** Расчёт priceFrom по маршруту/тарифу без создания заказа. */
  @Post('quote')
  async quotePost(@Body() body: QuoteOrderInput) {
    const quote = await this.orders.quoteOrder(body);
    return { ok: true, quote };
  }

  @Get('quote')
  async quoteGet(
    @Query('fromLat') fromLat?: string,
    @Query('fromLng') fromLng?: string,
    @Query('toLat') toLat?: string,
    @Query('toLng') toLng?: string,
    @Query('serviceIndex') serviceIndex?: string,
    @Query('serviceType') serviceType?: string,
    @Query('tariffId') tariffId?: string,
    @Query('routeDistanceMeters') routeDistanceMeters?: string,
    @Query('routeEtaSeconds') routeEtaSeconds?: string,
    @Query('kmOutsideMkad') kmOutsideMkad?: string,
    @Query('scheduledAt') scheduledAt?: string,
  ) {
    const input: QuoteOrderInput = {
      from: { lat: Number(fromLat), lng: Number(fromLng) },
      to: { lat: Number(toLat), lng: Number(toLng) },
      serviceIndex: serviceIndex != null ? Number(serviceIndex) : undefined,
      serviceType: serviceType || undefined,
      tariffId: tariffId || undefined,
      routeDistanceMeters: routeDistanceMeters != null ? Number(routeDistanceMeters) : undefined,
      routeEtaSeconds: routeEtaSeconds != null ? Number(routeEtaSeconds) : undefined,
      kmOutsideMkad: kmOutsideMkad != null ? Number(kmOutsideMkad) : undefined,
      scheduledAt: scheduledAt || undefined,
    };
    const quote = await this.orders.quoteOrder(input);
    return { ok: true, quote };
  }

  @Get('history/client')
  async getHistoryForClient(
    @Query('limit') limitRaw?: string,
    @Query('offset') offsetRaw?: string,
    @Query('page') pageRaw?: string,
    @Headers('authorization') auth?: string,
  ) {
    const clientId = this.requireClientId(auth);
    const limit = Math.min(100, Math.max(1, Number(limitRaw) || 50));
    const page = Math.max(1, Math.floor(Number(pageRaw) || 1));
    const offsetFromPage = (page - 1) * limit;
    const offset = Math.max(0, Math.floor(Number(offsetRaw) || offsetFromPage));
    const orders = await this.orders.listOrdersForClient(clientId, limit, offset);
    return { ok: true, orders, limit, offset, page };
  }

  @Get('active/client')
  async getActiveForClient(@Headers('authorization') auth?: string) {
    const clientId = this.requireClientId(auth);
    const order = await this.orders.findActiveOrderForClient(clientId);
    let driverLat: number | null = null;
    let driverLng: number | null = null;
    if (order && order.driverPhone) {
      const loc = await this.drivers.getLocation(order.driverPhone);
      if (loc) {
        driverLat = loc.lat;
        driverLng = loc.lng;
      }
    }
    return { ok: true, order, driverLat, driverLng };
  }

  @Get('active/driver')
  async getActiveForDriver(@Headers('authorization') auth?: string) {
    const phone = this.requireDriverPhone(auth);
    const order = await this.orders.findActiveOrderForDriver(phone);
    return { ok: true, order };
  }

  @Get(':id/chat')
  async listChat(
    @Param('id') id: string,
    @Query('limit') limitRaw?: string,
    @Headers('authorization') auth?: string,
  ) {
    const order = await this.orders.getOrder(id);
    const payload = this.verifyToken(auth);
    if (payload?.role === 'client') {
      const clientId = String(payload.phone || '').trim();
      if (!clientId || order.clientId !== clientId) throw new ForbiddenException('Access denied');
    } else if (payload?.role === 'driver') {
      const phone = String(payload.phone || '').trim();
      if (!phone || order.driverPhone !== phone) throw new ForbiddenException('Access denied');
    } else if (payload?.role !== 'admin') {
      throw new ForbiddenException('Access denied');
    }
    const limit = Math.min(100, Math.max(1, Number(limitRaw) || 50));
    const messages = await this.orders.listChatMessages(id, limit);
    return { ok: true, messages };
  }

  @Post(':id/chat')
  async postChat(
    @Param('id') id: string,
    @Body() body: { text?: string },
    @Headers('authorization') auth?: string,
  ) {
    const payload = this.verifyToken(auth);
    const text = (body?.text || '').toString();
    let message;
    if (payload?.role === 'client') {
      const clientId = String(payload.phone || '').trim();
      message = await this.orders.addChatMessage({
        orderId: id,
        senderRole: 'client',
        senderId: clientId,
        text,
      });
    } else if (payload?.role === 'driver') {
      const phone = String(payload.phone || '').trim();
      message = await this.orders.addChatMessage({
        orderId: id,
        senderRole: 'driver',
        senderId: phone,
        text,
      });
    } else {
      throw new ForbiddenException('Access denied');
    }
    this.events.emitOrderChat(id, message);
    return { ok: true, message };
  }

  @Get(':id/status-history')
  async statusHistory(
    @Param('id') id: string,
    @Query('limit') limitRaw?: string,
    @Headers('authorization') auth?: string,
  ) {
    this.requireAdmin(auth);
    const limit = Math.min(100, Math.max(1, Number(limitRaw) || 50));
    const history = await this.orders.listStatusHistory(id, limit);
    return { ok: true, history };
  }

  @Get(':id')
  async get(@Param('id') id: string, @Headers('authorization') auth?: string) {
    const order = await this.orders.getOrder(id);
    const payload = this.verifyToken(auth);
    if (payload?.role === 'client') {
      const clientId = String(payload.phone || '').trim();
      if (!clientId || order.clientId !== clientId) {
        throw new ForbiddenException('Access denied');
      }
    } else if (payload?.role === 'driver') {
      const phone = String(payload.phone || '').trim();
      if (!phone || order.driverPhone !== phone) {
        throw new ForbiddenException('Access denied');
      }
    } else if (payload?.role !== 'admin') {
      throw new ForbiddenException('Access denied');
    }
    // Добавляем координаты водителя если заказ активный
    let driverLat: number | null = null;
    let driverLng: number | null = null;
    if (order && order.driverPhone) {
      const loc = await this.drivers.getLocation(order.driverPhone);
      if (loc) {
        driverLat = loc.lat;
        driverLng = loc.lng;
      }
    }
    return { ok: true, order, driverLat, driverLng };
  }

  @Post(':id/cancel')
  async cancel(
    @Param('id') id: string,
    @Body() body: { clientId?: string; reason?: string },
    @Headers('authorization') auth?: string,
  ) {
    const clientId = this.requireClientId(auth);
    const order = await this.orders.cancelOrder(id, clientId, body?.reason);
    this.events.emitOrderStatus(order);
    return { ok: true, order };
  }

  @Post(':id/pay')
  async pay(@Param('id') id: string, @Headers('authorization') auth?: string) {
    this.requireAdmin(auth);
    const order = await this.orders.markPaid(id);
    this.events.emitPaymentStatus(order);
    return { ok: true, order };
  }

  @Post(':id/rate')
  async rate(
    @Param('id') id: string,
    @Body() body: { clientId?: string; rating?: number },
    @Headers('authorization') auth?: string,
  ) {
    const clientId = this.requireClientId(auth);
    const rating = Number(body?.rating || 0);
    const order = await this.orders.rateOrder(id, clientId, rating);
    return { ok: true, order };
  }

  @Get()
  async list(
    @Query('limit') limitRaw?: string,
    @Query('status') status?: string,
    @Query('active') active?: string,
    @Query('paymentStatus') paymentStatus?: string,
    @Query('clientId') clientId?: string,
    @Query('driverPhone') driverPhone?: string,
    @Query('from') from?: string,
    @Query('to') to?: string,
    @Query('priceMin') priceMin?: string,
    @Query('priceMax') priceMax?: string,
    @Headers('authorization') auth?: string,
  ) {
    this.requireAdmin(auth);
    const limit = Math.min(200, Math.max(1, Number(limitRaw) || 50));
    const orders = await this.orders.listRecentOrdersFiltered({
      limit,
      status,
      active: active === '1' || active === 'true',
      paymentStatus,
      clientId,
      driverPhone,
      from,
      to,
      priceMin: priceMin ? Number(priceMin) : undefined,
      priceMax: priceMax ? Number(priceMax) : undefined,
    });
    const driverPhones = Array.from(new Set(orders.map((o) => String(o.driverPhone || '').trim()).filter(Boolean)));
    const clientIds = Array.from(new Set(orders.map((o) => String(o.clientId || '').trim()).filter(Boolean)));
    const pipeline = this.redis.client.pipeline();
    driverPhones.forEach((phone) => pipeline.get(this.driverProfileKey(phone)));
    clientIds.forEach((id) => pipeline.get(this.clientProfileKey(id)));
    const res = await pipeline.exec();
    const driverProfiles = new Map<string, any>();
    const clientProfiles = new Map<string, any>();
    driverPhones.forEach((phone, idx) => {
      const raw = typeof res?.[idx]?.[1] === 'string' ? (res?.[idx]?.[1] as string) : null;
      if (!raw) return;
      try {
        driverProfiles.set(phone, JSON.parse(raw));
      } catch {}
    });
    clientIds.forEach((id, idx) => {
      const raw = typeof res?.[driverPhones.length + idx]?.[1] === 'string' ? (res?.[driverPhones.length + idx]?.[1] as string) : null;
      if (!raw) return;
      try {
        clientProfiles.set(id, JSON.parse(raw));
      } catch {}
    });
    const enriched = orders.map((order) => {
      const driverProfile = order.driverPhone ? driverProfiles.get(order.driverPhone) : null;
      const clientProfile = order.clientId ? clientProfiles.get(order.clientId) : null;
      return {
        ...order,
        driverName: driverProfile?.fullName || '',
        driverPhone: order.driverPhone || driverProfile?.phone || '',
        clientName: clientProfile?.fullName || clientProfile?.name || '',
        clientPhone: clientProfile?.phone || order.clientId || '',
      };
    });
    return { ok: true, orders: enriched };
  }
}
