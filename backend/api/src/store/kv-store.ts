/**
 * Thin key-value + counter abstraction.
 * Default: in-memory (unit tests / local without Redis).
 * Production: Redis via REDIS_URL / REDIS_HOST when KV_BACKEND=redis (default).
 */
export interface KvStore {
  get(key: string): Promise<string | null>;
  set(key: string, value: string, ttlSec?: number): Promise<void>;
  del(...keys: string[]): Promise<number>;
  incr(key: string): Promise<number>;
  expire(key: string, ttlSec: number): Promise<boolean>;
  ttl(key: string): Promise<number>;
}

type MemEntry = { value: string; expiresAt?: number };

export class MemoryKvStore implements KvStore {
  private readonly map = new Map<string, MemEntry>();

  private purge(key: string): MemEntry | undefined {
    const e = this.map.get(key);
    if (!e) return undefined;
    if (e.expiresAt != null && e.expiresAt <= Date.now()) {
      this.map.delete(key);
      return undefined;
    }
    return e;
  }

  async get(key: string): Promise<string | null> {
    const e = this.purge(key);
    return e ? e.value : null;
  }

  async set(key: string, value: string, ttlSec?: number): Promise<void> {
    const expiresAt =
      ttlSec != null && ttlSec > 0 ? Date.now() + Math.floor(ttlSec) * 1000 : undefined;
    this.map.set(key, { value, expiresAt });
  }

  async del(...keys: string[]): Promise<number> {
    let n = 0;
    for (const k of keys) {
      if (this.map.delete(k)) n += 1;
    }
    return n;
  }

  async incr(key: string): Promise<number> {
    const cur = await this.get(key);
    const next = (Number(cur) || 0) + 1;
    const e = this.map.get(key);
    const expiresAt = e?.expiresAt;
    this.map.set(key, { value: String(next), expiresAt });
    return next;
  }

  async expire(key: string, ttlSec: number): Promise<boolean> {
    const e = this.purge(key);
    if (!e) return false;
    e.expiresAt = Date.now() + Math.max(1, Math.floor(ttlSec)) * 1000;
    this.map.set(key, e);
    return true;
  }

  async ttl(key: string): Promise<number> {
    const e = this.map.get(key);
    if (!e) return -2;
    if (e.expiresAt == null) return -1;
    const left = Math.ceil((e.expiresAt - Date.now()) / 1000);
    if (left <= 0) {
      this.map.delete(key);
      return -2;
    }
    return left;
  }
}

export class RedisKvStore implements KvStore {
  constructor(private readonly redis: { get: Function; set: Function; del: Function; incr: Function; expire: Function; ttl: Function }) {}

  async get(key: string): Promise<string | null> {
    const v = await this.redis.get(key);
    return typeof v === 'string' ? v : null;
  }

  async set(key: string, value: string, ttlSec?: number): Promise<void> {
    if (ttlSec != null && ttlSec > 0) {
      await this.redis.set(key, value, 'EX', Math.floor(ttlSec));
    } else {
      await this.redis.set(key, value);
    }
  }

  async del(...keys: string[]): Promise<number> {
    if (!keys.length) return 0;
    return Number(await this.redis.del(...keys)) || 0;
  }

  async incr(key: string): Promise<number> {
    return Number(await this.redis.incr(key)) || 0;
  }

  async expire(key: string, ttlSec: number): Promise<boolean> {
    return (await this.redis.expire(key, Math.floor(ttlSec))) === 1;
  }

  async ttl(key: string): Promise<number> {
    return Number(await this.redis.ttl(key));
  }
}

export function createKvStore(redisClient?: { get: Function; set: Function; del: Function; incr: Function; expire: Function; ttl: Function }): KvStore {
  const backend = (process.env.KV_BACKEND || 'redis').trim().toLowerCase();
  if (backend === 'memory' || !redisClient) {
    return new MemoryKvStore();
  }
  return new RedisKvStore(redisClient);
}
