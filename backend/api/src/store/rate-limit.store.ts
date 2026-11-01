import { KvStore, MemoryKvStore } from './kv-store';

export interface RateLimitResult {
  allowed: boolean;
  count: number;
  limit: number;
  retryAfterSec?: number;
}

export interface RateLimitStore {
  hit(bucket: string, limit: number, windowSec: number): Promise<RateLimitResult>;
}

export class KvRateLimitStore implements RateLimitStore {
  constructor(private readonly kv: KvStore) {}

  async hit(bucket: string, limit: number, windowSec: number): Promise<RateLimitResult> {
    const key = `rl:${bucket}`;
    const count = await this.kv.incr(key);
    if (count === 1) {
      await this.kv.expire(key, Math.max(1, windowSec));
    }
    if (count > limit) {
      const ttl = await this.kv.ttl(key);
      return {
        allowed: false,
        count,
        limit,
        retryAfterSec: ttl > 0 ? ttl : windowSec,
      };
    }
    return { allowed: true, count, limit };
  }
}

/** Pure in-memory rate limiter (no Redis required for unit tests). */
export class MemoryRateLimitStore implements RateLimitStore {
  private readonly inner = new KvRateLimitStore(new MemoryKvStore());

  hit(bucket: string, limit: number, windowSec: number): Promise<RateLimitResult> {
    return this.inner.hit(bucket, limit, windowSec);
  }
}
