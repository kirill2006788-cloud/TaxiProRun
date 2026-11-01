import {
  BadRequestException,
  Body,
  ConflictException,
  Controller,
  Get,
  Headers,
  Param,
  Post,
  Query,
  ServiceUnavailableException,
  UnauthorizedException,
} from '@nestjs/common';
import crypto from 'node:crypto';
import jwt from 'jsonwebtoken';
import { OrdersService } from './orders.service';
import { RedisService } from './redis.service';
import { PaymentAuditService } from './payments/audit.service';
import { EventsGateway } from './events.gateway';

type OnlinePaymentMethod = 'card' | 'sbp';

export type PaymentWebhookVerifier = (input: {
  signature: string | undefined;
  intentId: string;
  status: string;
  amount: number;
  rawBody?: string;
}) => boolean;

@Controller('payments')
export class PaymentsController {
  /** Hook: replace/extend signature verification for a real PSP. */
  private webhookVerifier: PaymentWebhookVerifier;

  constructor(
    private readonly orders: OrdersService,
    private readonly redis: RedisService,
    private readonly audit: PaymentAuditService,
    private readonly events: EventsGateway,
  ) {
    this.webhookVerifier = this.defaultHmacVerifier.bind(this);
  }

  /** Allow tests / future PSP adapters to plug a custom verifier. */
  setWebhookVerifier(fn: PaymentWebhookVerifier) {
    this.webhookVerifier = fn;
  }

  private enabled() {
    return Boolean(
      (process.env.PAYMENT_CHECKOUT_URL || '').trim() &&
        (process.env.PAYMENT_WEBHOOK_SECRET || '').trim(),
    );
  }

