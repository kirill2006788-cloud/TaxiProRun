import { Body, Controller, Get, Headers, Param, Post, Query, UnauthorizedException } from '@nestjs/common';
import { RedisService } from './redis.service';
import { DriversService } from './drivers.service';
import { OrdersService } from './orders.service';
import { EventsGateway } from './events.gateway';
import { DEFAULT_TAXI_TARIFFS, inferDriverRatePerKm } from './pricing/taxi-pricing';
import jwt from 'jsonwebtoken';
import crypto from 'crypto';

type DriverProfile = {
  phone: string;
  fullName?: string;
  email?: string;
  rating?: number;
  inn?: string;
  passport?: string;
  docsSigned?: boolean;
  registrationStatus?: string;
  referralCount?: number;
};

type ClientProfile = {
  id: string;
  fullName?: string;
  phone?: string;
  email?: string;
};

@Controller('admin')
export class AdminController {
  constructor(
    private readonly redis: RedisService,
    private readonly drivers: DriversService,
    private readonly orders: OrdersService,
    private readonly events: EventsGateway,
  ) {}

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

  private auditListKey() {
    return 'admin:audit';
  }

  private async logAudit(
    action: string,
    meta?: { target?: string; details?: string; admin?: string },
  ) {
    try {
      const entry = {
        id: crypto.randomUUID(),
        action,
        target: meta?.target || '',
        details: meta?.details || '',
        admin: meta?.admin || 'admin',
        createdAt: new Date().toISOString(),
      };
      const multi = this.redis.client.multi();
      multi.lpush(this.auditListKey(), JSON.stringify(entry));
      multi.ltrim(this.auditListKey(), 0, 999);
      await multi.exec();
    } catch {
      // audit is best-effort
    }
  }

  private defaultTaxiTariffs() {
    return DEFAULT_TAXI_TARIFFS;
  }

  private normalizeTaxiTariff(input: any, fallback: any) {
    const id = String(input?.id || fallback?.id || 'tariff').trim();
    const clientRatePerKm = Number.isFinite(Number(input?.clientRatePerKm))
      ? Math.max(0, Math.round(Number(input.clientRatePerKm)))
      : Number.isFinite(Number(input?.perKm))
        ? Math.max(0, Math.round(Number(input.perKm)))
        : Number(fallback?.clientRatePerKm || fallback?.perKm || 0);
    const driverRatePerKm = Number.isFinite(Number(input?.driverRatePerKm)) && Number(input.driverRatePerKm) > 0
      ? Math.max(0, Math.round(Number(input.driverRatePerKm)))
      : Number(fallback?.driverRatePerKm) > 0
        ? Math.round(Number(fallback.driverRatePerKm))
        : inferDriverRatePerKm(clientRatePerKm);
    return {
      id,
      name: String(input?.name || fallback?.name || id),
      clientRatePerKm,
      driverRatePerKm,
      perKm: clientRatePerKm,
      description: String(input?.description || fallback?.description || ''),
      maxPassengers: Number.isFinite(Number(input?.maxPassengers))
        ? Math.max(1, Math.round(Number(input.maxPassengers)))
        : Number(fallback?.maxPassengers || 4),
      maxBags: Number.isFinite(Number(input?.maxBags))
        ? Math.max(0, Math.round(Number(input.maxBags)))
        : Number(fallback?.maxBags || 2),
      icon: String(input?.icon || fallback?.icon || id),
    };
  }

  private buildFallbackTimeline(order: any) {
    const items: { at: string; to: string; from?: string; actor: string; reason?: string }[] = [];
    if (order.createdAt) {
      items.push({ at: order.createdAt, from: '', to: 'searching', actor: 'system' });
    }
    if (order.acceptedAt) {
      items.push({ at: order.acceptedAt, from: 'searching', to: 'accepted', actor: order.driverPhone ? 'driver' : 'admin' });
    }
    if (order.arrivedAt) {
      items.push({ at: order.arrivedAt, from: 'accepted', to: 'arrived', actor: 'driver' });
    }
    if (order.startedAt) {
      items.push({ at: order.startedAt, from: 'arrived', to: 'started', actor: 'driver' });
    }
    if (order.completedAt) {
      items.push({ at: order.completedAt, from: 'started', to: 'completed', actor: 'driver' });
    }
    if (order.status === 'canceled') {
      const prev = order.startedAt ? 'started'
        : order.arrivedAt ? 'arrived'
          : order.acceptedAt ? 'accepted'
            : 'searching';
      items.push({
        at: order.completedAt || order.startedAt || order.arrivedAt || order.acceptedAt || order.createdAt,
        from: prev,
        to: 'canceled',
        actor: order.canceledBy || 'system',
        reason: order.cancelReason,
      });
    }
    return items;
  }

  private driverProfileKey(phone: string) {
    return `driver:profile:${phone}`;
  }

  private driverPhotosBackupKey(phone: string) {
    return `driver:photos_backup:${phone}`;
  }

  private profileHasVerificationPhotos(profile: Record<string, any> | null | undefined) {
    if (!profile) return false;
    return !!(
      profile.passportFrontBase64 ||
      profile.passportRegBase64 ||
      profile.driverLicenseBackBase64 ||
      profile.selfieBase64
    );
  }

  private mergeDriverProfilePhotos(profile: Record<string, any>, backup: Record<string, any>, includePhotos: boolean) {
    const hasVerificationPhotos = this.profileHasVerificationPhotos(profile) || this.profileHasVerificationPhotos(backup);
    if (!includePhotos) {
      const {
        passportFrontBase64,
        passportRegBase64,
        driverLicenseBackBase64,
        selfieBase64,
        avatarBase64,
        carPhotoBase64,
        stsBase64,
        osagoBase64,
        signatureBase64,
        ...rest
      } = profile;
      return {
        ...rest,
        hasVerificationPhotos,
      };
    }
    return {
      ...profile,
      hasVerificationPhotos,
      avatarBase64: profile.avatarBase64 || backup.avatarBase64 || null,
      passportFrontBase64: profile.passportFrontBase64 || backup.passportFrontBase64 || null,
      passportRegBase64: profile.passportRegBase64 || backup.passportRegBase64 || null,
      driverLicenseBackBase64: profile.driverLicenseBackBase64 || backup.driverLicenseBackBase64 || null,
      selfieBase64: profile.selfieBase64 || backup.selfieBase64 || null,
      carPhotoBase64: profile.carPhotoBase64 || backup.carPhotoBase64 || null,
      stsBase64: profile.stsBase64 || backup.stsBase64 || null,
      osagoBase64: profile.osagoBase64 || backup.osagoBase64 || null,
      signatureBase64: profile.signatureBase64 || backup.signatureBase64 || null,
    };
  }

  private async restoreProfilePhotosFromBackup(phone: string, profile: Record<string, any>, backup: Record<string, any>) {
    if (!this.profileHasVerificationPhotos(backup) || this.profileHasVerificationPhotos(profile)) {
      return profile;
    }
    return {
      ...profile,
      avatarBase64: profile.avatarBase64 || backup.avatarBase64 || null,
      passportFrontBase64: profile.passportFrontBase64 || backup.passportFrontBase64 || null,
      passportRegBase64: profile.passportRegBase64 || backup.passportRegBase64 || null,
      driverLicenseBackBase64: profile.driverLicenseBackBase64 || backup.driverLicenseBackBase64 || null,
      selfieBase64: profile.selfieBase64 || backup.selfieBase64 || null,
      carPhotoBase64: profile.carPhotoBase64 || backup.carPhotoBase64 || null,
      stsBase64: profile.stsBase64 || backup.stsBase64 || null,
      osagoBase64: profile.osagoBase64 || backup.osagoBase64 || null,
      signatureBase64: profile.signatureBase64 || backup.signatureBase64 || null,
    };
  }

  private cancelReasonLabel(reason?: string) {
    const raw = String(reason || '').trim();
    const map: Record<string, string> = {
      wait_too_long: 'Долго ждать',
      wrong_address: 'Ошибся адресом',
      plans_changed: 'Изменились планы',
      price_high: 'Дорого',
      found_another: 'Нашёл другой вариант',
      other: 'Другая причина',
    };
    return map[raw] || raw || 'Не указана';
  }

  private normalizeAdminPhone(raw?: string | null) {
    let digits = (raw || '').toString().replace(/\D/g, '');
    if (!digits) return '';
    if (digits.length === 11 && digits.startsWith('8')) digits = `7${digits.slice(1)}`;
    else if (digits.length === 10) digits = `7${digits}`;
    return digits;
  }

  private async resolveDriverPhoneKey(rawPhone: string): Promise<string | null> {
    const trimmed = (rawPhone || '').trim();
    if (!trimmed) return null;
    const normalized = this.normalizeAdminPhone(trimmed);
    const candidates = [...new Set([trimmed, normalized].filter(Boolean))];
    for (const candidate of candidates) {
      const hasProfile = await this.redis.client.exists(this.driverProfileKey(candidate));
      const hasBackup = await this.redis.client.exists(this.driverPhotosBackupKey(candidate));
      if (hasProfile || hasBackup) return candidate;
    }
    const all = await this.redis.client.smembers(this.driversSet());
    for (const listedPhone of all) {
      if (this.normalizeAdminPhone(listedPhone) !== normalized) continue;
      const hasProfile = await this.redis.client.exists(this.driverProfileKey(listedPhone));
      const hasBackup = await this.redis.client.exists(this.driverPhotosBackupKey(listedPhone));
      if (hasProfile || hasBackup) return listedPhone;
      return listedPhone;
    }
    return null;
  }

  private clientProfileKey(id: string) {
    return `client:profile:${id}`;
  }

  private clientBlockKey(id: string) {
    return `client:block:${id}`;
  }

  private clientBlockMetaKey(id: string) {
    return `client:block_meta:${id}`;
  }

  private driversSet() {
    return 'drivers:all';
  }

  private driverStatusKey() {
    return 'drivers:status';
  }

