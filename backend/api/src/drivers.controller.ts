import { BadRequestException, Body, Controller, ForbiddenException, Get, Headers, Param, Post, Query, UnauthorizedException } from '@nestjs/common';
import jwt from 'jsonwebtoken';
import { DriversService } from './drivers.service';
import { OrdersService } from './orders.service';
import { RedisService } from './redis.service';

@Controller('driver')
export class DriversController {
  constructor(
    private readonly drivers: DriversService,
    private readonly orders: OrdersService,
    private readonly redis: RedisService,
  ) {}

  private pushTokenKey(phone: string) {
    return `driver:push_token:${phone}`;
  }

  private photosBackupKey(phone: string) {
    return `driver:photos_backup:${phone}`;
  }

  private stripProfilePhotos(profile: Record<string, any>) {
    delete profile.avatarBase64;
    delete profile.passportFrontBase64;
    delete profile.passportRegBase64;
    delete profile.driverLicenseBackBase64;
    delete profile.selfieBase64;
    delete profile.carPhotoBase64;
    delete profile.stsBase64;
    delete profile.osagoBase64;
    delete profile.signatureBase64;
  }

  private normalizePhoneForCompare(raw?: string | null) {
    const digits = (raw || '').toString().replace(/\D/g, '');
    if (!digits) return '';
    if (digits.length === 10) return `7${digits}`;
    if (digits.length === 11 && (digits.startsWith('7') || digits.startsWith('8'))) {
      return `7${digits.slice(1)}`;
    }
    return digits;
  }

  private hasVerificationRequiredFields(profile: Record<string, any>) {
    return Boolean(
      (profile.fullName || '').toString().trim() &&
      (profile.inn || '').toString().trim() &&
      (profile.passport || '').toString().trim(),
    );
  }

  private hasVerificationPhotos(profile: Record<string, any>) {
    return Boolean(
      profile.passportFrontBase64 &&
      profile.passportRegBase64 &&
      profile.driverLicenseBackBase64 &&
      profile.selfieBase64,
    );
  }

  private isVerificationConsistent(profile: Record<string, any>) {
    return Boolean(
      profile.docsSigned === true &&
      this.hasVerificationRequiredFields(profile) &&
      this.hasVerificationPhotos(profile),
    );
  }

  /** Не затираем фото при partial-save: null/короткая строка = «не менять». */
  private pickPhotoValue(
    incoming: string | null | undefined,
    existing: string | null | undefined,
    backup: string | null | undefined,
  ): string | null {
    if (typeof incoming === 'string' && incoming.trim().length > 64) {
      const value = incoming.trim();
      if (value.length > 8 * 1024 * 1024) {
        throw new BadRequestException('Photo is too large');
      }
      return value;
    }
    if (typeof existing === 'string' && existing.trim()) return existing.trim();
    if (typeof backup === 'string' && backup.trim()) return backup.trim();
    return null;
  }

  private async readPhotosBackup(phone: string): Promise<Record<string, any>> {
    const backupRaw = await this.redis.client.get(this.photosBackupKey(phone));
    if (!backupRaw) return {};
    try {
      const parsed = JSON.parse(backupRaw);
      return parsed && typeof parsed === 'object' ? parsed : {};
    } catch {
      return {};
    }
  }

  private async savePhotosBackup(phone: string, profile: Record<string, any>, existingBackup: Record<string, any> = {}) {
    const backup = {
      avatarBase64: profile.avatarBase64 || existingBackup.avatarBase64 || null,
      passportFrontBase64: profile.passportFrontBase64 || existingBackup.passportFrontBase64 || null,
      passportRegBase64: profile.passportRegBase64 || existingBackup.passportRegBase64 || null,
      driverLicenseBackBase64: profile.driverLicenseBackBase64 || existingBackup.driverLicenseBackBase64 || null,
      selfieBase64: profile.selfieBase64 || existingBackup.selfieBase64 || null,
      carPhotoBase64: profile.carPhotoBase64 || existingBackup.carPhotoBase64 || null,
      stsBase64: profile.stsBase64 || existingBackup.stsBase64 || null,
      osagoBase64: profile.osagoBase64 || existingBackup.osagoBase64 || null,
      signatureBase64: profile.signatureBase64 || existingBackup.signatureBase64 || null,
      updatedAt: new Date().toISOString(),
    };
    await this.redis.client.set(this.photosBackupKey(phone), JSON.stringify(backup));
  }

