import { Body, Controller, Delete, Get, Headers, Param, Post, Query, UnauthorizedException } from '@nestjs/common';
import jwt from 'jsonwebtoken';
import { RedisService } from './redis.service';
import { EventsGateway } from './events.gateway';

export type BroadcastType = 'maintenance' | 'update' | 'news' | 'alert';
export type BroadcastAudience = 'all' | 'clients' | 'drivers';

export type Broadcast = {
  id: string;
  title: string;
  body: string;
  type: BroadcastType;
  audience: BroadcastAudience;
  active: boolean;
  startsAt: string | null;
  endsAt: string | null;
  createdAt: string;
  createdBy?: string;
};

@Controller()
export class BroadcastsController {
  constructor(
    private readonly redis: RedisService,
    private readonly events: EventsGateway,
  ) {}

  private listKey() {
    return 'broadcasts:list';
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

  private async readAll(): Promise<Broadcast[]> {
    const raw = await this.redis.client.get(this.listKey());
    if (!raw) return [];
    try {
      const list = JSON.parse(raw);
      return Array.isArray(list) ? list : [];
    } catch {
      return [];
    }
  }

  private async writeAll(list: Broadcast[]) {
    await this.redis.client.set(this.listKey(), JSON.stringify(list.slice(0, 200)));
  }

  private isActiveNow(b: Broadcast, now = Date.now()) {
    if (!b.active) return false;
    if (b.startsAt) {
      const t = Date.parse(b.startsAt);
      if (!Number.isNaN(t) && t > now) return false;
    }
    if (b.endsAt) {
      const t = Date.parse(b.endsAt);
      if (!Number.isNaN(t) && t < now) return false;
    }
    return true;
  }

  private matchesAudience(b: Broadcast, audience?: string) {
    if (!audience || audience === 'all') return true;
    if (b.audience === 'all') return true;
    return b.audience === audience;
  }

  /** Apps: active broadcasts */
  @Get('broadcasts/active')
  async active(@Query('audience') audience?: string) {
    const now = Date.now();
    const list = await this.readAll();
    const items = list
      .filter((b) => this.isActiveNow(b, now) && this.matchesAudience(b, audience))
      .sort((a, b) => Date.parse(b.createdAt) - Date.parse(a.createdAt));
    return { ok: true, broadcasts: items };
  }

  /** Admin: all broadcasts */
  @Get('admin/broadcasts')
  async list(@Headers('authorization') auth?: string) {
    this.requireAdmin(auth);
    const list = await this.readAll();
    list.sort((a, b) => Date.parse(b.createdAt) - Date.parse(a.createdAt));
    return { ok: true, broadcasts: list };
  }

  /** Admin: create & optionally push live */
  @Post('admin/broadcasts')
  async create(
    @Body()
    body: {
      title?: string;
      body?: string;
      type?: BroadcastType;
      audience?: BroadcastAudience;
      startsAt?: string | null;
      endsAt?: string | null;
      active?: boolean;
      pushLive?: boolean;
    },
    @Headers('authorization') auth?: string,
  ) {
    const admin = this.requireAdmin(auth);
    const title = String(body?.title || '').trim();
    const text = String(body?.body || '').trim();
    if (!title || !text) return { ok: false, error: 'title and body required' };

    const type = (['maintenance', 'update', 'news', 'alert'].includes(String(body?.type))
      ? body.type
      : 'news') as BroadcastType;
    const audience = (['all', 'clients', 'drivers'].includes(String(body?.audience))
      ? body.audience
      : 'all') as BroadcastAudience;

    const item: Broadcast = {
      id: `bc_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
      title,
      body: text,
      type,
      audience,
      active: body?.active !== false,
      startsAt: body?.startsAt || null,
      endsAt: body?.endsAt || null,
      createdAt: new Date().toISOString(),
      createdBy: admin?.login || 'admin',
    };

    const list = await this.readAll();
    list.unshift(item);
    await this.writeAll(list);

    if (body?.pushLive !== false && this.isActiveNow(item)) {
      try {
        this.events.emitBroadcast(item);
      } catch {
        /* socket optional */
      }
    }

    return { ok: true, broadcast: item };
  }

  @Post('admin/broadcasts/:id/deactivate')
  async deactivate(@Param('id') id: string, @Headers('authorization') auth?: string) {
    this.requireAdmin(auth);
    const list = await this.readAll();
    const idx = list.findIndex((b) => b.id === id);
    if (idx < 0) return { ok: false, error: 'not found' };
    list[idx] = { ...list[idx], active: false };
    await this.writeAll(list);
    try {
      this.events.emitBroadcastDeactivated(list[idx]);
    } catch {
      /* ignore */
    }
    return { ok: true, broadcast: list[idx] };
  }

  @Delete('admin/broadcasts/:id')
  async remove(@Param('id') id: string, @Headers('authorization') auth?: string) {
    this.requireAdmin(auth);
    const list = await this.readAll();
    const next = list.filter((b) => b.id !== id);
    await this.writeAll(next);
    return { ok: true };
  }
}
