import { KvStore } from './kv-store';

export interface OtpRecord {
  hash: string;
  attempts: number;
}

export interface OtpStore {
  saveCode(phone: string, hash: string, ttlSec: number): Promise<void>;
  getHash(phone: string): Promise<string | null>;
  clearCode(phone: string): Promise<void>;
  setCooldown(phone: string, ttlSec: number): Promise<void>;
  getCooldownTtl(phone: string): Promise<number>;
  incrAttempts(phone: string, ttlSec: number): Promise<number>;
  clearAttempts(phone: string): Promise<void>;
}

export class KvOtpStore implements OtpStore {
  constructor(private readonly kv: KvStore) {}

  private codeKey(phone: string) {
    return `otp:code:${phone}`;
  }
  private cooldownKey(phone: string) {
    return `otp:cooldown:${phone}`;
  }
  private attemptsKey(phone: string) {
    return `otp:attempts:${phone}`;
  }

  async saveCode(phone: string, hash: string, ttlSec: number): Promise<void> {
    await this.kv.set(this.codeKey(phone), hash, ttlSec);
  }

  async getHash(phone: string): Promise<string | null> {
    return this.kv.get(this.codeKey(phone));
  }

  async clearCode(phone: string): Promise<void> {
    await this.kv.del(this.codeKey(phone));
  }

  async setCooldown(phone: string, ttlSec: number): Promise<void> {
    await this.kv.set(this.cooldownKey(phone), '1', ttlSec);
  }

  async getCooldownTtl(phone: string): Promise<number> {
    const t = await this.kv.ttl(this.cooldownKey(phone));
    return t > 0 ? t : 0;
  }

  async incrAttempts(phone: string, ttlSec: number): Promise<number> {
    const key = this.attemptsKey(phone);
    const n = await this.kv.incr(key);
    if (n === 1) await this.kv.expire(key, ttlSec);
    return n;
  }

  async clearAttempts(phone: string): Promise<void> {
    await this.kv.del(this.attemptsKey(phone));
  }
}