  private requireDriverPhone(auth?: string) {
    const token = auth?.replace(/^Bearer\s+/i, '').trim();
    if (!token) throw new UnauthorizedException('Driver token required');
    const secret = process.env.JWT_SECRET;
    if (!secret) throw new UnauthorizedException('Server configuration error');
    let payload: any;
    try {
      payload = jwt.verify(token, secret) as any;
    } catch {
      throw new UnauthorizedException('Invalid token');
    }
    if (!payload || payload.role !== 'driver' || typeof payload.phone !== 'string' || !payload.phone.trim()) {
      throw new UnauthorizedException('Driver token required');
    }
    return payload.phone.trim();
  }

  @Get('profile')
  async getProfile(
    @Query('phone') phone?: string,
    @Query('lite') lite?: string,
    @Query('full') full?: string,
    @Query('photos') photos?: string,
    @Headers('authorization') auth?: string,
  ) {
    const normalized = this.requireDriverPhone(auth);
    if (phone && phone.trim() && this.normalizePhoneForCompare(phone) !== this.normalizePhoneForCompare(normalized)) {
      throw new ForbiddenException('Driver token mismatch');
    }
    const fullMode =
      full === '1' || full === 'true' || photos === '1' || photos === 'true';
    const liteMode =
      !fullMode && lite !== '0' && lite !== 'false';

    const [
      profile,
      bonus,
      rating,
      earnings,
      stats,
      blocked,
      blockMeta,
      earningsLimitRaw,
      subSettings,
      orderAcceptTimeoutSec,
      subscriptionPaidUntil,
      subscriptionOverdue,
      backupRaw,
    ] = await Promise.all([
      liteMode ? this.drivers.getProfileLite(normalized) : this.drivers.getProfile(normalized),
      this.drivers.getBonus(normalized),
      this.orders.getDriverRating(normalized),
      this.orders.getDriverEarnings(normalized),
      this.orders.getDriverStats(normalized),
      this.redis.client.exists(`driver:block:${normalized}`),
      this.drivers.getBlockMeta(normalized),
      this.redis.client.get('settings:earnings_limit'),
      this.drivers.getSubscriptionSettings(),
      this.drivers.getOrderAcceptTimeoutSec(),
      this.drivers.getSubscriptionPaidUntil(normalized),
      this.drivers.isSubscriptionOverdue(normalized),
      liteMode ? Promise.resolve(null) : this.redis.client.get(this.photosBackupKey(normalized)),
    ]);
    let photosBackup: any = {};
    if (!liteMode && backupRaw) {
      try { photosBackup = JSON.parse(backupRaw); } catch { /* ignore corrupted backup */ }
    }
    const baseProfile = profile && typeof profile === 'object' ? (profile as Record<string, unknown>) : {};
    const earningsLimit = Number(earningsLimitRaw || 15000);
    const safeProfile: Record<string, any> = {
      ...baseProfile,
      ...(liteMode
        ? {}
        : {
            avatarBase64: (baseProfile as any).avatarBase64 || photosBackup.avatarBase64 || null,
            passportFrontBase64: (baseProfile as any).passportFrontBase64 || photosBackup.passportFrontBase64 || null,
            passportRegBase64: (baseProfile as any).passportRegBase64 || photosBackup.passportRegBase64 || null,
            driverLicenseBackBase64: (baseProfile as any).driverLicenseBackBase64 || photosBackup.driverLicenseBackBase64 || null,
            selfieBase64: (baseProfile as any).selfieBase64 || photosBackup.selfieBase64 || null,
            carPhotoBase64: (baseProfile as any).carPhotoBase64 || photosBackup.carPhotoBase64 || null,
            stsBase64: (baseProfile as any).stsBase64 || photosBackup.stsBase64 || null,
            osagoBase64: (baseProfile as any).osagoBase64 || photosBackup.osagoBase64 || null,
            signatureBase64: (baseProfile as any).signatureBase64 || photosBackup.signatureBase64 || null,
          }),
      rating: rating.avg,
      ratingCount: rating.count,
      earnedRub: Math.round(Number(earnings.net || 0)),
      earnedGross: Math.round(Number(earnings.gross || 0)),
      earnedCommission: Math.round(Number(earnings.commission || 0)),
      earnedPaid: Math.round(Number(earnings.paid || 0)),
      earnedAvailable: Math.round(Number(earnings.available || 0)),
      acceptedOrders: stats.acceptedOrders,
      trips: stats.trips,
      blocked: blocked === 1,
      blockReason: blockMeta?.reason || null,
      blockUntil: blockMeta?.until || null,
      earningsLimit,
      limitReached: Number(earnings.commission || 0) >= earningsLimit,
      subscriptionPaidUntil: subscriptionPaidUntil || null,
      subscriptionOverdue,
      subscriptionAmount: subSettings.amount,
      subscriptionDayOfMonth: subSettings.dayOfMonth,
      orderAcceptTimeoutSec,
    };

    const statusRaw = (safeProfile.registrationStatus || '').toString().trim().toLowerCase();
    const profileForCheck = safeProfile;
    const isConsistent = this.isVerificationConsistent(profileForCheck);
    const hasAnyVerificationData = Boolean(
      (profileForCheck.fullName || '').toString().trim() ||
      (profileForCheck.inn || '').toString().trim() ||
      (profileForCheck.passport || '').toString().trim() ||
      profileForCheck.docsSigned === true ||
      profileForCheck.passportFrontBase64 ||
      profileForCheck.passportRegBase64 ||
      profileForCheck.driverLicenseBackBase64 ||
      profileForCheck.selfieBase64 ||
      profileForCheck.hasVerificationPhotos === true,
    );

    let healedStatus = statusRaw || 'incomplete';
    if (statusRaw === 'completed' && !isConsistent) {
      healedStatus = hasAnyVerificationData ? 'completed' : 'incomplete';
    } else if (statusRaw === 'pending' && !hasAnyVerificationData) {
      healedStatus = 'incomplete';
    } else if (statusRaw === 'pending') {
      healedStatus = 'pending';
    }

    if (healedStatus !== statusRaw) {
      (safeProfile as any).registrationStatus = healedStatus;
      if (!liteMode) {
        const full = await this.drivers.getProfile(normalized);
        const toSave = {
          ...(full && typeof full === 'object' ? full : baseProfile),
          registrationStatus: healedStatus,
          updatedAt: new Date().toISOString(),
        };
        await this.drivers.saveProfile(normalized, toSave as Record<string, unknown>);
      }
    }

    if (!fullMode) {
      this.stripProfilePhotos(safeProfile);
    }

    return { ok: true, profile: safeProfile, bonus };
  }