  private driverGeoKey() {
    return 'drivers:geo';
  }

  private driverLocKey(phone: string) {
    return `driver:loc:${phone}`;
  }

  private driverPushTokenKey(phone: string) {
    return `driver:push_token:${phone}`;
  }

  private driverAdminCommentKey(phone: string) {
    return `driver:admin_comment:${phone}`;
  }

  private clientsSet() {
    return 'clients:all';
  }

  private clientAdminCommentKey(id: string) {
    return `client:admin_comment:${id}`;
  }

  private promoSet() {
    return 'promos:all';
  }

  private promoKey(code: string) {
    return `promo:${code.toLowerCase()}`;
  }

  private defaultTariffs() {
    return [
      { name: 'Трезвый водитель', mode: 'system', base: 2500, perMin: 25, perKm: 50, includedMin: 60, commission: 33.3, dailyMarkupPercent: [0, 0, 0, 0, 0, 0, 0], saturdayMarkupPercent: 0, sundayMarkupPercent: 0 },
      { name: 'Личный водитель', mode: 'system', base: 9000, perMin: 25, includedMin: 300, commission: 33.3, dailyMarkupPercent: [0, 0, 0, 0, 0, 0, 0], saturdayMarkupPercent: 0, sundayMarkupPercent: 0 },
      { name: 'Перегон автомобиля', mode: 'system', base: 2500, perMin: 25, perKm: 50, includedMin: 60, commission: 33.3, dailyMarkupPercent: [0, 0, 0, 0, 0, 0, 0], saturdayMarkupPercent: 0, sundayMarkupPercent: 0 },
    ];
  }

  private normalizeTariff(input: any, fallback: any) {
    const base = Number.isFinite(Number(input?.base)) ? Math.max(0, Math.round(Number(input.base))) : Number(fallback.base || 0);
    const perKm = Number.isFinite(Number(input?.perKm)) ? Math.max(0, Math.round(Number(input.perKm))) : Number(fallback.perKm || 0);
    const perMin = Number.isFinite(Number(input?.perMin)) ? Math.max(0, Math.round(Number(input.perMin))) : Number(fallback.perMin || 0);
    const includedMin = Number.isFinite(Number(input?.includedMin))
      ? Math.max(0, Math.round(Number(input.includedMin)))
      : Number(fallback.includedMin || 0);
    const commissionRaw = Number(input?.commission);
    const commission = Number.isFinite(commissionRaw)
      ? Math.max(0, Math.min(100, commissionRaw))
      : Number(fallback.commission || 0);
    const fallbackDaily = Array.isArray(fallback?.dailyMarkupPercent)
      ? fallback.dailyMarkupPercent
      : [fallback?.sundayMarkupPercent || 0, 0, 0, 0, 0, 0, fallback?.saturdayMarkupPercent || 0];
    const inputDaily = Array.isArray(input?.dailyMarkupPercent) ? input.dailyMarkupPercent : [];
    const dailyMarkupPercent = Array.from({ length: 7 }, (_, day) => {
      const legacyValue = day === 0 ? input?.sundayMarkupPercent : day === 6 ? input?.saturdayMarkupPercent : undefined;
      const raw = Number(inputDaily[day] ?? legacyValue ?? fallbackDaily[day] ?? 0);
      return Number.isFinite(raw) ? Math.max(0, Math.min(300, Math.round(raw))) : 0;
    });
    const sundayMarkupPercent = dailyMarkupPercent[0];
    const saturdayMarkupPercent = dailyMarkupPercent[6];
    return {
      name: String(input?.name || fallback.name || 'Тариф'),
      mode: String(input?.mode || fallback.mode || 'system'),
      base,
      perKm,
      perMin,
      includedMin,
      commission,
      dailyMarkupPercent,
      saturdayMarkupPercent,
      sundayMarkupPercent,
    };
  }

  private async saveAdminDriverProfile(originalPhone: string, body: Partial<DriverProfile> & Record<string, any>) {
    const targetPhone = String(body?.phone || originalPhone || '').trim();
    if (!targetPhone) return { ok: false, error: 'phone required' };

    const existingRaw = await this.redis.client.get(this.driverProfileKey(originalPhone));
    const targetRaw = targetPhone !== originalPhone ? await this.redis.client.get(this.driverProfileKey(targetPhone)) : null;
    const backupRaw = await this.redis.client.get(this.driverPhotosBackupKey(originalPhone))
      || (targetPhone !== originalPhone ? await this.redis.client.get(this.driverPhotosBackupKey(targetPhone)) : null);
    let existing: any = {};
    let backup: any = {};
    try {
      if (existingRaw) existing = JSON.parse(existingRaw);
      else if (targetRaw) existing = JSON.parse(targetRaw);
    } catch {
      existing = {};
    }
    try { if (backupRaw) backup = JSON.parse(backupRaw); } catch { backup = {}; }

    const {
      passportFrontBase64: _pf,
      passportRegBase64: _pr,
      driverLicenseBackBase64: _dl,
      selfieBase64: _sf,
      avatarBase64: _av,
      ...bodyWithoutPhotos
    } = body as Record<string, any>;

    const profile = {
      ...existing,
      ...bodyWithoutPhotos,
      phone: targetPhone,
      fullName: typeof body?.fullName === 'string' ? body.fullName : (existing.fullName || ''),
      email: typeof body?.email === 'string' ? body.email : (existing.email || ''),
      rating: Number.isFinite(Number(body?.rating)) ? Number(body.rating) : (existing.rating ?? undefined),
      inn: typeof body?.inn === 'string' ? body.inn : (existing.inn || ''),
      passport: typeof body?.passport === 'string' ? body.passport : (existing.passport || ''),
      docsSigned: typeof body?.docsSigned === 'boolean' ? body.docsSigned : Boolean(existing.docsSigned),
      registrationStatus: typeof body?.registrationStatus === 'string' && body.registrationStatus.trim()
        ? body.registrationStatus.trim()
        : (existing.registrationStatus || 'incomplete'),
      avatarBase64: existing.avatarBase64 || backup.avatarBase64 || null,
      passportFrontBase64: existing.passportFrontBase64 || backup.passportFrontBase64 || null,
      passportRegBase64: existing.passportRegBase64 || backup.passportRegBase64 || null,
      driverLicenseBackBase64: existing.driverLicenseBackBase64 || backup.driverLicenseBackBase64 || null,
      selfieBase64: existing.selfieBase64 || backup.selfieBase64 || null,
      updatedAt: new Date().toISOString(),
    };

    await this.drivers.saveProfile(targetPhone, profile);
    if (this.profileHasVerificationPhotos(profile)) {
      await this.redis.client.set(this.driverPhotosBackupKey(targetPhone), JSON.stringify({
        avatarBase64: profile.avatarBase64 || null,
        passportFrontBase64: profile.passportFrontBase64 || null,
        passportRegBase64: profile.passportRegBase64 || null,
        driverLicenseBackBase64: profile.driverLicenseBackBase64 || null,
        selfieBase64: profile.selfieBase64 || null,
        updatedAt: new Date().toISOString(),
      }));
    }

    if (targetPhone !== originalPhone) {
      const backupRaw = await this.redis.client.get(this.driverPhotosBackupKey(originalPhone));
      const adminComment = await this.redis.client.get(this.driverAdminCommentKey(originalPhone));
      if (backupRaw) await this.redis.client.set(this.driverPhotosBackupKey(targetPhone), backupRaw);
      if (adminComment) await this.redis.client.set(this.driverAdminCommentKey(targetPhone), adminComment);
      await this.redis.client.del(this.driverProfileKey(originalPhone));
      await this.redis.client.del(this.driverPhotosBackupKey(originalPhone));
      await this.redis.client.del(this.driverAdminCommentKey(originalPhone));
      await this.redis.client.srem(this.driversSet(), originalPhone);
    }

    return { ok: true, phone: targetPhone, profile };
  }

  private parseLiteProfile(raw: unknown, phone: string, rebuilt?: Map<string, Record<string, unknown>>) {
    if (typeof raw === 'string' && raw) {
      try { return JSON.parse(raw); } catch { return rebuilt?.get(phone) || {}; }
    }
    return rebuilt?.get(phone) || {};
  }

  private async loadLiteProfiles(phones: string[]) {
    const pipeline = this.redis.client.pipeline();
    phones.forEach((p) => pipeline.get(this.drivers.profileLiteKey(p)));
    const res = await pipeline.exec();
    const raws = res?.map((r) => r?.[1]) || [];
    const missing: string[] = [];
    raws.forEach((raw, idx) => {
      if (typeof raw !== 'string' || !raw) missing.push(phones[idx]);
    });
    const rebuilt = missing.length ? await this.drivers.rebuildProfileLites(missing) : new Map<string, Record<string, unknown>>();
    return phones.map((phone, idx) => this.parseLiteProfile(raws[idx], phone, rebuilt));
  }