  private requireClientId(auth?: string) {
    const token = auth?.replace(/^Bearer\s+/i, '').trim();
    const secret = process.env.JWT_SECRET;
    if (!token || !secret) throw new UnauthorizedException('Client token required');
    try {
      const payload = jwt.verify(token, secret) as any;
      if (payload?.role !== 'client' || !payload?.phone) throw new Error('role');
      return String(payload.phone).trim();
    } catch {
      throw new UnauthorizedException('Invalid client token');
    }
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

  private intentKey(id: string) {
    return `payment:intent:${id}`;
  }

  private orderIntentKey(orderId: string) {
    return `payment:order_intent:${orderId}`;
  }

  private idempotencyKey(clientId: string, key: string) {
    return `payment:idem:${clientId}:${key}`;
  }

  private refundKey(id: string) {
    return `payment:refund:${id}`;
  }

  private receiptKey(id: string) {
    return `payment:receipt:${id}`;
  }

  private orderReceiptKey(orderId: string) {
    return `payment:order_receipt:${orderId}`;
  }

  private defaultHmacVerifier(input: {
    signature: string | undefined;
    intentId: string;
    status: string;
    amount: number;
  }): boolean {
    const secret = String(process.env.PAYMENT_WEBHOOK_SECRET || '');
    if (!secret) return false;
    const expected = crypto
      .createHmac('sha256', secret)
      .update(`${input.intentId}:${input.status}:${input.amount}`)
      .digest('hex');
    const supplied = String(input.signature || '').trim().toLowerCase();
    if (!supplied || supplied.length !== expected.length) return false;
    try {
      return crypto.timingSafeEqual(Buffer.from(supplied), Buffer.from(expected));
    } catch {
      return false;
    }
  }

  @Get('config')
  config() {
    const online = this.enabled();
    return {
      ok: true,
      methods: { cash: true, card: online, sbp: online },
      refundsEnabled: false,
      receiptsEnabled: true,
    };
  }

  @Post('intents')
  async createIntent(
    @Headers('authorization') auth: string | undefined,
    @Headers('idempotency-key') idempotencyHeader: string | undefined,
    @Body()
    body: { orderId?: string; method?: OnlinePaymentMethod; idempotencyKey?: string },
  ) {
    if (!this.enabled()) {
      throw new ServiceUnavailableException('Online acquiring is not configured');
    }
    const clientId = this.requireClientId(auth);
    const orderId = String(body?.orderId || '').trim();
    const method = body?.method;
    if (!orderId || (method !== 'card' && method !== 'sbp')) {
      throw new BadRequestException('orderId and payment method are required');
    }
    const idemRaw = String(idempotencyHeader || body?.idempotencyKey || '').trim();
    const idemKey = /^[a-zA-Z0-9_-]{8,128}$/.test(idemRaw) ? idemRaw : '';

    if (idemKey) {
      const existingIntentId = await this.redis.client.get(this.idempotencyKey(clientId, idemKey));
      if (existingIntentId) {
        const raw = await this.redis.client.get(this.intentKey(existingIntentId));
        if (raw) return { ok: true, intent: JSON.parse(raw), idempotentReplay: true };
      }
    }

    const order = await this.orders.getOrder(orderId);
    if (order.clientId !== clientId) throw new UnauthorizedException('Order access denied');
    if (order.paymentMethod !== method) throw new ConflictException('Payment method mismatch');
    if (order.paymentStatus === 'paid') throw new ConflictException('Order is already paid');

    const existingId = await this.redis.client.get(this.orderIntentKey(orderId));
    if (existingId) {
      const raw = await this.redis.client.get(this.intentKey(existingId));
      if (raw) return { ok: true, intent: JSON.parse(raw) };
    }

    const amount = Math.max(1, Math.round(Number(order.priceFinal || order.priceFrom || 0)));
    const id = crypto.randomUUID();
    const secret = String(process.env.PAYMENT_WEBHOOK_SECRET);
    const signature = crypto
      .createHmac('sha256', secret)
      .update(`${id}:${orderId}:${amount}:${method}`)
      .digest('hex');
    let checkout: URL;
    try {
      checkout = new URL(String(process.env.PAYMENT_CHECKOUT_URL));
    } catch {
      throw new ServiceUnavailableException('Invalid payment checkout URL');
    }
    if (checkout.protocol !== 'https:') {
      throw new ServiceUnavailableException('Payment checkout URL must use HTTPS');
    }
    checkout.searchParams.set('intent_id', id);
    checkout.searchParams.set('order_id', orderId);
    checkout.searchParams.set('amount', String(amount));
    checkout.searchParams.set('method', method);
    checkout.searchParams.set('signature', signature);
    const intent = {
      id,
      orderId,
      clientId,
      method,
      amount,
      status: 'pending',
      checkoutUrl: checkout.toString(),
      idempotencyKey: idemKey || undefined,
      createdAt: new Date().toISOString(),
    };
    const ttl = 60 * 60 * 24;
    const multi = this.redis.client.multi();
    multi.set(this.intentKey(id), JSON.stringify(intent), 'EX', ttl);
    multi.set(this.orderIntentKey(orderId), id, 'EX', ttl);
    if (idemKey) {
      multi.set(this.idempotencyKey(clientId, idemKey), id, 'EX', ttl);
    }
    await multi.exec();
    await this.orders.setPaymentStatus(orderId, 'pending');
    await this.audit.append('intent_created', {
      orderId,
      intentId: id,
      amount,
      actor: clientId,
      meta: { method, idempotencyKey: idemKey || null },
    });
    const updated = await this.orders.getOrder(orderId);
    this.events.emitPaymentStatus(updated);
    return { ok: true, intent };
  }

  /**
   * Webhook stub with pluggable signature verification.
   * Production PSP: set PAYMENT_WEBHOOK_SECRET and send
   * X-Payment-Signature = HMAC-SHA256(intentId:status:amount).
   */
  @Post('webhook')
  async webhook(
    @Headers('x-payment-signature') signature: string | undefined,
    @Headers('x-idempotency-key') webhookIdem: string | undefined,
    @Body() body: { intentId?: string; status?: string; amount?: number },
  ) {
    if (!this.enabled()) throw new ServiceUnavailableException('Online acquiring is not configured');
    const intentId = String(body?.intentId || '').trim();
    const status = String(body?.status || '').trim().toLowerCase();
    const amount = Math.round(Number(body?.amount || 0));
    if (!intentId || !['paid', 'failed'].includes(status)) {
      throw new BadRequestException('Invalid webhook payload');
    }

    const webhookIdemKey = String(webhookIdem || '').trim();
    if (webhookIdemKey && /^[a-zA-Z0-9_-]{8,128}$/.test(webhookIdemKey)) {
      const seen = await this.redis.client.get(`payment:webhook_idem:${webhookIdemKey}`);
      if (seen) return { ok: true, duplicate: true };
    }

    if (
      !this.webhookVerifier({
        signature,
        intentId,
        status,
        amount,
      })
    ) {
      throw new UnauthorizedException('Invalid payment signature');
    }

    const raw = await this.redis.client.get(this.intentKey(intentId));
    if (!raw) throw new BadRequestException('Payment intent not found');
    const intent = JSON.parse(raw) as Record<string, any>;
    if (amount !== Number(intent.amount)) throw new ConflictException('Payment amount mismatch');
    if (intent.status === 'paid') return { ok: true };

    intent.status = status;
    intent.updatedAt = new Date().toISOString();
    await this.redis.client.set(this.intentKey(intentId), JSON.stringify(intent), 'EX', 60 * 60 * 24 * 365);
    const order = await this.orders.setPaymentStatus(
      intent.orderId,
      status === 'paid' ? 'paid' : 'failed',
    );
    if (webhookIdemKey && /^[a-zA-Z0-9_-]{8,128}$/.test(webhookIdemKey)) {
      await this.redis.client.set(`payment:webhook_idem:${webhookIdemKey}`, '1', 'EX', 60 * 60 * 24 * 30);
    }
    await this.audit.append(status === 'paid' ? 'webhook_paid' : 'webhook_failed', {
      orderId: intent.orderId,
      intentId,
      amount,
      actor: 'webhook',
    });
    if (status === 'paid') {
      await this.issueReceiptInternal(order.id, amount, intentId);
    }
    this.events.emitPaymentStatus(order);
    return { ok: true };
  }

  @Post('refunds')
  async createRefund(
    @Headers('authorization') auth: string | undefined,
    @Headers('idempotency-key') idempotencyHeader: string | undefined,
    @Body() body: { orderId?: string; amount?: number; reason?: string },
  ) {
    this.requireAdmin(auth);
    throw new ServiceUnavailableException('Возвраты недоступны: провайдер возвратов ещё не подключён');
  }

  @Get('receipts/:orderId')
  async getReceipt(
    @Param('orderId') orderId: string,
    @Headers('authorization') auth: string | undefined,
  ) {
    const order = await this.orders.getOrder(orderId);
    const token = auth?.replace(/^Bearer\s+/i, '').trim();
    const secret = process.env.JWT_SECRET;
    if (!token || !secret) throw new UnauthorizedException('Authorization required');
    try {
      const payload = jwt.verify(token, secret) as any;
      if (payload?.role === 'client' && String(payload.phone || '').trim() !== order.clientId) {
        throw new UnauthorizedException('Access denied');
      }
      if (payload?.role === 'driver' && String(payload.phone || '').trim() !== order.driverPhone) {
        throw new UnauthorizedException('Access denied');
      }
      if (payload?.role !== 'client' && payload?.role !== 'driver' && payload?.role !== 'admin') {
        throw new UnauthorizedException('Access denied');
      }
    } catch (e) {
      if (e instanceof UnauthorizedException) throw e;
      throw new UnauthorizedException('Invalid token');
    }
    const receiptId = await this.redis.client.get(this.orderReceiptKey(orderId));
    if (!receiptId) throw new BadRequestException('Receipt not found');
    const raw = await this.redis.client.get(this.receiptKey(receiptId));
    if (!raw) throw new BadRequestException('Receipt not found');
    return { ok: true, receipt: JSON.parse(raw) };
  }

  @Post('receipts')
  async issueReceipt(
    @Headers('authorization') auth: string | undefined,
    @Body() body: { orderId?: string },
  ) {
    this.requireAdmin(auth);
    const orderId = String(body?.orderId || '').trim();
    if (!orderId) throw new BadRequestException('orderId is required');
    const order = await this.orders.getOrder(orderId);
    if (order.paymentStatus !== 'paid') {
      throw new ConflictException('Receipt requires paid order');
    }
    const amount = Math.max(1, Math.round(Number(order.priceFinal || order.priceFrom || 0)));
    const receipt = await this.issueReceiptInternal(orderId, amount);
    return { ok: true, receipt };
  }

  @Get('audit')
  async listAudit(
    @Headers('authorization') auth: string | undefined,
    @Query('limit') limitRaw?: string,
  ) {
    this.requireAdmin(auth);
    const limit = Math.min(200, Math.max(1, Number(limitRaw) || 50));
    const entries = await this.audit.list(limit);
    return { ok: true, entries };
  }

  private async issueReceiptInternal(orderId: string, amount: number, intentId?: string) {
    const existingId = await this.redis.client.get(this.orderReceiptKey(orderId));
    if (existingId) {
      const raw = await this.redis.client.get(this.receiptKey(existingId));
      if (raw) return JSON.parse(raw);
    }
    const id = crypto.randomUUID();
    const receipt = {
      id,
      orderId,
      intentId: intentId || undefined,
      amount,
      currency: 'RUB',
      fiscalProvider: process.env.FISCAL_PROVIDER || 'stub',
      // Stub fiscal number — replace when OFD/54-FZ provider is connected.
      fiscalDocumentNumber: `STUB-${id.slice(0, 8).toUpperCase()}`,
      issuedAt: new Date().toISOString(),
    };
    const ttl = 60 * 60 * 24 * 400;
    await this.redis.client
      .multi()
      .set(this.receiptKey(id), JSON.stringify(receipt), 'EX', ttl)
      .set(this.orderReceiptKey(orderId), id, 'EX', ttl)
      .exec();
    await this.audit.append('receipt_issued', {
      orderId,
      intentId,
      amount,
      actor: 'system',
      meta: { receiptId: id },
    });
    return receipt;
  }
}
