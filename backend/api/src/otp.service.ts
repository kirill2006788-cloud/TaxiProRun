import { BadRequestException, Injectable, UnauthorizedException } from '@nestjs/common';
import { createHash, randomInt } from 'crypto';
import { StoreModuleService } from './store/store.module';
import { isOtpDebugAllowed } from './sms.service';

@Injectable()
export class OtpService {
  constructor(private readonly stores: StoreModuleService) {}

  private normalizePhone(raw: string) {
    const digits = String(raw || '').replace(/\D/g, '');
    if (digits.length < 10 || digits.length > 15) {
      throw new BadRequestException('Invalid phone');
    }
    if (digits.length === 11 && digits.startsWith('8')) {
      return `+7${digits.slice(1)}`;
    }
    if (digits.length === 10) return `+7${digits}`;
    return `+${digits}`;
  }

  private hashCode(code: string) {
    return createHash('sha256').update(code).digest('hex');
  }

  private ttlSec() {
    return Math.max(60, Number(process.env.OTP_TTL_SEC || 300));
  }

  private cooldownSec() {
    return Math.max(15, Number(process.env.OTP_COOLDOWN_SEC || 60));
  }

  private maxAttempts() {
    return Math.max(3, Number(process.env.OTP_MAX_ATTEMPTS || 5));
  }

  private rateLimitMax() {
    return Math.max(3, Number(process.env.OTP_RATE_LIMIT_MAX || 12));
  }

  private rateLimitWindowSec() {
    return Math.max(30, Math.round(Number(process.env.OTP_RATE_LIMIT_WINDOW_MS || 60_000) / 1000));
  }

  private demoMatch(phone: string) {
    // Never honour demo/test OTP shortcuts in production.
    if ((process.env.NODE_ENV || '').toLowerCase() === 'production') {
      return null;
    }
    const demoPhone = (process.env.DEMO_OTP_PHONE || '').replace(/\D/g, '');
    const demoCode = (process.env.DEMO_OTP_CODE || '').trim();
    const testPhone = (process.env.TEST_OTP_PHONE || '').replace(/\D/g, '');
    const testCode = (process.env.TEST_OTP_CODE || '').trim();
    const normalizedDigits = phone.replace(/\D/g, '');

    if (demoPhone && demoCode && (normalizedDigits.endsWith(demoPhone) || demoPhone.endsWith(normalizedDigits))) {
      return demoCode;
    }
    if (testPhone && testCode && (normalizedDigits.endsWith(testPhone) || testPhone.endsWith(normalizedDigits))) {
      return testCode;
    }
    return null;
  }

  private async guardRateLimit(phone: string) {
    const result = await this.stores.rateLimit.hit(
      `otp:${phone}`,
      this.rateLimitMax(),
      this.rateLimitWindowSec(),
    );
    if (!result.allowed) {
      throw new BadRequestException('Too many OTP requests. Try later.');
    }
  }

  async requestOtp(rawPhone: string) {
    const phone = this.normalizePhone(rawPhone);
    await this.guardRateLimit(phone);

    const cooldown = await this.stores.otpStore.getCooldownTtl(phone);
    if (cooldown > 0) {
      throw new BadRequestException(`OTP cooldown active (${cooldown}s)`);
    }

    const demoCode = this.demoMatch(phone);
    const debugLog = isOtpDebugAllowed();
    const skipSms = Boolean(demoCode) || debugLog;
    const code = demoCode || String(randomInt(1000, 9999));
    const ttlSec = this.ttlSec();

    await this.stores.otpStore.saveCode(phone, this.hashCode(code), ttlSec);
    await this.stores.otpStore.clearAttempts(phone);
    await this.stores.otpStore.setCooldown(phone, this.cooldownSec());

    return { phone, code, ttlSec, skipSms };
  }

  async rollback(phone: string) {
    const normalized = this.normalizePhone(phone);
    await this.stores.otpStore.clearCode(normalized);
    await this.stores.otpStore.setCooldown(normalized, 1);
  }

  async verifyOtp(rawPhone: string, rawCode: string) {
    const phone = this.normalizePhone(rawPhone);
    const code = String(rawCode || '').trim();
    if (!/^\d{4,8}$/.test(code)) {
      throw new BadRequestException('Invalid code');
    }

    const demoCode = this.demoMatch(phone);
    if (demoCode && code === demoCode) {
      await this.stores.otpStore.clearCode(phone);
      await this.stores.otpStore.clearAttempts(phone);
      return { phone };
    }

    const stored = await this.stores.otpStore.getHash(phone);
    if (!stored) throw new UnauthorizedException('OTP expired or not requested');

    const attempts = await this.stores.otpStore.incrAttempts(phone, this.ttlSec());
    if (attempts > this.maxAttempts()) {
      await this.stores.otpStore.clearCode(phone);
      throw new UnauthorizedException('Too many invalid attempts');
    }

    if (stored !== this.hashCode(code)) {
      throw new UnauthorizedException('Invalid code');
    }

    await this.stores.otpStore.clearCode(phone);
    await this.stores.otpStore.clearAttempts(phone);
    return { phone };
  }
}