  @Get('drivers')
  async listDrivers(
    @Headers('authorization') auth?: string,
    @Query('includePhotos') includePhotos?: string,
    @Query('includeLocation') includeLocation?: string,
    @Query('view') view?: string,
  ) {
    this.requireAdmin(auth);
    const mode = String(view || 'manage').trim().toLowerCase();
    if (mode === 'abon') return this.listDriversAbonView();
    if (mode === 'commission') return this.listDriversCommissionView();
    if (mode === 'verify') return this.listDriversVerifyView();

    const includeAllPhotos = includePhotos === '1' || includePhotos === 'true';
    const withLocation = includeLocation === '1' || includeLocation === 'true' || mode === 'dispatch';
    const base = await this.drivers.listDriversForAdmin({ withLocation, withBlockMeta: true });
    const earningsLimit = await this.orders.getEarningsLimit();
    const pipeline = this.redis.client.pipeline();
    if (includeAllPhotos) {
      base.forEach((d: any) => pipeline.get(this.driverProfileKey(d.phone)));
      base.forEach((d: any) => pipeline.get(this.driverPhotosBackupKey(d.phone)));
    } else {
      base.forEach((d: any) => pipeline.get(this.drivers.profileLiteKey(d.phone)));
      base.forEach((d: any) => pipeline.exists(this.driverPhotosBackupKey(d.phone)));
    }
    base.forEach((d: any) => pipeline.hgetall(`driver:earnings:${d.phone}`));
    base.forEach((d: any) => pipeline.get(`driver:sub:paid_until:${d.phone}`));
    base.forEach((d: any) => pipeline.get(this.driverAdminCommentKey(d.phone)));
    const res = await pipeline.exec();
    const half = base.length;
    const profiles = res?.slice(0, half).map((r: any) => r?.[1]) || [];
    const backupsOrExists = res?.slice(half, half * 2).map((r: any) => r?.[1]) || [];
    const earningsRaw = res?.slice(half * 2, half * 3).map((r: any) => r?.[1]) || [];
    const subPaidRaw = res?.slice(half * 3, half * 4).map((r: any) => r?.[1]) || [];
    const adminComments = res?.slice(half * 4).map((r: any) => r?.[1]) || [];

    const missingLitePhones: string[] = [];
    if (!includeAllPhotos) {
      profiles.forEach((raw, idx) => {
        if (typeof raw !== 'string' || !raw) missingLitePhones.push(base[idx].phone);
      });
    }
    const rebuiltLites = missingLitePhones.length
      ? await this.drivers.rebuildProfileLites(missingLitePhones)
      : new Map<string, Record<string, unknown>>();

    const subSettings = await this.drivers.getSubscriptionSettings();
    const currentDue = this.drivers.getCurrentPeriodDueDate(subSettings.dayOfMonth);
    const drivers = base.map((d: any, idx: number) => {
      const raw = typeof profiles[idx] === 'string' ? profiles[idx] : null;
      let profile: any = {};
      if (includeAllPhotos) {
        try { if (raw) profile = JSON.parse(raw) as DriverProfile; } catch { /* skip corrupted */ }
      } else if (raw) {
        try { profile = JSON.parse(raw); } catch { profile = {}; }
      } else {
        profile = rebuiltLites.get(d.phone) || {};
      }
      if (includeAllPhotos) {
        let backup: any = {};
        const backupRaw = typeof backupsOrExists[idx] === 'string' ? backupsOrExists[idx] : null;
        try { if (backupRaw) backup = JSON.parse(backupRaw); } catch { backup = {}; }
        profile = this.mergeDriverProfilePhotos(profile, backup, true);
      } else {
        const backupExists = Number(backupsOrExists[idx] || 0) === 1;
        if (backupExists && !profile.hasVerificationPhotos) {
          profile.hasVerificationPhotos = true;
        }
      }
      const e = (earningsRaw[idx] || {}) as Record<string, string>;
      const gross = Number(e.gross || 0);
      const commission = Number(e.commission || 0);
      const net = Number(e.net || 0);
      const paid = Number(e.paid || 0);
      const paidUntil = typeof subPaidRaw[idx] === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(subPaidRaw[idx] as string) ? (subPaidRaw[idx] as string) : null;
      const subscriptionOverdue = !paidUntil || paidUntil < currentDue;
      return {
        ...d,
        profile,
        adminComment: typeof adminComments[idx] === 'string' ? (adminComments[idx] as string) : '',
        earnings: { gross, commission, net, paid, available: net - paid },
        limitReached: commission >= earningsLimit,
        earningsLimit,
        subscriptionPaidUntil: paidUntil,
        subscriptionOverdue,
        subscriptionAmount: subSettings.amount,
        subscriptionDayOfMonth: subSettings.dayOfMonth,
      };
    });
    return { ok: true, drivers };
  }

  private async listDriversAbonView() {
    const phones = await this.redis.client.smembers(this.driversSet());
    const subSettings = await this.drivers.getSubscriptionSettings();
    const currentDue = this.drivers.getCurrentPeriodDueDate(subSettings.dayOfMonth);
    if (!phones.length) {
      return {
        ok: true,
        drivers: [],
        subscription: subSettings,
      };
    }
    const liteProfiles = await this.loadLiteProfiles(phones);
    const pipeline = this.redis.client.pipeline();
    phones.forEach((p) => pipeline.get(`driver:sub:paid_until:${p}`));
    const subRaw = (await pipeline.exec())?.map((r) => r?.[1]) || [];
    const drivers = phones.map((phone, idx) => {
      const profile = liteProfiles[idx] || {};
      const paidUntil = typeof subRaw[idx] === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(subRaw[idx] as string)
        ? (subRaw[idx] as string)
        : null;
      return {
        phone,
        profile: {
          fullName: profile.fullName || '',
          phone: profile.phone || phone,
        },
        subscriptionPaidUntil: paidUntil,
        subscriptionOverdue: !paidUntil || paidUntil < currentDue,
        subscriptionAmount: subSettings.amount,
        subscriptionDayOfMonth: subSettings.dayOfMonth,
      };
    });
    return { ok: true, drivers, subscription: subSettings };
  }

  private async listDriversCommissionView() {
    const base = await this.drivers.listDriversForAdmin({ withLocation: false, withBlockMeta: false });
    const phones = base.map((d) => d.phone);
    const earningsLimit = await this.orders.getEarningsLimit();
    const liteProfiles = phones.length ? await this.loadLiteProfiles(phones) : [];
    const pipeline = this.redis.client.pipeline();
    base.forEach((d) => pipeline.hgetall(`driver:earnings:${d.phone}`));
    const earningsRaw = (await pipeline.exec())?.map((r) => r?.[1]) || [];
    const drivers = base.map((d, idx) => {
      const profile = liteProfiles[idx] || {};
      const e = (earningsRaw[idx] || {}) as Record<string, string>;
      const gross = Number(e.gross || 0);
      const commission = Number(e.commission || 0);
      const net = Number(e.net || 0);
      const paid = Number(e.paid || 0);
      return {
        phone: d.phone,
        status: d.status,
        blocked: d.blocked,
        profile: {
          fullName: profile.fullName || '',
          email: profile.email || '',
          phone: profile.phone || d.phone,
        },
        earnings: { gross, commission, net, paid, available: net - paid },
        limitReached: commission >= earningsLimit,
        earningsLimit,
      };
    });
    return { ok: true, drivers };
  }

  private async listDriversVerifyView() {
    const base = await this.drivers.listDriversForAdmin({ withLocation: false, withBlockMeta: false });
    const phones = base.map((d) => d.phone);
    const liteProfiles = phones.length ? await this.loadLiteProfiles(phones) : [];
    const pipeline = this.redis.client.pipeline();
    phones.forEach((p) => pipeline.exists(this.driverPhotosBackupKey(p)));
    const backupExistsRaw = (await pipeline.exec())?.map((r) => r?.[1]) || [];
    const drivers = base.map((d, idx) => {
      let profile = liteProfiles[idx] || {};
      if (Number(backupExistsRaw[idx] || 0) === 1 && !profile.hasVerificationPhotos) {
        profile = { ...profile, hasVerificationPhotos: true };
      }
      return {
        phone: d.phone,
        status: d.status,
        blocked: d.blocked,
        profile,
      };
    });
    return { ok: true, drivers };
  }

  @Post('drivers/warm-lite-cache')
  async warmLiteCache(@Headers('authorization') auth?: string) {
    this.requireAdmin(auth);
    const rebuilt = await this.drivers.warmAllProfileLites();
    return { ok: true, count: rebuilt.size };
  }

  @Post('drivers')
  async upsertDriver(@Body() body: DriverProfile, @Headers('authorization') auth?: string) {
    this.requireAdmin(auth);
    const phone = (body.phone || '').trim();
    if (!phone) return { ok: false, error: 'phone required' };
    return this.saveAdminDriverProfile(phone, body as any);
  }

  @Post('drivers/:phone')
  async updateDriverProfile(
    @Param('phone') phoneRaw: string,
    @Body() body: Partial<DriverProfile> & Record<string, any>,
    @Headers('authorization') auth?: string,
  ) {
    this.requireAdmin(auth);
    const phone = (phoneRaw || '').trim();
    if (!phone) return { ok: false, error: 'phone required' };
    return this.saveAdminDriverProfile(phone, body as any);
  }

  @Post('drivers/:phone/block')
  async blockDriver(
    @Param('phone') phoneRaw: string,
    @Body() body: { reason?: string },
    @Headers('authorization') auth?: string,
  ) {
    const admin = this.requireAdmin(auth);
    const phone = (phoneRaw || '').trim();
    if (!phone) return { ok: false };
    const reason = (body?.reason || '').trim() || 'manual';
    await this.drivers.blockTemporarily(phone, reason, 24 * 365);
    const meta = await this.drivers.getBlockMeta(phone);
    this.events.emitDriverBlocked(phone, { reason: meta?.reason || reason, until: meta?.until || null });
    await this.logAudit('driver.block', { admin: admin.login, target: phone, details: reason });
    return { ok: true, reason: meta?.reason || reason, until: meta?.until || null };
  }

  @Post('drivers/:phone/unblock')
  async unblockDriver(@Param('phone') phoneRaw: string, @Headers('authorization') auth?: string) {
    this.requireAdmin(auth);
    const phone = (phoneRaw || '').trim();
    if (!phone) return { ok: false };
    await this.drivers.clearBlock(phone);
    this.events.emitDriverUnblocked(phone);
    return { ok: true };
  }

