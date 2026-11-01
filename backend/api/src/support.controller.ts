import {
  Body,
  Controller,
  Get,
  Headers,
  Param,
  Post,
  UnauthorizedException,
} from '@nestjs/common';
import jwt from 'jsonwebtoken';
import { RedisService } from './redis.service';

export type TicketStatus = 'open' | 'replied' | 'closed';
export type TicketAuthorRole = 'client' | 'driver';

export type TicketMessage = {
  id: string;
  from: 'user' | 'admin';
  body: string;
  createdAt: string;
  author?: string;
};

export type SupportTicket = {
  id: string;
  subject: string;
  body: string;
  status: TicketStatus;
  authorRole: TicketAuthorRole;
  authorPhone: string;
  authorName?: string;
  createdAt: string;
  updatedAt: string;
  messages: TicketMessage[];
};

@Controller()
export class SupportController {
  constructor(private readonly redis: RedisService) {}

  private listKey() {
    return 'support:tickets';
  }

  private requireUser(authHeader?: string): { phone: string; role: TicketAuthorRole } {
    const token = authHeader?.replace(/^Bearer\s+/i, '').trim();
    if (!token) throw new UnauthorizedException('Authorization required');
    const secret = process.env.JWT_SECRET;
    if (!secret) throw new UnauthorizedException('Server configuration error');
    let payload: any;
    try {
      payload = jwt.verify(token, secret) as any;
    } catch {
      throw new UnauthorizedException('Invalid token');
    }
    const role = payload?.role === 'driver' ? 'driver' : payload?.role === 'client' ? 'client' : null;
    const phone = typeof payload?.phone === 'string' ? payload.phone.trim() : '';
    if (!role || !phone) throw new UnauthorizedException('Client or driver token required');
    return { phone, role };
  }

  private requireAdmin(authHeader?: string) {
    const token = authHeader?.replace(/^Bearer\s+/i, '').trim();
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

  private async readAll(): Promise<SupportTicket[]> {
    const raw = await this.redis.client.get(this.listKey());
    if (!raw) return [];
    try {
      const list = JSON.parse(raw);
      return Array.isArray(list) ? list : [];
    } catch {
      return [];
    }
  }

  private async writeAll(list: SupportTicket[]) {
    await this.redis.client.set(this.listKey(), JSON.stringify(list.slice(0, 500)));
  }

  private async resolveAuthorName(role: TicketAuthorRole, phone: string): Promise<string> {
    const key = role === 'driver' ? `driver:profile:${phone}` : `client:profile:${phone}`;
    const raw = await this.redis.client.get(key);
    if (!raw) return '';
    try {
      const p = JSON.parse(raw);
      return String(p?.fullName || p?.name || '').trim();
    } catch {
      return '';
    }
  }

  /** Client / driver: create ticket */
  @Post('support/tickets')
  async create(
    @Body() body: { subject?: string; body?: string; message?: string },
    @Headers('authorization') auth?: string,
  ) {
    const user = this.requireUser(auth);
    const subject = String(body?.subject || '').trim().slice(0, 120);
    const text = String(body?.body || body?.message || '').trim().slice(0, 4000);
    if (!subject || !text) return { ok: false, error: 'subject and body required' };

    const now = new Date().toISOString();
    const authorName = await this.resolveAuthorName(user.role, user.phone);
    const ticket: SupportTicket = {
      id: `st_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
      subject,
      body: text,
      status: 'open',
      authorRole: user.role,
      authorPhone: user.phone,
      authorName: authorName || undefined,
      createdAt: now,
      updatedAt: now,
      messages: [
        {
          id: `sm_${Date.now()}`,
          from: 'user',
          body: text,
          createdAt: now,
          author: authorName || user.phone,
        },
      ],
    };

    const list = await this.readAll();
    list.unshift(ticket);
    await this.writeAll(list);
    return { ok: true, ticket };
  }

  /** Client / driver: own tickets */
  @Get('support/tickets/mine')
  async mine(@Headers('authorization') auth?: string) {
    const user = this.requireUser(auth);
    const list = await this.readAll();
    const tickets = list
      .filter((t) => t.authorPhone === user.phone && t.authorRole === user.role)
      .sort((a, b) => Date.parse(b.updatedAt) - Date.parse(a.updatedAt));
    return { ok: true, tickets };
  }

  /** Admin: list */
  @Get('admin/support/tickets')
  async list(@Headers('authorization') auth?: string) {
    this.requireAdmin(auth);
    const list = await this.readAll();
    list.sort((a, b) => Date.parse(b.updatedAt) - Date.parse(a.updatedAt));
    return { ok: true, tickets: list };
  }

  /** Admin: reply */
  @Post('admin/support/tickets/:id/reply')
  async reply(
    @Param('id') id: string,
    @Body() body: { body?: string; message?: string },
    @Headers('authorization') auth?: string,
  ) {
    const admin = this.requireAdmin(auth);
    const text = String(body?.body || body?.message || '').trim().slice(0, 4000);
    if (!text) return { ok: false, error: 'body required' };

    const list = await this.readAll();
    const idx = list.findIndex((t) => t.id === id);
    if (idx < 0) return { ok: false, error: 'not found' };

    const now = new Date().toISOString();
    const ticket = list[idx];
    ticket.messages = ticket.messages || [];
    ticket.messages.push({
      id: `sm_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`,
      from: 'admin',
      body: text,
      createdAt: now,
      author: admin?.login || 'admin',
    });
    if (ticket.status !== 'closed') ticket.status = 'replied';
    ticket.updatedAt = now;
    list[idx] = ticket;
    await this.writeAll(list);
    return { ok: true, ticket };
  }

  /** Admin: close */
  @Post('admin/support/tickets/:id/close')
  async close(@Param('id') id: string, @Headers('authorization') auth?: string) {
    this.requireAdmin(auth);
    const list = await this.readAll();
    const idx = list.findIndex((t) => t.id === id);
    if (idx < 0) return { ok: false, error: 'not found' };
    list[idx] = {
      ...list[idx],
      status: 'closed',
      updatedAt: new Date().toISOString(),
    };
    await this.writeAll(list);
    return { ok: true, ticket: list[idx] };
  }

  /** Admin: convenience POST on collection (reply/close by action) */
  @Post('admin/support/tickets')
  async adminAction(
    @Body()
    body: {
      action?: 'reply' | 'close';
      id?: string;
      body?: string;
      message?: string;
    },
    @Headers('authorization') auth?: string,
  ) {
    const action = String(body?.action || '').trim();
    const id = String(body?.id || '').trim();
    if (!id) return { ok: false, error: 'id required' };
    if (action === 'close') return this.close(id, auth);
    if (action === 'reply') {
      return this.reply(id, { body: body?.body, message: body?.message }, auth);
    }
    return { ok: false, error: 'action must be reply or close' };
  }
}
