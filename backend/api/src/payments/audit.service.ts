import { Injectable, Logger } from '@nestjs/common';
import crypto from 'node:crypto';
import { RedisService } from '../redis.service';

export type MoneyAuditAction =
  | 'intent_created'
  | 'webhook_paid'
  | 'webhook_failed'
  | 'mark_paid'
  | 'refund_created'
  | 'refund_completed'
  | 'receipt_issued'
  | 'payout_created';

export type MoneyAuditEntry = {
  id: string;
  action: MoneyAuditAction;
  orderId?: string;
  intentId?: string;
  refundId?: string;
  amount?: number;
  currency?: string;
  actor?: string;
  meta?: Record<string, unknown>;
  at: string;
};

@Injectable()
export class PaymentAuditService {
  private readonly logger = new Logger(PaymentAuditService.name);

  constructor(private readonly redis: RedisService) {}

  private listKey() {
    return 'payments:audit';
  }

  private entryKey(id: string) {
    return `payments:audit:${id}`;
  }

  async append(
    action: MoneyAuditAction,
    data: Omit<MoneyAuditEntry, 'id' | 'action' | 'at'> & { at?: string },
  ): Promise<MoneyAuditEntry> {
    const entry: MoneyAuditEntry = {
      id: crypto.randomUUID(),
      action,
      orderId: data.orderId,
      intentId: data.intentId,
      refundId: data.refundId,
      amount: data.amount,
      currency: data.currency || 'RUB',
      actor: data.actor,
      meta: data.meta,
      at: data.at || new Date().toISOString(),
    };
    try {
      const multi = this.redis.client.multi();
      multi.set(this.entryKey(entry.id), JSON.stringify(entry), 'EX', 60 * 60 * 24 * 400);
      multi.lpush(this.listKey(), entry.id);
      multi.ltrim(this.listKey(), 0, 4999);
      await multi.exec();
    } catch (err) {
      this.logger.warn(`audit persist failed: ${err}`);
    }
    this.logger.log(
      JSON.stringify({
        type: 'money_audit',
        ...entry,
      }),
    );
    return entry;
  }

  async list(limit = 50): Promise<MoneyAuditEntry[]> {
    const ids = await this.redis.client.lrange(this.listKey(), 0, Math.max(0, limit - 1));
    if (!ids.length) return [];
    const raws = await this.redis.client.mget(ids.map((id) => this.entryKey(id)));
    return raws
      .filter((r): r is string => typeof r === 'string')
      .map((r) => JSON.parse(r) as MoneyAuditEntry);
  }
}