  @Post('drivers/:phone/delete')
  async deleteDriver(
    @Param('phone') phoneRaw: string,
    @Body() body: { comment?: string },
    @Headers('authorization') auth?: string,
  ) {
    this.requireAdmin(auth);
    const phone = (phoneRaw || '').trim();
    if (!phone) return { ok: false };
    const comment = (body?.comment || '').trim();
    if (comment) {
      await this.redis.client.set(this.driverAdminCommentKey(phone), comment);
    }
    await this.drivers.clearBlock(phone);
    await this.redis.client.del(this.driverProfileKey(phone));
    await this.redis.client.del(this.drivers.profileLiteKey(phone));
    await this.redis.client.del(this.driverPhotosBackupKey(phone));
    await this.redis.client.del(this.driverLocKey(phone));
    await this.redis.client.del(this.driverPushTokenKey(phone));
    await this.redis.client.srem(this.driversSet(), phone);
    await this.redis.client.hdel(this.driverStatusKey(), phone);
    try {
      await this.redis.client.zrem(this.driverGeoKey(), phone);
    } catch {
      // geo index cleanup is best-effort
    }
    await this.redis.client.srem('drivers:active_order', phone);
    await this.redis.client.del(`driver:sub:paid_until:${phone}`);
    return { ok: true };
  }

  @Get('subscription/settings')
  async getSubscriptionSettings(@Headers('authorization') auth?: string) {
    this.requireAdmin(auth);
    const settings = await this.drivers.getSubscriptionSettings();
    return { ok: true, ...settings };
  }

  @Post('subscription/settings')
  async setSubscriptionSettings(
    @Body() body: { amount?: number; dayOfMonth?: number },
    @Headers('authorization') auth?: string,
  ) {
    this.requireAdmin(auth);
    const current = await this.drivers.getSubscriptionSettings();
    const amount = Number.isFinite(Number(body?.amount)) ? Math.max(0, Math.round(Number(body.amount))) : current.amount;
    const dayOfMonth = Number.isFinite(Number(body?.dayOfMonth)) ? Math.max(1, Math.min(28, Math.round(Number(body.dayOfMonth)))) : current.dayOfMonth;
    await this.drivers.setSubscriptionSettings(amount, dayOfMonth);
    return { ok: true, amount, dayOfMonth };
  }

  @Get('order-timeout/settings')
  async getOrderAcceptTimeoutSettings(@Headers('authorization') auth?: string) {
    this.requireAdmin(auth);
    const orderAcceptTimeoutSec = await this.drivers.getOrderAcceptTimeoutSec();
    return { ok: true, orderAcceptTimeoutSec };
  }

  @Post('order-timeout/settings')
  async setOrderAcceptTimeoutSettings(
    @Body() body: { orderAcceptTimeoutSec?: number },
    @Headers('authorization') auth?: string,
  ) {
    this.requireAdmin(auth);
    const current = await this.drivers.getOrderAcceptTimeoutSec();
    const sec = Number.isFinite(Number(body?.orderAcceptTimeoutSec))
      ? Math.round(Number(body.orderAcceptTimeoutSec))
      : current;
    try {
      await this.drivers.setOrderAcceptTimeoutSec(sec);
    } catch (e: any) {
      return { ok: false, error: e?.message || 'invalid timeout' };
    }
    return { ok: true, orderAcceptTimeoutSec: sec };
  }

  @Post('drivers/:phone/subscription/paid')
  async markSubscriptionPaid(
    @Param('phone') phoneRaw: string,
    @Body() body: { paidUntil?: string },
    @Headers('authorization') auth?: string,
  ) {
    this.requireAdmin(auth);
    const phone = (phoneRaw || '').trim();
    if (!phone) return { ok: false, error: 'phone required' };
    const nextDue = this.drivers.getNextDueDate((await this.drivers.getSubscriptionSettings()).dayOfMonth);
    const paidUntil = body?.paidUntil && /^\d{4}-\d{2}-\d{2}$/.test(String(body.paidUntil).trim()) ? String(body.paidUntil).trim() : nextDue;
    await this.drivers.setSubscriptionPaidUntil(phone, paidUntil);
    this.events.emitDriverSubscriptionPaid(phone);
    return { ok: true, paidUntil };
  }

  @Post('drivers/:phone/subscription/force-overdue')
  async forceSubscriptionOverdue(@Param('phone') phoneRaw: string, @Headers('authorization') auth?: string) {
    this.requireAdmin(auth);
    const phone = (phoneRaw || '').trim();
    if (!phone) return { ok: false, error: 'phone required' };
    const settings = await this.drivers.getSubscriptionSettings();
    const currentDue = this.drivers.getCurrentPeriodDueDate(settings.dayOfMonth);
    const dueDate = new Date(currentDue + 'T12:00:00Z');
    dueDate.setDate(dueDate.getDate() - 1);
    const paidUntil = dueDate.toISOString().slice(0, 10);
    await this.drivers.setSubscriptionPaidUntil(phone, paidUntil);
    this.events.emitDriverSubscriptionOverdue(phone);
    return { ok: true, paidUntil };
  }

  @Post('drivers/:phone/subscription/set-date')
  async setSubscriptionDate(
    @Param('phone') phoneRaw: string,
    @Body() body: { paidUntil: string },
    @Headers('authorization') auth?: string,
  ) {
    this.requireAdmin(auth);
    const phone = (phoneRaw || '').trim();
    if (!phone) return { ok: false, error: 'phone required' };
    const paidUntil = body?.paidUntil && /^\d{4}-\d{2}-\d{2}$/.test(String(body.paidUntil).trim()) ? String(body.paidUntil).trim() : null;
    if (!paidUntil) return { ok: false, error: 'paidUntil required (YYYY-MM-DD)' };
    await this.drivers.setSubscriptionPaidUntil(phone, paidUntil);
    this.events.emitDriverSubscriptionPaid(phone);
    return { ok: true, paidUntil };
  }

  @Post('drivers/:phone/approve')
  async approveDriver(@Param('phone') phoneRaw: string, @Headers('authorization') auth?: string) {
    const admin = this.requireAdmin(auth);
    const phone = await this.resolveDriverPhoneKey(phoneRaw);
    if (!phone) return { ok: false, error: 'driver not found' };
    const profile = await this.loadDriverProfileForModeration(phone);
    if (!profile) return { ok: false, error: 'profile not found' };
    profile.registrationStatus = 'completed';
    profile.approvedAt = new Date().toISOString();
    profile.updatedAt = new Date().toISOString();
    await this.drivers.saveProfile(
      phone,
      this.mergeDriverProfilePhotos(profile, {}, false),
    );
    await this.logAudit('driver.approve', { admin: admin.login, target: phone });
    return { ok: true };
  }

  @Post('drivers/:phone/reject')
  async rejectDriver(@Param('phone') phoneRaw: string, @Headers('authorization') auth?: string) {
    const admin = this.requireAdmin(auth);
    const phone = await this.resolveDriverPhoneKey(phoneRaw);
    if (!phone) return { ok: false, error: 'driver not found' };
    const profile = await this.loadDriverProfileForModeration(phone);
    if (!profile) return { ok: false, error: 'profile not found' };
    profile.registrationStatus = 'rejected';
    profile.rejectedAt = new Date().toISOString();
    profile.updatedAt = new Date().toISOString();
    await this.drivers.saveProfile(
      phone,
      this.mergeDriverProfilePhotos(profile, {}, false),
    );
    await this.logAudit('driver.reject', { admin: admin.login, target: phone });
    return { ok: true };
  }

  private async loadDriverProfileForModeration(phone: string) {
    const raw = await this.redis.client.get(this.driverProfileKey(phone));
    const backupRaw = await this.redis.client.get(this.driverPhotosBackupKey(phone));
    let profile: any = {};
    let backup: any = {};
    try { if (raw) profile = JSON.parse(raw); } catch { profile = {}; }
    try { if (backupRaw) backup = JSON.parse(backupRaw); } catch { backup = {}; }
    if (!raw && !backupRaw && !profile.phone && !profile.fullName) return null;
    profile.phone = phone;
    profile = await this.restoreProfilePhotosFromBackup(phone, profile, backup);
    await this.redis.client.sadd(this.driversSet(), phone);
    return profile;
  }

  @Get('drivers/:phone/orders')
  async listDriverOrders(
    @Param('phone') phoneRaw: string,
    @Query('limit') limitRaw?: string,
    @Headers('authorization') auth?: string,
  ) {
    this.requireAdmin(auth);
    const phone = (phoneRaw || '').trim();
    if (!phone) return { ok: true, orders: [] };
    const limit = Math.min(200, Math.max(1, Number(limitRaw) || 50));
    const orders = await this.orders.listOrdersForDriver(phone, limit);
    return { ok: true, orders };
  }

  @Get('drivers/:phone/earnings')
  async driverEarnings(@Param('phone') phoneRaw: string, @Headers('authorization') auth?: string) {
    this.requireAdmin(auth);
    const phone = (phoneRaw || '').trim();
    if (!phone) return { ok: false };
    const earnings = await this.orders.getDriverEarnings(phone);
    return { ok: true, earnings };
  }

