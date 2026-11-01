import { Injectable } from '@nestjs/common';
import { RedisService } from './redis.service';

export type DriverStatus = 'online' | 'offline' | 'busy';

@Injectable()
export class DriversService {
  constructor(private readonly redis: RedisService) {}

  private geoKey() {
    return 'drivers:geo';
  }

  private statusKey() {
    return 'drivers:status';
  }

  private allKey() {
    return 'drivers:all';
  }

  private onlineKey(phone: string) {
    return `driver:online:${phone}`;
  }

  private locKey(phone: string) {
    return `driver:loc:${phone}`;
  }

  private profileKey(phone: string) {
    return `driver:profile:${phone}`;
  }

  profileLiteKey(phone: string) {
    return `driver:profile_lite:${phone}`;
  }

  buildProfileLite(profile: Record<string, unknown>) {
    const p = profile || {};
    const hasVerificationPhotos = !!(
      p.passportFrontBase64 ||
      p.passportRegBase64 ||
      p.driverLicenseBackBase64 ||
      p.selfieBase64
    );
    return {
      phone: p.phone,
      fullName: p.fullName,
      email: p.email,
      rating: p.rating,
      inn: p.inn,
      passport: p.passport,
      docsSigned: p.docsSigned,
      registrationStatus: p.registrationStatus,
      referralCount: p.referralCount,
      updatedAt: p.updatedAt,
      hasVerificationPhotos: p.hasVerificationPhotos === true || hasVerificationPhotos,
      hasAvatar: p.hasAvatar === true || !!(p.avatarBase64 || p.selfieBase64),
      hasCarPhoto: p.hasCarPhoto === true || !!p.carPhotoBase64,
      hasPassportPhoto: p.hasPassportPhoto === true || !!p.passportFrontBase64,
      hasSelfiePhoto: p.hasSelfiePhoto === true || !!p.selfieBase64,
      hasDriverLicensePhoto: p.hasDriverLicensePhoto === true || !!p.driverLicenseBackBase64,
      hasStsPhoto: p.hasStsPhoto === true || !!p.stsBase64,
      hasOsagoPhoto: p.hasOsagoPhoto === true || !!p.osagoBase64,
      hasSignaturePhoto: p.hasSignaturePhoto === true || !!p.signatureBase64,
      birthDate: p.birthDate,
      carModel: p.carModel,
      carColor: p.carColor,
      carPlate: p.carPlate,
      servedClasses: p.servedClasses,
    };
  }

  async rebuildProfileLites(phones: string[]) {
    const map = new Map<string, Record<string, unknown>>();
    if (!phones.length) return map;
    const pipe = this.redis.client.pipeline();
    phones.forEach((p) => pipe.get(this.profileKey(p)));
    const res = await pipe.exec();
    const writePipe = this.redis.client.pipeline();
    phones.forEach((phone, idx) => {
      const raw = res?.[idx]?.[1];
      if (typeof raw !== 'string') return;
      try {
        const full = JSON.parse(raw) as Record<string, unknown>;
        const lite = this.buildProfileLite(full);
        map.set(phone, lite);
        writePipe.set(this.profileLiteKey(phone), JSON.stringify(lite));
      } catch {
        // skip corrupted profile
      }
    });
    await writePipe.exec();
    return map;
  }

  private bonusKey(phone: string) {
    return `driver:bonus:${phone}`;
  }

  private ratingKey(phone: string) {
    return `driver:rating:${phone}`;
  }

  private blockKey(phone: string) {
    return `driver:block:${phone}`;
  }

  private blockMetaKey(phone: string) {
    return `driver:block_meta:${phone}`;
  }

  private missedOrdersKey(phone: string) {
    return `driver:missed_orders:${phone}`;
  }

  private subscriptionPaidUntilKey(phone: string) {
    return `driver:sub:paid_until:${phone}`;
  }

  private subscriptionSettingsKey() {
    return 'settings:subscription';
  }

