import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { readFileSync, existsSync } from 'fs';

import { RedisService } from './redis.service';
import type { Order } from './orders.service';

type PushTokenRecord = {
  token?: string;
  platform?: string;
};

@Injectable()
export class PushService implements OnModuleInit {
  private readonly logger = new Logger(PushService.name);
  private enabled = false;
  private messaging: { send: (msg: unknown) => Promise<string> } | null = null;

  constructor(private readonly redis: RedisService) {}

  onModuleInit() {
    this.tryInit();
  }

  get isEnabled() {
    return this.enabled;
  }

  private tryInit() {
    try {
      // Optional dependency — install firebase-admin on VPS when FCM key is added.
      // eslint-disable-next-line @typescript-eslint/no-var-requires
      const admin = require('firebase-admin') as {
        apps: { length: number };
        initializeApp: (opts: { credential: unknown }) => void;
        credential: { cert: (cred: Record<string, unknown>) => unknown };
        messaging: () => { send: (msg: unknown) => Promise<string> };
      };
      const jsonRaw = (process.env.FIREBASE_SERVICE_ACCOUNT_JSON || '').trim();
      const path = (process.env.FIREBASE_SERVICE_ACCOUNT_PATH || '').trim();
      let cred: Record<string, unknown> | null = null;

      if (jsonRaw) {
        cred = JSON.parse(jsonRaw);
      } else if (path && existsSync(path)) {
        cred = JSON.parse(readFileSync(path, 'utf8'));
      }

      if (!cred) {
        this.logger.log('FCM disabled — no FIREBASE_SERVICE_ACCOUNT_JSON / PATH');
        return;
      }

      if (!admin.apps.length) {
        admin.initializeApp({ credential: admin.credential.cert(cred) });
      }
      this.messaging = admin.messaging();
      this.enabled = true;
      this.logger.log('FCM push enabled');
    } catch (err) {
      this.logger.warn(`FCM disabled: ${err}`);
    }
  }

  private isDeliverableToken(token: string) {
    const trimmed = token.trim();
    return trimmed.length > 20 && !trimmed.startsWith('local-');
  }

  private async readToken(key: string) {
    try {
      const raw = await this.redis.client.get(key);
      if (!raw) return null;
      const parsed = JSON.parse(raw) as PushTokenRecord;
      const token = String(parsed?.token || '').trim();
      return this.isDeliverableToken(token) ? token : null;
    } catch {
      return null;
    }
  }

  private driverTokenKey(phone: string) {
    return `driver:push_token:${phone}`;
  }

  private clientTokenKey(clientId: string) {
    return `client:push_token:${clientId}`;
  }

  private isPermanentTokenError(error: unknown) {
    const code = String((error as { code?: string })?.code || '');
    return code === 'messaging/registration-token-not-registered' ||
      code === 'messaging/invalid-registration-token';
  }

  private async send(
    tokenKey: string,
    token: string,
    title: string,
    body: string,
    data: Record<string, string>,
  ) {
    if (!this.enabled || !this.messaging || !this.isDeliverableToken(token)) return;
    try {
      await this.messaging.send({
        token,
        notification: { title, body },
        data,
        android: { priority: 'high' },
        apns: { payload: { aps: { sound: 'default' } } },
      });
    } catch (err) {
      if (this.isPermanentTokenError(err)) {
        await this.redis.client.del(tokenKey);
        this.logger.warn('Removed an invalid FCM registration token');
        return;
      }
      this.logger.warn(`FCM send failed: ${err}`);
    }
  }

  async notifyDriversNewOrder(order: Order, driverPhones: string[]) {
    if (!this.enabled || !driverPhones.length) return;
    const from = String(order.fromAddress || 'Откуда');
    const to = String(order.toAddress || 'Куда');
    const pricePart = order.priceFrom ? ` · ${Math.round(Number(order.priceFrom))} ₽` : '';
    const title = `Новый заказ${pricePart}`;
    const body = `${from} → ${to}`;
    const data = {
      type: 'order:new',
      orderId: String(order.id),
      fromAddress: from,
      toAddress: to,
      price: order.priceFrom != null ? String(order.priceFrom) : '',
    };

    const unique = [...new Set(driverPhones.map((p) => String(p || '').trim()).filter(Boolean))];
    await Promise.all(
      unique.map(async (phone) => {
        const tokenKey = this.driverTokenKey(phone);
        const token = await this.readToken(tokenKey);
        if (token) await this.send(tokenKey, token, title, body, data);
      }),
    );
  }

  async notifyClientOrderStatus(order: Order) {
    if (!this.enabled) return;
    const clientId = String(order.clientId || '').trim();
    if (!clientId) return;

    const status = String(order.status || '').toLowerCase();
    let title = '';
    let body = '';
    if (status === 'accepted') {
      title = 'Заказ принят';
      body = 'Водитель назначен на ваш заказ';
    } else if (status === 'enroute') {
      title = 'Водитель в пути';
      body = 'Водитель выехал к вам';
    } else if (status === 'arrived' || status === 'waiting') {
      title = 'Водитель на месте';
      body = status === 'waiting' ? 'Ожидание в точке посадки' : 'Автомобиль прибыл к точке посадки';
    } else if (status === 'started') {
      title = 'Поездка началась';
      body = 'Приятной дороги!';
    } else if (status === 'completed') {
      title = 'Поездка завершена';
      body = 'Спасибо, что выбрали КОРОЛИ ДОРОГ';
    } else if (status === 'canceled') {
      title = 'Заказ отменён';
      body = String(order.cancelReason || 'Заказ был отменён');
    } else {
      return;
    }

    const tokenKey = this.clientTokenKey(clientId);
    const token = await this.readToken(tokenKey);
    if (!token) return;

    await this.send(tokenKey, token, title, body, {
      type: 'order:status',
      orderId: String(order.id),
      status,
    });
  }

  /** Push for in-trip chat when the peer app may be backgrounded. */
  async notifyChatMessage(order: Order, message: Record<string, unknown>) {
    if (!this.enabled) return;
    const senderRole = String(message['senderRole'] || '');
    const text = String(message['text'] || '').trim().slice(0, 120);
    if (!text) return;
    const title = 'Новое сообщение';
    const data = {
      type: 'order:chat',
      orderId: String(order.id),
      role: senderRole,
    };
    if (senderRole === 'client' && order.driverPhone) {
      const tokenKey = this.driverTokenKey(order.driverPhone);
      const token = await this.readToken(tokenKey);
      if (token) await this.send(tokenKey, token, title, text, data);
    } else if (senderRole === 'driver' && order.clientId) {
      const tokenKey = this.clientTokenKey(order.clientId);
      const token = await this.readToken(tokenKey);
      if (token) await this.send(tokenKey, token, title, text, data);
    }
  }
}