  @Get('drivers/:phone/debug')
  async debugDriver(@Param('phone') phoneRaw: string, @Headers('authorization') auth?: string) {
    this.requireAdmin(auth);
    const normalized = this.normalizeAdminPhone(phoneRaw);
    const resolved = await this.resolveDriverPhoneKey(phoneRaw);
    const all = await this.redis.client.smembers(this.driversSet());
    const matches = all.filter((p) => this.normalizeAdminPhone(p) === normalized);

    const probe = async (phone: string) => {
      const raw = await this.redis.client.get(this.driverProfileKey(phone));
      const backupRaw = await this.redis.client.get(this.driverPhotosBackupKey(phone));
      let profile: any = {};
      let backup: any = {};
      try { if (raw) profile = JSON.parse(raw); } catch { profile = { parseError: true }; }
      try { if (backupRaw) backup = JSON.parse(backupRaw); } catch { backup = { parseError: true }; }
      const len = (v: unknown) => (typeof v === 'string' ? v.length : 0);
      const hasPhotos = !!(profile.passportFrontBase64 || backup.passportFrontBase64);
      const reg = String(profile.registrationStatus || 'incomplete').toLowerCase();
      const hasRequired = !!(
        String(profile.fullName || '').trim() &&
        String(profile.inn || '').trim() &&
        String(profile.passport || '').trim()
      );
      const fullPacket = Boolean(profile.docsSigned && hasRequired && (
        (profile.passportFrontBase64 && profile.passportRegBase64 && profile.driverLicenseBackBase64 && profile.selfieBase64) ||
        (backup.passportFrontBase64 && backup.passportRegBase64 && backup.driverLicenseBackBase64 && backup.selfieBase64)
      ));
      const wouldShowInVerification = reg === 'pending' || (
        reg === 'incomplete' && (profile.docsSigned || profile.fullName || profile.inn || profile.passport || hasPhotos)
      ) || ((reg === 'completed' || reg === 'pending') && !fullPacket);
      return {
        phone,
        inDriversAll: all.includes(phone),
        profileExists: !!raw,
        backupExists: !!backupRaw,
        profileBytes: typeof raw === 'string' ? raw.length : 0,
        backupBytes: typeof backupRaw === 'string' ? backupRaw.length : 0,
        summary: {
          fullName: profile.fullName || '',
          inn: profile.inn || '',
          passport: profile.passport || '',
          email: profile.email || '',
          docsSigned: Boolean(profile.docsSigned),
          registrationStatus: reg,
          updatedAt: profile.updatedAt || backup.updatedAt || null,
        },
        photoLengths: {
          passportFront: len(profile.passportFrontBase64 || backup.passportFrontBase64),
          passportReg: len(profile.passportRegBase64 || backup.passportRegBase64),
          driverLicenseBack: len(profile.driverLicenseBackBase64 || backup.driverLicenseBackBase64),
          selfie: len(profile.selfieBase64 || backup.selfieBase64),
        },
        fullPacket,
        wouldShowInVerification,
      };
    };

    const probes = [];
    const seen = new Set<string>();
    for (const phone of [resolved, normalized, phoneRaw.trim(), ...matches].filter(Boolean)) {
      if (seen.has(phone as string)) continue;
      seen.add(phone as string);
      probes.push(await probe(phone as string));
    }

    return {
      ok: true,
      query: phoneRaw,
      normalized,
      resolvedPhone: resolved,
      matchedInDriversAll: matches,
      probes,
    };
  }

  @Post('drivers/:phone/force-pending')
  async forcePendingDriver(@Param('phone') phoneRaw: string, @Headers('authorization') auth?: string) {
    this.requireAdmin(auth);
    const phone = await this.resolveDriverPhoneKey(phoneRaw);
    if (!phone) return { ok: false, error: 'driver not found' };

    const raw = await this.redis.client.get(this.driverProfileKey(phone));
    const backupRaw = await this.redis.client.get(this.driverPhotosBackupKey(phone));
    let profile: any = {};
    let backup: any = {};
    try { if (raw) profile = JSON.parse(raw); } catch { return { ok: false, error: 'profile corrupted' }; }
    try { if (backupRaw) backup = JSON.parse(backupRaw); } catch { backup = {}; }

    profile = await this.restoreProfilePhotosFromBackup(phone, profile, backup);
    profile.registrationStatus = 'pending';
    profile.updatedAt = new Date().toISOString();
    await this.drivers.saveProfile(
      phone,
      this.mergeDriverProfilePhotos(profile, backup, false),
    );
    await this.redis.client.set(this.driverPhotosBackupKey(phone), JSON.stringify({
      avatarBase64: profile.avatarBase64 || backup.avatarBase64 || null,
      passportFrontBase64: profile.passportFrontBase64 || backup.passportFrontBase64 || null,
      passportRegBase64: profile.passportRegBase64 || backup.passportRegBase64 || null,
      driverLicenseBackBase64: profile.driverLicenseBackBase64 || backup.driverLicenseBackBase64 || null,
      selfieBase64: profile.selfieBase64 || backup.selfieBase64 || null,
      carPhotoBase64: profile.carPhotoBase64 || backup.carPhotoBase64 || null,
      stsBase64: profile.stsBase64 || backup.stsBase64 || null,
      osagoBase64: profile.osagoBase64 || backup.osagoBase64 || null,
      signatureBase64: profile.signatureBase64 || backup.signatureBase64 || null,
      updatedAt: new Date().toISOString(),
    }));

    return { ok: true, phone, registrationStatus: 'pending' };
  }

  @Get('drivers/:phone/photos')
  async getDriverPhotos(@Param('phone') phoneRaw: string, @Headers('authorization') auth?: string) {
    this.requireAdmin(auth);
    const phone = await this.resolveDriverPhoneKey(phoneRaw);
    if (!phone) return { ok: false, error: 'not found' };

    const raw = await this.redis.client.get(this.driverProfileKey(phone));
    const backupRaw = await this.redis.client.get(this.driverPhotosBackupKey(phone));

    let profile: any = {};
    let backup: any = {};
    try { if (raw) profile = JSON.parse(raw); } catch { profile = {}; }
    try { if (backupRaw) backup = JSON.parse(backupRaw); } catch { backup = {}; }

    profile = await this.restoreProfilePhotosFromBackup(phone, profile, backup);

    const photos = {
      avatarBase64: profile.avatarBase64 || backup.avatarBase64 || null,
      passportFrontBase64: profile.passportFrontBase64 || backup.passportFrontBase64 || null,
      passportRegBase64: profile.passportRegBase64 || backup.passportRegBase64 || null,
      driverLicenseBackBase64: profile.driverLicenseBackBase64 || backup.driverLicenseBackBase64 || null,
      selfieBase64: profile.selfieBase64 || backup.selfieBase64 || null,
      carPhotoBase64: profile.carPhotoBase64 || backup.carPhotoBase64 || null,
      stsBase64: profile.stsBase64 || backup.stsBase64 || null,
      osagoBase64: profile.osagoBase64 || backup.osagoBase64 || null,
      signatureBase64: profile.signatureBase64 || backup.signatureBase64 || null,
    };

    return {
      ok: true,
      phone,
      profile: {
        fullName: profile.fullName || '',
        phone: profile.phone || phone,
        inn: profile.inn || '',
        passport: profile.passport || '',
        email: profile.email || '',
        birthDate: profile.birthDate || null,
        carModel: profile.carModel || '',
        carColor: profile.carColor || '',
        carPlate: profile.carPlate || '',
        servedClasses: Array.isArray(profile.servedClasses) ? profile.servedClasses : [],
        docsSigned: Boolean(profile.docsSigned),
        registrationStatus: profile.registrationStatus || 'incomplete',
      },
      photos,
    };
  }

  @Get('drivers/:phone')
  async getDriverProfile(
    @Param('phone') phoneRaw: string,
    @Query('includePhotos') includePhotos?: string,
    @Headers('authorization') auth?: string,
  ) {
    this.requireAdmin(auth);
    const phone = await this.resolveDriverPhoneKey(phoneRaw);
    if (!phone) return { ok: false, error: 'not found' };

    const includeAllPhotos = includePhotos === '1' || includePhotos === 'true';
    const raw = await this.redis.client.get(this.driverProfileKey(phone));
    const backupRaw = await this.redis.client.get(this.driverPhotosBackupKey(phone));
    if (!raw && !backupRaw) return { ok: false, error: 'not found' };

    let profile: any = {};
    try { if (raw) profile = JSON.parse(raw); } catch { /* skip */ }
    let backup: any = {};
    try { if (backupRaw) backup = JSON.parse(backupRaw); } catch { /* skip */ }
    profile = await this.restoreProfilePhotosFromBackup(phone, profile, backup);
    const blockMeta = await this.drivers.getBlockMeta(phone);
    const adminComment = await this.redis.client.get(this.driverAdminCommentKey(phone));

    const regStatus = profile.registrationStatus || 'incomplete';
    const shouldIncludeVerificationPhotos = includeAllPhotos || regStatus === 'pending';
    const safeProfile = this.mergeDriverProfilePhotos(profile, backup, shouldIncludeVerificationPhotos);

    return {
      ok: true,
      profile: safeProfile,
      blockReason: blockMeta?.reason || null,
      blockUntil: blockMeta?.until || null,
      adminComment: adminComment || '',
    };
  }

  /** Погасить комиссию: обнуляем earnings водителя */
  @Post('drivers/:phone/commission/clear')
  async clearCommission(@Param('phone') phoneRaw: string, @Headers('authorization') auth?: string) {
    this.requireAdmin(auth);
    const phone = (phoneRaw || '').trim();
    if (!phone) return { ok: false };
    const earnings = await this.orders.getDriverEarnings(phone);
    await this.redis.client.hset(`driver:earnings:${phone}`, {
      commission: '0',
    });
    // Уведомляем водителя через сокет — лимит снят
    this.events.emitCommissionCleared(phone);
    return { ok: true, cleared: earnings };
  }

  @Get('clients')
  async listClients(@Headers('authorization') auth?: string) {
    this.requireAdmin(auth);
    const ids = await this.redis.client.smembers(this.clientsSet());
    if (!ids.length) return { ok: true, clients: [] };
    const pipeline = this.redis.client.pipeline();
    ids.forEach((id: string) => pipeline.get(this.clientProfileKey(id)));
    ids.forEach((id: string) => pipeline.get(this.clientBlockKey(id)));
    ids.forEach((id: string) => pipeline.get(this.clientBlockMetaKey(id)));
    ids.forEach((id: string) => pipeline.llen(`client:orders:${id}`));
    ids.forEach((id: string) => pipeline.get(this.clientAdminCommentKey(id)));
    const res = await pipeline.exec();
    const split = ids.length;
    const clients = ids.map((id: string, idx: number) => {
      const raw = typeof res?.[idx]?.[1] === 'string' ? (res?.[idx]?.[1] as string) : null;
      let profile: any = { id };
      try { if (raw) profile = JSON.parse(raw) as ClientProfile; } catch { /* skip corrupted */ }
      const blockRaw = typeof res?.[split + idx]?.[1] === 'string' ? (res?.[split + idx]?.[1] as string) : null;
      const blockMetaRaw = typeof res?.[split * 2 + idx]?.[1] === 'string' ? (res?.[split * 2 + idx]?.[1] as string) : null;
      let legacyBlock: any = null;
      try { if (blockRaw) legacyBlock = JSON.parse(blockRaw); } catch { legacyBlock = null; }
      let blockMeta: any = null;
      try { if (blockMetaRaw) blockMeta = JSON.parse(blockMetaRaw); } catch { blockMeta = null; }
      const blocked = !!blockRaw;
      const orderCountRaw = res?.[split * 3 + idx]?.[1];
      const orderCount = Number(orderCountRaw) || 0;
      const adminComment = typeof res?.[split * 4 + idx]?.[1] === 'string' ? (res?.[split * 4 + idx]?.[1] as string) : '';
      return {
        ...profile,
        blocked,
        blockReason: blockMeta?.reason || legacyBlock?.reason || null,
        blockUntil: blockMeta?.until || legacyBlock?.until || null,
        blockedAt: blockMeta?.blockedAt || legacyBlock?.blockedAt || null,
        adminComment,
        orderCount,
        ordersCount: orderCount,
      };
    });
    return { ok: true, clients };
  }