  @Get('trips')
  async getTrips(
    @Query('phone') phone?: string,
    @Query('limit') limitRaw?: string,
    @Query('offset') offsetRaw?: string,
    @Query('page') pageRaw?: string,
    @Headers('authorization') auth?: string,
  ) {
    const normalized = this.requireDriverPhone(auth);
    if (phone && phone.trim() && this.normalizePhoneForCompare(phone) !== this.normalizePhoneForCompare(normalized)) {
      throw new ForbiddenException('Driver token mismatch');
    }
    const limit = Math.min(100, Math.max(1, Number(limitRaw) || 50));
    const page = Math.max(1, Math.floor(Number(pageRaw) || 1));
    const offsetFromPage = (page - 1) * limit;
    const offset = Math.max(0, Math.floor(Number(offsetRaw) || offsetFromPage));
    const orders = await this.orders.listOrdersForDriver(normalized, limit, true, offset);
    const trips = orders
      .filter((o) => o.status === 'completed' || o.status === 'started' || o.status === 'accepted' || o.status === 'enroute' || o.status === 'arrived')
      .map((o) => ({
        id: o.id,
        status: o.status,
        fromAddress: o.fromAddress || '',
        toAddress: o.toAddress || '',
        priceFrom: o.priceFrom || 0,
        priceFinal: o.priceFinal || 0,
        startedAt: o.startedAt || o.acceptedAt || o.createdAt,
        completedAt: o.completedAt || null,
        tripMinutes: o.tripMinutes || 0,
        serviceIndex: o.serviceIndex || 0,
        rating: o.rating ?? null,
        ratedAt: o.ratedAt || null,
        paymentMethod: o.paymentMethod || null,
        scheduledAt: o.scheduledAt || null,
      }));
    return { ok: true, trips, limit, offset, page };
  }