  private orderAcceptTimeoutKey() {
    return 'settings:order_accept_timeout_sec';
  }

  private antifraudSettingsKey() {
    return 'settings:antifraud';
  }

  private declinesDayKey(phone: string, day: string) {
    return `driver:declines:day:${phone}:${day}`;
  }

  private todayUtc(): string {
    return new Date().toISOString().slice(0, 10);
  }

  private secondsUntilUtcMidnight(): number {
    const now = new Date();
    const next = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + 1));
    return Math.max(60, Math.ceil((next.getTime() - now.getTime()) / 1000));
  }

  private static readonly ORDER_ACCEPT_TIMEOUT_OPTIONS = [5, 10, 15, 25, 30] as const;

  async getOrderAcceptTimeoutSec(): Promise<number> {
    const raw = await this.redis.client.get(this.orderAcceptTimeoutKey());
    const parsed = Number(raw);
    if (DriversService.ORDER_ACCEPT_TIMEOUT_OPTIONS.includes(parsed as 5 | 10 | 15 | 25 | 30)) {
      return parsed;
    }
    return 10;
  }

  async setOrderAcceptTimeoutSec(sec: number) {
    const rounded = Math.round(Number(sec));
    if (!DriversService.ORDER_ACCEPT_TIMEOUT_OPTIONS.includes(rounded as 5 | 10 | 15 | 25 | 30)) {
      throw new Error('order accept timeout must be 5, 10, 15, 25 or 30 seconds');
    }
    await this.redis.client.set(this.orderAcceptTimeoutKey(), String(rounded));
  }

  async getAntifraudSettings(): Promise<{
    maxDeclinesPerDay: number;
    autoBlockAfterSkips: number;
    blockHours: number;
  }> {
    const defaults = { maxDeclinesPerDay: 20, autoBlockAfterSkips: 3, blockHours: 48 };
    const raw = await this.redis.client.get(this.antifraudSettingsKey());
    if (!raw) return defaults;
    try {
      const o = JSON.parse(raw) as Record<string, unknown>;
      const maxDeclinesPerDay = Number.isFinite(Number(o?.maxDeclinesPerDay))
        ? Math.max(1, Math.min(500, Math.round(Number(o.maxDeclinesPerDay))))
        : defaults.maxDeclinesPerDay;
      const autoBlockAfterSkips = Number.isFinite(Number(o?.autoBlockAfterSkips))
        ? Math.max(1, Math.min(50, Math.round(Number(o.autoBlockAfterSkips))))
        : defaults.autoBlockAfterSkips;
      const blockHours = Number.isFinite(Number(o?.blockHours))
        ? Math.max(1, Math.min(168, Math.round(Number(o.blockHours))))
        : defaults.blockHours;
      return { maxDeclinesPerDay, autoBlockAfterSkips, blockHours };
    } catch {
      return defaults;
    }
  }

  async setAntifraudSettings(input: {
    maxDeclinesPerDay?: number;
    autoBlockAfterSkips?: number;
    blockHours?: number;
  }) {
    const current = await this.getAntifraudSettings();
    const next = {
      maxDeclinesPerDay: Number.isFinite(Number(input?.maxDeclinesPerDay))
        ? Math.max(1, Math.min(500, Math.round(Number(input.maxDeclinesPerDay))))
        : current.maxDeclinesPerDay,
      autoBlockAfterSkips: Number.isFinite(Number(input?.autoBlockAfterSkips))
        ? Math.max(1, Math.min(50, Math.round(Number(input.autoBlockAfterSkips))))
        : current.autoBlockAfterSkips,
      blockHours: Number.isFinite(Number(input?.blockHours))
        ? Math.max(1, Math.min(168, Math.round(Number(input.blockHours))))
        : current.blockHours,
    };
    await this.redis.client.set(this.antifraudSettingsKey(), JSON.stringify(next));
    return next;
  }

  async getSubscriptionSettings(): Promise<{ amount: number; dayOfMonth: number }> {
    const raw = await this.redis.client.get(this.subscriptionSettingsKey());
    if (raw) {
      try {
        const o = JSON.parse(raw) as { amount?: number; dayOfMonth?: number };
        const amount = Number.isFinite(Number(o?.amount)) ? Math.max(0, Math.round(Number(o.amount))) : 1500;
        const day = Number.isFinite(Number(o?.dayOfMonth)) ? Math.max(1, Math.min(28, Math.round(Number(o.dayOfMonth)))) : 5;
        return { amount, dayOfMonth: day };
      } catch {
        return { amount: 1500, dayOfMonth: 5 };
      }
    }
    return { amount: 1500, dayOfMonth: 5 };
  }

  async setSubscriptionSettings(amount: number, dayOfMonth: number) {
    await this.redis.client.set(
      this.subscriptionSettingsKey(),
      JSON.stringify({
        amount: Math.max(0, Math.round(amount)),
        dayOfMonth: Math.max(1, Math.min(28, Math.round(dayOfMonth))),
      }),
    );
  }

  getNextDueDate(dayOfMonth: number): string {
    const now = new Date();
    let d = new Date(now.getFullYear(), now.getMonth(), dayOfMonth);
    if (d <= now) d = new Date(now.getFullYear(), now.getMonth() + 1, dayOfMonth);
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${y}-${m}-${day}`;
  }

  getCurrentPeriodDueDate(dayOfMonth: number): string {
    const now = new Date();
    const d = new Date(now.getFullYear(), now.getMonth(), dayOfMonth);
    if (d > now) {
      const prev = new Date(now.getFullYear(), now.getMonth() - 1, dayOfMonth);
      const y = prev.getFullYear();
      const m = String(prev.getMonth() + 1).padStart(2, '0');
      const day = String(prev.getDate()).padStart(2, '0');
      return `${y}-${m}-${day}`;
    }
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${y}-${m}-${day}`;
  }

  async getSubscriptionPaidUntil(phone: string): Promise<string | null> {
    const raw = await this.redis.client.get(this.subscriptionPaidUntilKey(phone));
    return raw && /^\d{4}-\d{2}-\d{2}$/.test(raw) ? raw : null;
  }

  async setSubscriptionPaidUntil(phone: string, dateStr: string) {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(dateStr)) return;
    await this.redis.client.set(this.subscriptionPaidUntilKey(phone), dateStr);
  }

  async isSubscriptionOverdue(phone: string): Promise<boolean> {
    const settings = await this.getSubscriptionSettings();
    const due = this.getCurrentPeriodDueDate(settings.dayOfMonth);
    const paidUntil = await this.getSubscriptionPaidUntil(phone);
    if (!paidUntil) return true;
    return paidUntil < due;
  }

  async setStatus(phone: string, status: DriverStatus) {
    const pipeline = this.redis.client.pipeline();
    pipeline.hset(this.statusKey(), phone, status);
    pipeline.sadd(this.allKey(), phone);
    if (status === 'online') {
      pipeline.set(this.onlineKey(phone), '1', 'EX', 120);
    }
    if (status === 'offline' || status === 'busy') {
      pipeline.del(this.onlineKey(phone));
    }
    await pipeline.exec();
  }

  async updateLocation(
    phone: string,
    lat: number,
    lng: number,
    meta?: { accuracyMeters?: number; recordedAt?: string },
  ): Promise<boolean> {
    const currentStatus = await this.redis.client.hget(this.statusKey(), phone);
    // Запоздалый GPS-пакет после ручного offline не должен самовольно
    // возвращать водителя на линию.
    if (currentStatus !== 'online' && currentStatus !== 'busy') return false;

    const pipeline = this.redis.client.pipeline();
    pipeline.geoadd(this.geoKey(), lng, lat, phone);
    pipeline.set(
      this.locKey(phone),
      JSON.stringify({
        lat,
        lng,
        updatedAt: new Date().toISOString(),
        ...(Number.isFinite(meta?.accuracyMeters)
          ? { accuracyMeters: Number(meta?.accuracyMeters) }
          : {}),
        ...(meta?.recordedAt ? { recordedAt: meta.recordedAt } : {}),
      }),
      'EX',
      120,
    );
    pipeline.sadd(this.allKey(), phone);
    if (currentStatus === 'online') {
      pipeline.set(this.onlineKey(phone), '1', 'EX', 120);
    }
    await pipeline.exec();
    return true;
  }

  async getNearbyDrivers(lat: number, lng: number, radiusMeters: number, limit = 100) {
    const phones = await this.redis.client.georadius(
      this.geoKey(),
      lng,
      lat,
      radiusMeters,
      'm',
      'WITHDIST',
      'ASC',
      'COUNT',
      limit,
    );
    if (!phones.length) return [];

    const onlyPhones = (phones as Array<[string, string]>).map((p: [string, string]) => p[0]);
    const pipeline = this.redis.client.pipeline();
    onlyPhones.forEach((p) => pipeline.exists(this.onlineKey(p)));
    onlyPhones.forEach((p) => pipeline.exists(this.blockKey(p)));
    const results = await pipeline.exec();
    const online = new Set<string>();
    results?.slice(0, onlyPhones.length).forEach(([, res], idx) => {
      if (res === 1) online.add(onlyPhones[idx]);
    });
    const blocked = new Set<string>();
    results?.slice(onlyPhones.length).forEach(([, res], idx) => {
      if (res === 1) blocked.add(onlyPhones[idx]);
    });
    return onlyPhones.filter((p) => online.has(p) && !blocked.has(p));
  }

  /**
   * Filter drivers by tariff / service class from profile.servedClasses.
   * Empty servedClasses → driver accepts all (backward compatible).
   */
  async filterByTariffOrService(
    phones: string[],
    opts: { tariffId?: string; serviceIndex?: number; serviceType?: string },
  ): Promise<string[]> {
    if (!phones.length) return [];
    const tariffId = String(opts.tariffId || '').trim().toLowerCase();
    const serviceType = String(opts.serviceType || '').trim().toLowerCase();
    const serviceIndex =
      opts.serviceIndex != null && Number.isFinite(Number(opts.serviceIndex))
        ? Number(opts.serviceIndex)
        : null;
    if (!tariffId && !serviceType && serviceIndex == null) return phones;

    const needed = new Set<string>();
    if (tariffId) needed.add(tariffId);
    if (serviceType) needed.add(serviceType);
    if (serviceIndex != null) {
      needed.add(String(serviceIndex));
      // Common class aliases used in driver app registration.
      const aliases = ['economy', 'comfort', 'business', 'minivan', 'trezvy', 'personal', 'peregon'];
      if (serviceIndex >= 0 && serviceIndex < aliases.length) {
        needed.add(aliases[serviceIndex]);
      }
    }

    const pipeline = this.redis.client.pipeline();
    phones.forEach((p) => pipeline.get(this.profileLiteKey(p)));
    const results = await pipeline.exec();
    const matched: string[] = [];
    for (let i = 0; i < phones.length; i++) {
      const raw = results?.[i]?.[1];
      if (typeof raw !== 'string') {
        // No lite profile → allow (legacy drivers).
        matched.push(phones[i]);
        continue;
      }
      try {
        const lite = JSON.parse(raw) as { servedClasses?: unknown };
        const classes = Array.isArray(lite.servedClasses)
          ? lite.servedClasses.map((c) => String(c || '').trim().toLowerCase()).filter(Boolean)
          : [];
        if (!classes.length) {
          matched.push(phones[i]);
          continue;
        }
        const hit = classes.some((c) => needed.has(c));
        if (hit) matched.push(phones[i]);
      } catch {
        matched.push(phones[i]);
      }
    }
    return matched;
  }

  async listOnlineDrivers() {
    const phones = await this.redis.client.smembers(this.allKey());
    if (!phones.length) return [];
    const pipeline = this.redis.client.pipeline();
    phones.forEach((p) => pipeline.exists(this.onlineKey(p)));
    phones.forEach((p) => pipeline.exists(this.blockKey(p)));
    const results = await pipeline.exec();
    const online = new Set<string>();
    results?.slice(0, phones.length).forEach(([, res], idx) => {
      if (res === 1) online.add(phones[idx]);
    });
    const blocked = new Set<string>();
    results?.slice(phones.length).forEach(([, res], idx) => {
      if (res === 1) blocked.add(phones[idx]);
    });
    return phones.filter((p) => online.has(p) && !blocked.has(p));
  }

  async listDrivers() {
    return this.listDriversForAdmin({ withLocation: true });
  }

  /** Admin lists: skip geo unless explicitly needed — saves 1 Redis round-trip per driver. */
  async listDriversForAdmin(options?: { withLocation?: boolean; withBlockMeta?: boolean }) {
    const withLocation = options?.withLocation === true;
    const withBlockMeta = options?.withBlockMeta !== false;
    const phones = await this.redis.client.smembers(this.allKey());
    if (!phones.length) return [];
    const pipeline = this.redis.client.pipeline();
    phones.forEach((p) => pipeline.hget(this.statusKey(), p));
    if (withLocation) {
      phones.forEach((p) => pipeline.get(this.locKey(p)));
    }
    phones.forEach((p) => pipeline.exists(this.blockKey(p)));
    if (withBlockMeta) {
      phones.forEach((p) => pipeline.get(this.blockMetaKey(p)));
    }
    const results = await pipeline.exec();
    let offset = 0;
    const statuses = results?.slice(offset, offset + phones.length).map((r) => r?.[1]) || [];
    offset += phones.length;
    const locs = withLocation
      ? (results?.slice(offset, offset + phones.length).map((r) => r?.[1]) || [])
      : phones.map(() => null);
    if (withLocation) offset += phones.length;
    const blocks = results?.slice(offset, offset + phones.length).map((r) => r?.[1]) || [];
    offset += phones.length;
    const blockMetas = withBlockMeta
      ? (results?.slice(offset, offset + phones.length).map((r) => r?.[1]) || [])
      : phones.map(() => null);
    return phones.map((phone, idx) => {
      const locRaw = typeof locs[idx] === 'string' ? locs[idx] : null;
      const blockMetaRaw = typeof blockMetas[idx] === 'string' ? blockMetas[idx] : null;
      let blockMeta: any = null;
      try { if (blockMetaRaw) blockMeta = JSON.parse(blockMetaRaw); } catch { blockMeta = null; }
      let location: { lat: number; lng: number } | null = null;
      if (locRaw) {
        try { location = JSON.parse(locRaw); } catch { location = null; }
      }
      return {
        phone,
        status: (statuses[idx] as DriverStatus) || 'offline',
        location,
        blocked: blocks[idx] === 1,
        blockReason: blockMeta?.reason || null,
        blockUntil: blockMeta?.until || null,
      };
    });
  }

  async warmAllProfileLites() {
    const phones = await this.redis.client.smembers(this.allKey());
    return this.rebuildProfileLites(phones);
  }

  async isBlocked(phone: string): Promise<boolean> {
    const val = await this.redis.client.exists(this.blockKey(phone));
    return val === 1;
  }

  async getBlockMeta(phone: string): Promise<{ reason?: string; until?: string | null } | null> {
    const raw = await this.redis.client.get(this.blockMetaKey(phone));
    if (!raw) return null;
    try {
      const meta = JSON.parse(raw) as { reason?: string; until?: string | null };
      return {
        reason: typeof meta.reason === 'string' ? meta.reason : undefined,
        until: typeof meta.until === 'string' ? meta.until : null,
      };
    } catch {
      return null;
    }
  }

  async blockTemporarily(phone: string, reason: string, hours: number) {
    const ttlSec = Math.max(60, Math.round(hours * 60 * 60));
    const until = new Date(Date.now() + ttlSec * 1000).toISOString();
    await this.redis.client.set(this.blockKey(phone), '1', 'EX', ttlSec);
    await this.redis.client.set(
      this.blockMetaKey(phone),
      JSON.stringify({ reason, until }),
      'EX',
      ttlSec,
    );
    await this.setStatus(phone, 'offline');
  }

  async clearBlock(phone: string) {
    await this.redis.client.del(this.blockKey(phone));
    await this.redis.client.del(this.blockMetaKey(phone));
    await this.redis.client.del(this.missedOrdersKey(phone));
  }

  async registerMissedOrder(phone: string): Promise<{
    count: number;
    dayDeclines: number;
    blocked: boolean;
    until?: string;
    reason?: string;
  }> {
    const settings = await this.getAntifraudSettings();
    const day = this.todayUtc();
    const dayKey = this.declinesDayKey(phone, day);
    const dayDeclines = await this.redis.client.incr(dayKey);
    await this.redis.client.expire(dayKey, this.secondsUntilUtcMidnight());

    if (dayDeclines > settings.maxDeclinesPerDay) {
      await this.blockTemporarily(phone, 'max_declines_per_day', settings.blockHours);
      const meta = await this.getBlockMeta(phone);
      return {
        count: dayDeclines,
        dayDeclines,
        blocked: true,
        until: meta?.until || undefined,
        reason: 'max_declines_per_day',
      };
    }

    const key = this.missedOrdersKey(phone);
    const count = await this.redis.client.incr(key);
    await this.redis.client.expire(key, 60 * 60 * 48);
    if (count >= settings.autoBlockAfterSkips) {
      await this.blockTemporarily(phone, 'missed_orders', settings.blockHours);
      await this.redis.client.del(key);
      const meta = await this.getBlockMeta(phone);
      return {
        count,
        dayDeclines,
        blocked: true,
        until: meta?.until || undefined,
        reason: 'missed_orders',
      };
    }
    return { count, dayDeclines, blocked: false };
  }

  async getProfile(phone: string) {
    const raw = await this.redis.client.get(this.profileKey(phone));
    if (!raw) return null;
    try {
      return JSON.parse(raw);
    } catch {
      return null;
    }
  }

  /** Preserve the stored identity; older installations used digits without '+'. */
  async resolveProfilePhone(rawPhone: string): Promise<string | null> {
    const trimmed = String(rawPhone || '').trim();
    let digits = trimmed.replace(/\D/g, '');
    if (digits.length === 11 && digits.startsWith('8')) digits = `7${digits.slice(1)}`;
    if (digits.length === 10) digits = `7${digits}`;
    if (!/^\d{10,15}$/.test(digits)) return null;
    for (const candidate of new Set([trimmed, `+${digits}`, digits])) {
      if (await this.getProfile(candidate)) return candidate;
    }
    return null;
  }

  async getProfileLite(phone: string) {
    const liteRaw = await this.redis.client.get(this.profileLiteKey(phone));
    if (liteRaw) {
      try {
        return JSON.parse(liteRaw);
      } catch {
        /* fall through */
      }
    }
    const full = await this.getProfile(phone);
    if (!full || typeof full !== 'object') return null;
    const lite = this.buildProfileLite(full as Record<string, unknown>);
    await this.redis.client.set(this.profileLiteKey(phone), JSON.stringify(lite));
    return lite;
  }

  async saveProfile(phone: string, profile: Record<string, unknown>) {
    await this.redis.client.set(this.profileKey(phone), JSON.stringify(profile));
    await this.redis.client.set(this.profileLiteKey(phone), JSON.stringify(this.buildProfileLite(profile)));
    await this.redis.client.sadd(this.allKey(), phone);
  }

  /** Гарантируем, что водитель есть в drivers:all (вызывается при OTP-входе) */
  async ensureRegistered(phone: string) {
    await this.redis.client.sadd(this.allKey(), phone);
  }

  async getBonus(phone: string) {
    const raw = await this.redis.client.hgetall(this.bonusKey(phone));
    const available = Number(raw.available || 0);
    const earned = Number(raw.earned || 0);
    return { available, earned };
  }

  async getRating(phone: string) {
    const raw = await this.redis.client.hgetall(this.ratingKey(phone));
    const avg = Number(raw.avg || 0);
    const count = Number(raw.count || 0);
    return { avg, count };
  }

  async addBonus(phone: string, amount: number) {
    const value = Math.max(0, Math.round(Number(amount) || 0));
    if (value <= 0) return;
    const key = this.bonusKey(phone);
    const multi = this.redis.client.multi();
    multi.hincrby(key, 'available', value);
    multi.hincrby(key, 'earned', value);
    await multi.exec();
  }

  /** O(1) проверка наличия активного заказа у водителя через Redis SET */
  async hasActiveOrder(phone: string): Promise<boolean> {
    const val = await this.redis.client.sismember('drivers:active_order', phone);
    return val === 1;
  }

  /** Batch version used by dispatch to avoid one Redis round-trip per candidate. */
  async filterWithoutActiveOrders(phones: string[]): Promise<string[]> {
    if (!phones.length) return [];
    const pipeline = this.redis.client.pipeline();
    phones.forEach((phone) => pipeline.sismember('drivers:active_order', phone));
    const results = await pipeline.exec();
    return phones.filter((_, index) => results?.[index]?.[1] !== 1);
  }

  private photosBackupKey(phone: string) {
    return `driver:photos_backup:${phone}`;
  }

  private pushTokenKey(phone: string) {
    return `driver:push_token:${phone}`;
  }

  /** Driver self-delete (used by drivers.controller on server). */
  async deleteAccount(phone: string) {
    const normalized = (phone || '').trim();
    if (!normalized) return { ok: false, error: 'phone required' };

    await this.clearBlock(normalized);
    await this.setStatus(normalized, 'offline');

    const pipeline = this.redis.client.pipeline();
    pipeline.del(this.profileKey(normalized));
    pipeline.del(this.profileLiteKey(normalized));
    pipeline.del(this.photosBackupKey(normalized));
    pipeline.del(this.locKey(normalized));
    pipeline.del(this.pushTokenKey(normalized));
    pipeline.del(this.onlineKey(normalized));
    pipeline.del(this.subscriptionPaidUntilKey(normalized));
    pipeline.del(this.bonusKey(normalized));
    pipeline.del(this.ratingKey(normalized));
    pipeline.srem(this.allKey(), normalized);
    pipeline.hdel(this.statusKey(), normalized);
    pipeline.srem('drivers:active_order', normalized);
    try {
      pipeline.zrem(this.geoKey(), normalized);
    } catch {
      // best-effort
    }
    await pipeline.exec();

    return { ok: true };
  }

  async getLocation(phone: string): Promise<{
    lat: number;
    lng: number;
    accuracyMeters?: number;
    recordedAt?: string;
    updatedAt?: string;
  } | null> {
    const raw = await this.redis.client.get(this.locKey(phone));
    if (!raw) return null;
    try {
      const loc = JSON.parse(raw) as {
        lat?: number;
        lng?: number;
        accuracyMeters?: number;
        recordedAt?: string;
        updatedAt?: string;
      };
      if (!Number.isFinite(loc.lat) || !Number.isFinite(loc.lng)) return null;
      return {
        lat: Number(loc.lat),
        lng: Number(loc.lng),
        ...(Number.isFinite(loc.accuracyMeters)
          ? { accuracyMeters: Number(loc.accuracyMeters) }
          : {}),
        ...(typeof loc.recordedAt === 'string'
          ? { recordedAt: loc.recordedAt }
          : {}),
        ...(typeof loc.updatedAt === 'string'
          ? { updatedAt: loc.updatedAt }
          : {}),
      };
    } catch {
      return null;
    }
  }
}