  @Post('clients')
  async upsertClient(@Body() body: ClientProfile, @Headers('authorization') auth?: string) {
    this.requireAdmin(auth);
    const id = (body.id || '').trim();
    if (!id) return { ok: false, error: 'id required' };
    await this.redis.client.set(this.clientProfileKey(id), JSON.stringify(body));
    await this.redis.client.sadd(this.clientsSet(), id);
    return { ok: true };
  }

  @Post('clients/:id/block')
  async blockClient(
    @Param('id') idRaw: string,
    @Body() body: { reason?: string },
    @Headers('authorization') auth?: string,
  ) {
    this.requireAdmin(auth);
    const id = (idRaw || '').trim();
    if (!id) return { ok: false };
    const reason = (body?.reason || '').trim() || 'manual';
    const ttlSec = 60 * 60 * 24 * 365;
    await this.redis.client.set(this.clientBlockKey(id), '1', 'EX', ttlSec);
    await this.redis.client.set(
      this.clientBlockMetaKey(id),
      JSON.stringify({ reason, blockedAt: new Date().toISOString() }),
      'EX',
      ttlSec,
    );
    return { ok: true, reason };
  }

  @Get('promos')
  async listPromos(@Headers('authorization') auth?: string) {
    this.requireAdmin(auth);
    const codes = await this.redis.client.smembers(this.promoSet());
    if (!codes.length) return { ok: true, promos: [] };
    const pipeline = this.redis.client.pipeline();
    codes.forEach((code: string) => pipeline.hgetall(this.promoKey(code)));
    const res = await pipeline.exec();
    const promos = codes.map((code: string, idx: number) => {
      const raw = (res?.[idx]?.[1] as Record<string, string>) || {};
      return {
        code,
        discount: Number(raw.discount || 0),
        active: raw.active !== 'false',
        expiresAt: raw.expiresAt || '',
        createdAt: raw.createdAt || '',
      };
    });
    return { ok: true, promos };
  }

  @Post('promos')
  async upsertPromo(
    @Body() body: { code?: string; discount?: number; active?: boolean; expiresAt?: string },
    @Headers('authorization') auth?: string,
  ) {
    this.requireAdmin(auth);
    const code = (body.code || '').toString().trim().toLowerCase();
    const discount = Math.max(0, Math.min(90, Math.round(Number(body.discount) || 0)));
    if (!code) return { ok: false, error: 'code required' };
    if (discount <= 0) return { ok: false, error: 'discount required' };
    const active = body.active !== false;
    const expiresAt = (body.expiresAt || '').toString().trim();
    const data: Record<string, string> = {
      code,
      discount: String(discount),
      active: active ? 'true' : 'false',
      updatedAt: new Date().toISOString(),
    };
    if (expiresAt) data.expiresAt = expiresAt;
    const existing = await this.redis.client.hgetall(this.promoKey(code));
    if (!existing || Object.keys(existing).length === 0) {
      data.createdAt = new Date().toISOString();
    }
    await this.redis.client.hset(this.promoKey(code), data);
    await this.redis.client.sadd(this.promoSet(), code);
    return { ok: true };
  }

  @Post('promos/:code/disable')
  async disablePromo(@Param('code') codeRaw: string, @Headers('authorization') auth?: string) {
    this.requireAdmin(auth);
    const code = (codeRaw || '').toString().trim().toLowerCase();
    if (!code) return { ok: false };
    await this.redis.client.hset(this.promoKey(code), {
      active: 'false',
      updatedAt: new Date().toISOString(),
    });
    return { ok: true };
  }

  @Post('clients/:id/unblock')
  async unblockClient(@Param('id') idRaw: string, @Headers('authorization') auth?: string) {
    this.requireAdmin(auth);
    const id = (idRaw || '').trim();
    if (!id) return { ok: false };
    await this.redis.client.del(this.clientBlockKey(id));
    await this.redis.client.del(this.clientBlockMetaKey(id));
    return { ok: true };
  }

  @Get('clients/:id/orders')
  async listClientOrders(
    @Param('id') idRaw: string,
    @Query('limit') limitRaw?: string,
    @Headers('authorization') auth?: string,
  ) {
    this.requireAdmin(auth);
    const id = (idRaw || '').trim();
    if (!id) return { ok: true, orders: [] };
    const limit = Math.min(200, Math.max(1, Number(limitRaw) || 50));
    const orders = await this.orders.listOrdersForClient(id, limit);
    return { ok: true, orders };
  }

  @Get('tariffs')
  async listTariffs(@Headers('authorization') auth?: string) {
    this.requireAdmin(auth);
    const raw = await this.redis.client.get('tariffs:list');
    let tariffs: any[] = [];
    try { if (raw) tariffs = JSON.parse(raw); } catch { /* corrupted tariffs */ }
    if (!tariffs.length) {
      tariffs = this.defaultTariffs();
    }
    return { ok: true, tariffs };
  }

  @Post('tariffs')
  async saveTariffs(@Body() body: { tariffs?: any[] }, @Headers('authorization') auth?: string) {
    const admin = this.requireAdmin(auth);
    const defaults = this.defaultTariffs();
    const rawList = Array.isArray(body.tariffs) ? body.tariffs : [];
    const source = rawList.length ? rawList : defaults;
    const tariffs = source.map((item, idx) => this.normalizeTariff(item, defaults[idx] || defaults[0]));
    await this.redis.client.set('tariffs:list', JSON.stringify(tariffs));
    await this.logAudit('tariffs.save_services', {
      admin: admin.login,
      details: `${tariffs.length} тарифов услуг`,
    });
    return { ok: true };
  }

  @Get('taxi-tariffs')
  async listTaxiTariffs(@Headers('authorization') auth?: string) {
    this.requireAdmin(auth);
    const raw = await this.redis.client.get('taxi_tariffs:list');
    let tariffs: any[] = [];
    try { if (raw) tariffs = JSON.parse(raw); } catch { /* corrupted */ }
    if (!Array.isArray(tariffs) || !tariffs.length) {
      tariffs = this.defaultTaxiTariffs();
    }
    return { ok: true, tariffs };
  }

  @Post('taxi-tariffs')
  async saveTaxiTariffs(@Body() body: { tariffs?: any[] }, @Headers('authorization') auth?: string) {
    const admin = this.requireAdmin(auth);
    const defaults = this.defaultTaxiTariffs();
    const rawList = Array.isArray(body.tariffs) ? body.tariffs : [];
    const source = rawList.length ? rawList : defaults;
    const tariffs = source.map((item, idx) => this.normalizeTaxiTariff(item, defaults[idx] || defaults[0]));
    await this.redis.client.set('taxi_tariffs:list', JSON.stringify(tariffs));
    await this.logAudit('tariffs.save_taxi', {
      admin: admin.login,
      details: tariffs.map((t) => t.id).join(', '),
    });
    return { ok: true, tariffs };
  }

  @Get('audit')
  async listAudit(
    @Query('limit') limitRaw?: string,
    @Headers('authorization') auth?: string,
  ) {
    this.requireAdmin(auth);
    const limit = Math.min(500, Math.max(1, Number(limitRaw) || 100));
    const raw = await this.redis.client.lrange(this.auditListKey(), 0, limit - 1);
    const entries: any[] = [];
    for (const line of raw || []) {
      if (typeof line !== 'string') continue;
      try {
        entries.push(JSON.parse(line));
      } catch {
        // skip corrupted
      }
    }
    return { ok: true, entries, total: entries.length };
  }

  @Get('orders/:id')
  async getOrderDetail(@Param('id') id: string, @Headers('authorization') auth?: string) {
    this.requireAdmin(auth);
    const order = await this.orders.getOrder(id);
    const [history, chat] = await Promise.all([
      this.orders.listStatusHistory(id, 50),
      this.orders.listChatMessages(id, 100),
    ]);
    let driverName = '';
    let clientName = '';
    if (order.driverPhone) {
      try {
        const raw = await this.redis.client.get(this.driverProfileKey(order.driverPhone));
        if (raw) driverName = JSON.parse(raw)?.fullName || '';
      } catch { /* skip */ }
    }
    if (order.clientId) {
      try {
        const raw = await this.redis.client.get(this.clientProfileKey(order.clientId));
        if (raw) clientName = JSON.parse(raw)?.fullName || JSON.parse(raw)?.name || '';
      } catch { /* skip */ }
    }
    const timeline = history.length
      ? [...history].reverse()
      : this.buildFallbackTimeline(order);
    return {
      ok: true,
      order: {
        ...order,
        driverName,
        clientName,
        clientPhone: order.clientId,
      },
      timeline,
      chat,
    };
  }