  @Get('public/:phone')
  async getPublicProfile(@Param('phone') phoneRaw: string, @Headers('authorization') auth?: string) {
    // Require any valid authenticated user to reduce scraping.
    const token = auth?.replace(/^Bearer\s+/i, '').trim();
    if (!token) throw new UnauthorizedException('Authorization required');
    const secret = process.env.JWT_SECRET;
    if (!secret) throw new UnauthorizedException('Server configuration error');
    try {
      jwt.verify(token, secret);
    } catch {
      throw new UnauthorizedException('Invalid token');
    }
    const phone = await this.drivers.resolveProfilePhone(phoneRaw);
    if (!phone) throw new UnauthorizedException('phone required');
    const profile = ((await this.drivers.getProfile(phone)) as Record<string, any>) || {};
    const backupRaw = await this.redis.client.get(this.photosBackupKey(phone));
    let backup: Record<string, any> = {};
    if (backupRaw) {
      try {
        backup = JSON.parse(backupRaw);
      } catch {
        backup = {};
      }
    }
    const merged: Record<string, any> = {
      ...profile,
      avatarBase64: profile.avatarBase64 || backup.avatarBase64 || null,
      selfieBase64: profile.selfieBase64 || backup.selfieBase64 || null,
      passportFrontBase64: profile.passportFrontBase64 || backup.passportFrontBase64 || null,
    };
    const rating = await this.orders.getDriverRating(phone);
    return {
      ok: true,
      profile: {
        fullName: (merged?.fullName || profile?.fullName || '').toString(),
        // KYC documents and verification selfies must never become public avatars.
        avatarBase64: merged?.avatarBase64 || null,
        rating: rating.avg,
        ratingCount: rating.count,
      },
    };
  }

