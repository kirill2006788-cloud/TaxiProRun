import { Injectable, Logger } from '@nestjs/common';
import { createKvStore, KvStore } from './kv-store';
import { KvOtpStore, OtpStore } from './otp.store';
import { KvRateLimitStore, MemoryRateLimitStore, RateLimitStore } from './rate-limit.store';
import { RedisService } from '../redis.service';

/**
 * Provides OTP + rate-limit stores.
 * KV_BACKEND=memory → in-memory (no Redis required for unit tests).
 * KV_BACKEND=redis (default) → Redis-backed when RedisService is available.
 */
@Injectable()
export class StoreModuleService {
  private readonly logger = new Logger(StoreModuleService.name);
  readonly kv: KvStore;
  readonly otpStore: OtpStore;
  readonly rateLimit: RateLimitStore;

  constructor(private readonly redis: RedisService) {
    const backend = (process.env.KV_BACKEND || 'redis').trim().toLowerCase();
    if (backend === 'memory') {
      this.kv = createKvStore();
      this.otpStore = new KvOtpStore(this.kv);
      this.rateLimit = new MemoryRateLimitStore();
      this.logger.log('KV_BACKEND=memory — OTP/rate-limit use in-memory store');
    } else {
      this.kv = createKvStore(this.redis.client);
      this.otpStore = new KvOtpStore(this.kv);
      this.rateLimit = new KvRateLimitStore(this.kv);
      this.logger.log('KV_BACKEND=redis — OTP/rate-limit use Redis');
    }
  }
}