  @Get('stats/orders')
  async statsOrders(
    @Query('period') periodRaw?: string,
    @Query('mode') modeRaw?: string,
    @Headers('authorization') auth?: string,
  ) {
    this.requireAdmin(auth);
    const period = (['hour', 'day', 'month', 'year'].includes(periodRaw || '') ? periodRaw : 'day') as string;
    const mode = (['orders', 'company', 'drivers'].includes(modeRaw || '') ? modeRaw : 'orders') as string;

    type Bucket = { total: number; completed: number; canceled: number; revenue: number };
    const makeBucket = (): Bucket => ({ total: 0, completed: 0, canceled: 0, revenue: 0 });
    const now = new Date();

    // Prefer durable Redis day buckets when available (day/month/year).
    if (period === 'day' || period === 'month' || period === 'year') {
      const durable = await this.buildDurableStats(period, mode, now);
      if (durable) return durable;
    }

    const allOrders = await this.orders.getAllOrdersForStats(2000);

    if (period === 'hour') {
      const labels = Array.from({ length: 24 }, (_, i) => String(i).padStart(2, '0'));
      const buckets = labels.map(() => makeBucket());
      const cutoff = now.getTime() - 24 * 60 * 60 * 1000;
      for (const o of allOrders) {
        const ts = Date.parse(o.createdAt);
        if (ts < cutoff) continue;
        const h = new Date(ts).getHours();
        buckets[h].total++;
        if (o.status === 'completed') { buckets[h].completed++; buckets[h].revenue += Number(o.priceFinal || o.priceFrom || 0); }
        if (o.status === 'canceled') buckets[h].canceled++;
      }
      return this.buildStatsResponse(period, mode, labels, buckets, allOrders, cutoff);
    }

    if (period === 'day') {
      const labels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
      const buckets = labels.map(() => makeBucket());
      const cutoff = now.getTime() - 7 * 24 * 60 * 60 * 1000;
      for (const o of allOrders) {
        const ts = Date.parse(o.createdAt);
        if (ts < cutoff) continue;
        const jsDay = new Date(ts).getDay(); // 0=Sun
        const idx = jsDay === 0 ? 6 : jsDay - 1; // Mon=0 .. Sun=6
        buckets[idx].total++;
        if (o.status === 'completed') { buckets[idx].completed++; buckets[idx].revenue += Number(o.priceFinal || o.priceFrom || 0); }
        if (o.status === 'canceled') buckets[idx].canceled++;
      }
      return this.buildStatsResponse(period, mode, labels, buckets, allOrders, cutoff);
    }

    if (period === 'month') {
      const monthNames = ['Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июн', 'Июл', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек'];
      const labels: string[] = [];
      const buckets: Bucket[] = [];
      for (let i = 5; i >= 0; i--) {
        const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
        labels.push(monthNames[d.getMonth()]);
        buckets.push(makeBucket());
      }
      const sixMonthsAgo = new Date(now.getFullYear(), now.getMonth() - 5, 1).getTime();
      for (const o of allOrders) {
        const ts = Date.parse(o.createdAt);
        if (ts < sixMonthsAgo) continue;
        const d = new Date(ts);
        const monthDiff = (now.getFullYear() - d.getFullYear()) * 12 + (now.getMonth() - d.getMonth());
        const idx = 5 - monthDiff;
        if (idx < 0 || idx >= 6) continue;
        buckets[idx].total++;
        if (o.status === 'completed') { buckets[idx].completed++; buckets[idx].revenue += Number(o.priceFinal || o.priceFrom || 0); }
        if (o.status === 'canceled') buckets[idx].canceled++;
      }
      return this.buildStatsResponse(period, mode, labels, buckets, allOrders, sixMonthsAgo);
    }

    // year
    const yearsSet = new Set<number>();
    for (const o of allOrders) {
      const y = new Date(Date.parse(o.createdAt)).getFullYear();
      if (y > 2000) yearsSet.add(y);
    }
    const years = [...yearsSet].sort((a, b) => a - b);
    if (years.length === 0) years.push(now.getFullYear());
    const labels = years.map(String);
    const buckets = labels.map(() => makeBucket());
    for (const o of allOrders) {
      const y = new Date(Date.parse(o.createdAt)).getFullYear();
      const idx = years.indexOf(y);
      if (idx < 0) continue;
      buckets[idx].total++;
      if (o.status === 'completed') { buckets[idx].completed++; buckets[idx].revenue += Number(o.priceFinal || o.priceFrom || 0); }
      if (o.status === 'canceled') buckets[idx].canceled++;
    }
    return this.buildStatsResponse(period, mode, labels, buckets, allOrders, 0);
  }

  @Get('stats/cancel-reasons')
  async cancelReasonStats(
    @Query('limit') limitRaw?: string,
    @Headers('authorization') auth?: string,
  ) {
    this.requireAdmin(auth);
    const limit = Math.min(5000, Math.max(100, Number(limitRaw) || 2000));
    const orders = await this.orders.getAllOrdersForStats(limit);
    const stats = new Map<string, { reason: string; label: string; count: number; client: number; driver: number; admin: number; system: number }>();
    for (const order of orders) {
      if (order.status !== 'canceled') continue;
      const reason = String(order.cancelReason || '').trim() || 'unknown';
      const label = this.cancelReasonLabel(reason === 'unknown' ? '' : reason);
      const item = stats.get(reason) || {
        reason,
        label,
        count: 0,
        client: 0,
        driver: 0,
        admin: 0,
        system: 0,
      };
      item.count++;
      const by = String(order.canceledBy || 'system');
      if (by === 'client') item.client++;
      else if (by === 'driver') item.driver++;
      else if (by === 'admin') item.admin++;
      else item.system++;
      stats.set(reason, item);
    }
    const items = [...stats.values()].sort((a, b) => b.count - a.count || a.label.localeCompare(b.label, 'ru'));
    return {
      ok: true,
      total: items.reduce((sum, item) => sum + item.count, 0),
      items,
    };
  }

  private async buildDurableStats(period: string, mode: string, now: Date) {
    type Bucket = { total: number; completed: number; canceled: number; revenue: number };
    const makeBucket = (): Bucket => ({ total: 0, completed: 0, canceled: 0, revenue: 0 });
    const dayNamesRu = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    const monthNames = ['Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июн', 'Июл', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек'];

    const fetchDays = async (ymds: string[]) => {
      if (!ymds.length) return new Map<string, Bucket>();
      const pipeline = this.redis.client.pipeline();
      ymds.forEach((ymd) => pipeline.hgetall(`stats:day:${ymd}`));
      const res = await pipeline.exec();
      const map = new Map<string, Bucket>();
      ymds.forEach((ymd, idx) => {
        const raw = (res?.[idx]?.[1] || {}) as Record<string, string>;
        if (!raw || !Object.keys(raw).length) return;
        const bucket = {
          total: Number(raw.orders || 0),
          completed: Number(raw.completed || 0),
          canceled: Number(raw.canceled || 0),
          revenue: Number(raw.revenue || 0),
        };
        if (!bucket.total && !bucket.completed && !bucket.canceled && !bucket.revenue) return;
        map.set(ymd, bucket);
      });
      return map;
    };

    if (period === 'day') {
      const labels = dayNamesRu.slice();
      const buckets = labels.map(() => makeBucket());
      const ymds: string[] = [];
      for (let i = 6; i >= 0; i--) {
        const d = new Date(now.getTime() - i * 24 * 60 * 60 * 1000);
        ymds.push(this.orders.moscowDayString(d));
      }
      const dayMap = await fetchDays(ymds);
      if (!dayMap.size) return null;
      for (const ymd of ymds) {
        const stats = dayMap.get(ymd);
        if (!stats) continue;
        const jsDay = new Date(`${ymd}T12:00:00+03:00`).getDay();
        const idx = jsDay === 0 ? 6 : jsDay - 1;
        buckets[idx].total += stats.total;
        buckets[idx].completed += stats.completed;
        buckets[idx].canceled += stats.canceled;
        buckets[idx].revenue += stats.revenue;
      }
      return this.buildStatsResponse(period, mode, labels, buckets, [], 0, true);
    }

    if (period === 'month') {
      const labels: string[] = [];
      const buckets: Bucket[] = [];
      const ymds: string[] = [];
      const monthKeys: string[] = [];
      for (let i = 5; i >= 0; i--) {
        const monthStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - i, 1));
        const year = monthStart.getUTCFullYear();
        const month = monthStart.getUTCMonth();
        labels.push(monthNames[month]);
        buckets.push(makeBucket());
        const key = `${year}-${month}`;
        monthKeys.push(key);
        const daysInMonth = new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
        for (let day = 1; day <= daysInMonth; day++) {
          ymds.push(`${year}-${String(month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`);
        }
      }
      const dayMap = await fetchDays(ymds);
      if (!dayMap.size) return null;
      for (const [ymd, stats] of dayMap) {
        const [y, m] = ymd.split('-').map(Number);
        const key = `${y}-${m - 1}`;
        const idx = monthKeys.indexOf(key);
        if (idx < 0) continue;
        buckets[idx].total += stats.total;
        buckets[idx].completed += stats.completed;
        buckets[idx].canceled += stats.canceled;
        buckets[idx].revenue += stats.revenue;
      }
      return this.buildStatsResponse(period, mode, labels, buckets, [], 0, true);
    }

    // year — last 3 calendar years via durable day keys
    const years: number[] = [];
    for (let i = 2; i >= 0; i--) years.push(now.getFullYear() - i);
    const labels = years.map(String);
    const buckets = labels.map(() => makeBucket());
    const ymds: string[] = [];
    for (const year of years) {
      for (let month = 0; month < 12; month++) {
        const daysInMonth = new Date(Date.UTC(year, month + 1, 0)).getUTCDate();
        for (let day = 1; day <= daysInMonth; day++) {
          ymds.push(`${year}-${String(month + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`);
        }
      }
    }
    const dayMap = await fetchDays(ymds);
    if (!dayMap.size) return null;
    for (const [ymd, stats] of dayMap) {
      const y = Number(ymd.slice(0, 4));
      const idx = years.indexOf(y);
      if (idx < 0) continue;
      buckets[idx].total += stats.total;
      buckets[idx].completed += stats.completed;
      buckets[idx].canceled += stats.canceled;
      buckets[idx].revenue += stats.revenue;
    }
    return this.buildStatsResponse(period, mode, labels, buckets, [], 0, true);
  }