  @Post('profile')
  async saveProfile(
    @Headers('authorization') auth: string,
    @Body()
    body: {
      phone?: string;
      fullName?: string;
      inn?: string;
      passport?: string;
      avatarBase64?: string | null;
      passportFrontBase64?: string | null;
      passportRegBase64?: string | null;
      driverLicenseBackBase64?: string | null;
      selfieBase64?: string | null;
      carPhotoBase64?: string | null;
      stsBase64?: string | null;
      osagoBase64?: string | null;
      signatureBase64?: string | null;
      birthDate?: string;
      carModel?: string;
      carColor?: string;
      carPlate?: string;
      servedClasses?: string[];
      docsSigned?: boolean;
      registrationStatus?: string;
      referralCount?: number;
      referralCode?: string;
    },
  ) {
    const phone = this.requireDriverPhone(auth);
    const requestedRegistrationStatus = (body.registrationStatus || '').toString().trim().toLowerCase();
    const referralCode = (body.referralCode || '').toString().trim().replace(/\D/g, '');
    const existing = (await this.drivers.getProfile(phone)) as Record<string, any> | null;
    const photosBackup = await this.readPhotosBackup(phone);
    if (referralCode && referralCode !== phone && !(existing as any)?.referralCode) {
      const refProfile = await this.drivers.getProfile(referralCode);
      if (refProfile) {
        const nextCount = Math.max(0, Number((refProfile as any).referralCount || 0)) + 1;
        (refProfile as any).referralCount = nextCount;
        await this.drivers.saveProfile(referralCode, refProfile as Record<string, unknown>);
        if (nextCount % 3 === 0) {
          await this.drivers.addBonus(referralCode, 500);
        }
      }
    }
    const existingRegistrationStatus = ((existing as any)?.registrationStatus || '').toString().trim().toLowerCase();
    const mergedForValidation = {
      ...(existing as any),
      fullName: (body.fullName ?? existing?.fullName ?? '').toString(),
      inn: (body.inn ?? existing?.inn ?? '').toString(),
      passport: (body.passport ?? existing?.passport ?? '').toString(),
      passportFrontBase64: this.pickPhotoValue(body.passportFrontBase64, existing?.passportFrontBase64, photosBackup.passportFrontBase64),
      passportRegBase64: this.pickPhotoValue(body.passportRegBase64, existing?.passportRegBase64, photosBackup.passportRegBase64),
      driverLicenseBackBase64: this.pickPhotoValue(body.driverLicenseBackBase64, existing?.driverLicenseBackBase64, photosBackup.driverLicenseBackBase64),
      selfieBase64: this.pickPhotoValue(body.selfieBase64, existing?.selfieBase64, photosBackup.selfieBase64),
      docsSigned: body.docsSigned ?? existing?.docsSigned ?? false,
    } as Record<string, any>;
    const verificationConsistent = this.isVerificationConsistent(mergedForValidation);
    let nextRegistrationStatus = existingRegistrationStatus || 'incomplete';
    // completed — только admin меняет, статус не трогаем.
    // pending   — пока заявка на проверке, не сбрасываем в incomplete при обновлении профиля/фото.
    // rejected  — водитель может переподать заявку (→ pending).
    // incomplete — водитель может установить pending или остаться incomplete.
    if (existingRegistrationStatus === 'completed') {
      if (!verificationConsistent) {
        nextRegistrationStatus = requestedRegistrationStatus === 'pending' && verificationConsistent
          ? 'pending'
          : 'incomplete';
      } else if (requestedRegistrationStatus === 'pending' && verificationConsistent) {
        nextRegistrationStatus = 'pending';
      } else {
        nextRegistrationStatus = 'completed';
      }
    } else if (existingRegistrationStatus === 'pending') {
      // Заявка на проверке — не сбрасываем, пока админ не отклонит/подтвердит.
      nextRegistrationStatus = 'pending';
    } else if (existingRegistrationStatus === 'rejected') {
      nextRegistrationStatus = requestedRegistrationStatus === 'pending' && verificationConsistent
        ? 'pending'
        : 'rejected';
    } else {
      const hasMinimumPacket = this.hasVerificationRequiredFields(mergedForValidation) &&
        mergedForValidation.docsSigned === true;
      if (requestedRegistrationStatus === 'pending' && hasMinimumPacket) {
        // Заявка в админку даже если фото не дошли в этом POST (частая проблема на мобильном).
        nextRegistrationStatus = 'pending';
      } else if (requestedRegistrationStatus === 'pending' && verificationConsistent) {
        nextRegistrationStatus = 'pending';
      } else {
        nextRegistrationStatus = 'incomplete';
      }
    }
    // Повторное чтение перед записью: иначе автосохранение профиля с устройства
    // может затереть reject/approve админа устаревшим incomplete.
    const freshExisting = (await this.drivers.getProfile(phone)) as Record<string, any> | null;
    const freshStatus = ((freshExisting as any)?.registrationStatus || '').toString().trim().toLowerCase();
    if (freshStatus === 'rejected') {
      nextRegistrationStatus =
        nextRegistrationStatus === 'pending' && verificationConsistent ? 'pending' : 'rejected';
    } else if (freshStatus === 'completed') {
      if (nextRegistrationStatus === 'incomplete' || nextRegistrationStatus === 'pending') {
        nextRegistrationStatus = verificationConsistent && nextRegistrationStatus === 'pending'
          ? 'pending'
          : 'completed';
      }
    } else if (freshStatus === 'pending' && nextRegistrationStatus === 'incomplete') {
      nextRegistrationStatus = 'pending';
    }
    const profile = {
      phone,
      fullName: (body.fullName ?? existing?.fullName ?? '').toString(),
      inn: (body.inn ?? existing?.inn ?? '').toString(),
      passport: (body.passport ?? existing?.passport ?? '').toString(),
      email: (body as any)?.email ?? existing?.email ?? undefined,
      avatarBase64: this.pickPhotoValue(body.avatarBase64, existing?.avatarBase64, photosBackup.avatarBase64),
      passportFrontBase64: mergedForValidation.passportFrontBase64,
      passportRegBase64: mergedForValidation.passportRegBase64,
      driverLicenseBackBase64: mergedForValidation.driverLicenseBackBase64,
      selfieBase64: mergedForValidation.selfieBase64,
      carPhotoBase64: this.pickPhotoValue(body.carPhotoBase64, existing?.carPhotoBase64, photosBackup.carPhotoBase64),
      stsBase64: this.pickPhotoValue(body.stsBase64, existing?.stsBase64, photosBackup.stsBase64),
      osagoBase64: this.pickPhotoValue(body.osagoBase64, existing?.osagoBase64, photosBackup.osagoBase64),
      signatureBase64: this.pickPhotoValue(body.signatureBase64, existing?.signatureBase64, photosBackup.signatureBase64),
      birthDate: (body.birthDate ?? existing?.birthDate ?? '').toString(),
      carModel: (body.carModel ?? existing?.carModel ?? '').toString(),
      carColor: (body.carColor ?? existing?.carColor ?? '').toString(),
      carPlate: (body.carPlate ?? existing?.carPlate ?? '').toString(),
      servedClasses: Array.isArray(body.servedClasses)
        ? body.servedClasses.map((value) => value.toString()).filter(Boolean).slice(0, 10)
        : Array.isArray(existing?.servedClasses) ? existing.servedClasses : [],
      docsSigned: typeof body.docsSigned === 'boolean' ? body.docsSigned : Boolean(existing?.docsSigned),
      registrationStatus: nextRegistrationStatus,
      referralCount: Number.isFinite(Number(existing?.referralCount))
        ? Number(existing?.referralCount)
        : 0,
      referralCode: referralCode || existing?.referralCode || undefined,
      updatedAt: new Date().toISOString(),
    };
    await this.savePhotosBackup(phone, profile, photosBackup);
    // Keep large binary payloads only in the backup key. The normal profile and
    // response stay small, which is critical for mobile traffic and admin lists.
    const storedProfile: Record<string, any> = {
      ...profile,
      hasVerificationPhotos: this.hasVerificationPhotos(profile),
      hasAvatar: Boolean(profile.avatarBase64 || profile.selfieBase64),
      hasCarPhoto: Boolean(profile.carPhotoBase64),
      hasPassportPhoto: Boolean(profile.passportFrontBase64),
      hasSelfiePhoto: Boolean(profile.selfieBase64),
      hasDriverLicensePhoto: Boolean(profile.driverLicenseBackBase64),
      hasStsPhoto: Boolean(profile.stsBase64),
      hasOsagoPhoto: Boolean(profile.osagoBase64),
      hasSignaturePhoto: Boolean(profile.signatureBase64),
    };
    this.stripProfilePhotos(storedProfile);
    await this.drivers.saveProfile(phone, storedProfile);
    return { ok: true, profile: storedProfile };
  }
  @Post('push-token')
  async savePushToken(
    @Headers('authorization') auth?: string,
    @Body() body?: { token?: string; platform?: string },
  ) {
    const phone = this.requireDriverPhone(auth);
    const token = (body?.token || '').toString().trim();
    if (!token) {
      await this.redis.client.del(this.pushTokenKey(phone));
      return { ok: true, deleted: true };
    }
    if (token.length <= 20 || token.startsWith('local-')) {
      throw new BadRequestException('Invalid push token');
    }

    const payload = {
      token,
      platform: body?.platform === 'android' ? 'android' : 'ios',
      updatedAt: new Date().toISOString(),
    };
    await this.redis.client.set(this.pushTokenKey(phone), JSON.stringify(payload));
    return { ok: true };
  }
}