  private buildStatsResponse(
    period: string,
    mode: string,
    labels: string[],
    buckets: { total: number; completed: number; canceled: number; revenue: number }[],
    allOrders: any[],
    cutoff: number,
    fromDurable = false,
  ) {
    const fmt = (n: number) => n.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
    const periodNames: Record<string, string> = {
      hour: 'по часам', day: 'по дням недели', month: 'по месяцам', year: 'по годам',
    };
    const periodLabel = periodNames[period] || period;

    let totalAll: number;
    let completedAll: number;
    let canceledAll: number;
    let revenueAll: number;
    if (fromDurable) {
      totalAll = buckets.reduce((s, b) => s + b.total, 0);
      completedAll = buckets.reduce((s, b) => s + b.completed, 0);
      canceledAll = buckets.reduce((s, b) => s + b.canceled, 0);
      revenueAll = buckets.reduce((s, b) => s + b.revenue, 0);
    } else {
      const filteredOrders = cutoff > 0
        ? allOrders.filter((o: any) => Date.parse(o.createdAt) >= cutoff)
        : allOrders;
      totalAll = filteredOrders.length;
      completedAll = filteredOrders.filter((o: any) => o.status === 'completed').length;
      canceledAll = filteredOrders.filter((o: any) => o.status === 'canceled').length;
      revenueAll = filteredOrders
        .filter((o: any) => o.status === 'completed')
        .reduce((s: number, o: any) => s + Number(o.priceFinal || o.priceFrom || 0), 0);
    }
    const avgCheck = completedAll > 0 ? Math.round(revenueAll / completedAll) : 0;
    const conversionPct = totalAll > 0 ? Math.round((completedAll / totalAll) * 100) : 0;
    const cancelPct = totalAll > 0 ? ((canceledAll / totalAll) * 100).toFixed(1) : '0';

    if (mode === 'orders') {
      return {
        ok: true,
        source: fromDurable ? 'durable' : 'orders-scan',
        title: `Статистика заказов ${periodLabel}`,
        labels,
        series: [
          { name: 'Завершено', values: buckets.map((b) => b.completed) },
          { name: 'Отменено', values: buckets.map((b) => b.canceled) },
          { name: 'Новые', values: buckets.map((b) => b.total) },
        ],
        list: [
          { k: 'Всего заказов', v: fmt(totalAll) },
          { k: 'Завершено', v: fmt(completedAll) },
          { k: 'Отменено', v: fmt(canceledAll) },
          { k: 'Конверсия', v: `${conversionPct}%` },
        ],
      };
    }

    if (mode === 'company') {
      return {
        ok: true,
        source: fromDurable ? 'durable' : 'orders-scan',
        title: `Заказы ${periodLabel} (компания)`,
        labels,
        series: [
          { name: 'Заказы', values: buckets.map((b) => b.total) },
          { name: 'Доход (тыс)', values: buckets.map((b) => Math.round(b.revenue / 1000)) },
          { name: 'Отмены', values: buckets.map((b) => b.canceled) },
        ],
        list: [
          { k: 'Заказов', v: fmt(totalAll) },
          { k: 'Доход', v: `${fmt(Math.round(revenueAll))} ₽` },
          { k: 'Средний чек', v: `${fmt(avgCheck)} ₽` },
          { k: 'Отмены', v: `${cancelPct}%` },
        ],
      };
    }

    // mode === 'drivers'
    const driverPhones = new Set<string>();
    if (!fromDurable) {
      const filteredOrders = cutoff > 0
        ? allOrders.filter((o: any) => Date.parse(o.createdAt) >= cutoff)
        : allOrders;
      filteredOrders.forEach((o: any) => { if (o.driverPhone) driverPhones.add(o.driverPhone); });
    }
    return {
      ok: true,
      source: fromDurable ? 'durable' : 'orders-scan',
      title: `Поездки ${periodLabel} (водители)`,
      labels,
      series: [
        { name: 'Поездки', values: buckets.map((b) => b.completed) },
        { name: 'Заказы', values: buckets.map((b) => b.total) },
        { name: 'Отмены', values: buckets.map((b) => b.canceled) },
      ],
      list: [
        { k: 'Активных водителей', v: fromDurable ? '—' : String(driverPhones.size) },
        { k: 'Поездок', v: fmt(completedAll) },
        { k: 'Заказов', v: fmt(totalAll) },
        { k: 'Отмены водителями', v: `${cancelPct}%` },
      ],
    };
  }

  @Post('orders/:id/cancel')
  async adminCancel(
    @Param('id') id: string,
    @Body() body: { reason?: string },
    @Headers('authorization') auth?: string,
  ) {
    const admin = this.requireAdmin(auth);
    const order = await this.orders.adminCancel(id, body?.reason);
    this.events.emitOrderStatus(order);
    await this.logAudit('order.cancel', {
      admin: admin.login,
      target: id,
      details: body?.reason || order.cancelReason || '',
    });
    return { ok: true, order };
  }

  @Post('orders/:id/assign')
  async assignOrder(
    @Param('id') id: string,
    @Body() body: { driverPhone?: string },
    @Headers('authorization') auth?: string,
  ) {
    const admin = this.requireAdmin(auth);
    const driverPhone = (body?.driverPhone || '').trim();
    if (!driverPhone) return { ok: false, error: 'driverPhone required' };
    const order = await this.orders.assignDriver(id, driverPhone);
    this.events.emitOrderNew(order, [driverPhone]).catch(() => undefined);
    this.events.emitOrderStatus(order);
    await this.logAudit('order.assign', {
      admin: admin.login,
      target: id,
      details: driverPhone,
    });
    return { ok: true, order };
  }

  @Post('orders/:id/pay')
  async adminPay(@Param('id') id: string, @Headers('authorization') auth?: string) {
    this.requireAdmin(auth);
    const order = await this.orders.markPaid(id);
    return { ok: true, order };
  }

  @Get('payouts')
  async listPayouts(
    @Query('limit') limitRaw?: string,
    @Query('driverPhone') driverPhone?: string,
    @Headers('authorization') auth?: string,
  ) {
    this.requireAdmin(auth);
    const limit = Math.min(200, Math.max(1, Number(limitRaw) || 50));
    const payouts = await this.orders.listPayouts(limit, driverPhone?.trim() || undefined);
    return { ok: true, payouts };
  }

  @Post('payouts')
  async createPayout(
    @Body() body: { driverPhone?: string; amount?: number; orderId?: string },
    @Headers('authorization') auth?: string,
  ) {
    this.requireAdmin(auth);
    const driverPhone = (body.driverPhone || '').trim();
    const amount = Number(body.amount || 0);
    if (!driverPhone || !Number.isFinite(amount) || amount <= 0) {
      return { ok: false, error: 'driverPhone and amount required' };
    }
    const payout = await this.orders.createPayout({
      driverPhone,
      amount,
      orderId: body.orderId?.trim(),
    });
    return { ok: true, payout };
  }

  // Driver admin comments
  @Get('drivers/:phone/comment')
  async getDriverComment(@Param('phone') phoneRaw: string, @Headers('authorization') auth?: string) {
    this.requireAdmin(auth);
    const phone = (phoneRaw || '').trim();
    if (!phone) return { ok: false, error: 'phone required' };
    const comment = await this.redis.client.get(this.driverAdminCommentKey(phone));
    return { ok: true, comment: comment || '' };
  }

  @Post('drivers/:phone/comment')
  async setDriverComment(
    @Param('phone') phoneRaw: string,
    @Body() body: { comment?: string },
    @Headers('authorization') auth?: string,
  ) {
    this.requireAdmin(auth);
    const phone = (phoneRaw || '').trim();
    if (!phone) return { ok: false, error: 'phone required' };
    const key = this.driverAdminCommentKey(phone);
    if (!body?.comment || !body.comment.trim()) {
      await this.redis.client.del(key);
      return { ok: true, comment: '' };
    }
    await this.redis.client.set(key, body.comment.trim());
    return { ok: true, comment: body.comment.trim() };
  }

  // Client admin comments
  @Get('clients/:id/comment')
  async getClientComment(@Param('id') idRaw: string, @Headers('authorization') auth?: string) {
    this.requireAdmin(auth);
    const id = (idRaw || '').trim();
    if (!id) return { ok: false, error: 'id required' };
    const comment = await this.redis.client.get(this.clientAdminCommentKey(id));
    return { ok: true, comment: comment || '' };
  }

  @Post('clients/:id/comment')
  async setClientComment(
    @Param('id') idRaw: string,
    @Body() body: { comment?: string },
    @Headers('authorization') auth?: string,
  ) {
    this.requireAdmin(auth);
    const id = (idRaw || '').trim();
    if (!id) return { ok: false, error: 'id required' };
    const key = this.clientAdminCommentKey(id);
    if (!body?.comment || !body.comment.trim()) {
      await this.redis.client.del(key);
      return { ok: true, comment: '' };
    }
    await this.redis.client.set(key, body.comment.trim());
    return { ok: true, comment: body.comment.trim() };
  }

  @Get('antifraud/settings')
  async getAntifraudSettings(@Headers('authorization') auth?: string) {
    this.requireAdmin(auth);
    const settings = await this.drivers.getAntifraudSettings();
    return { ok: true, ...settings };
  }

  @Post('antifraud/settings')
  async setAntifraudSettings(
    @Body() body: { maxDeclinesPerDay?: number; autoBlockAfterSkips?: number; blockHours?: number },
    @Headers('authorization') auth?: string,
  ) {
    this.requireAdmin(auth);
    const settings = await this.drivers.setAntifraudSettings({
      maxDeclinesPerDay: body?.maxDeclinesPerDay,
      autoBlockAfterSkips: body?.autoBlockAfterSkips,
      blockHours: body?.blockHours,
    });
    return { ok: true, ...settings };
  }
}
