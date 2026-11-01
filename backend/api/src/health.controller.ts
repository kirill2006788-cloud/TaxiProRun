import { Controller, Get, ServiceUnavailableException } from '@nestjs/common';
import { RedisService } from './redis.service';
import { PushService } from './push.service';
import { SmsService } from './sms.service';

@Controller()
export class HealthController {
  constructor(
    private readonly redis: RedisService,
    private readonly push: PushService,
    private readonly sms: SmsService,
  ) {}

  @Get('health')
  async health() {
    return this.buildHealth(false);
  }

  /** Liveness — process is up (no dependency checks). */
  @Get('health/live')
  live() {
    return {
      ok: true,
      status: 'live',
      uptimeSec: Math.round(process.uptime()),
      ts: new Date().toISOString(),
    };
  }

  /** Readiness — Redis required for serving traffic. */
  @Get('health/ready')
  async ready() {
    return this.buildHealth(true);
  }

  private async buildHealth(strictReady: boolean) {
    const started = Date.now();
    let redisOk = false;
    try {
      const pong = await this.redis.client.ping();
      redisOk = String(pong).toUpperCase() === 'PONG';
    } catch {
      redisOk = false;
    }
    const payload = {
      ok: redisOk,
      status: redisOk ? 'ready' : 'degraded',
      redis: redisOk ? 'ok' : 'down',
      redisMs: Date.now() - started,
      push: this.push.isEnabled ? 'ok' : 'disabled',
      smsProvider: this.sms.providerName,
      kvBackend: (process.env.KV_BACKEND || 'redis').toLowerCase(),
      sentry: Boolean((process.env.SENTRY_DSN || '').trim()),
      uptimeSec: Math.round(process.uptime()),
      memoryRssMb: Math.round(process.memoryUsage().rss / 1024 / 1024),
      version: process.env.APP_VERSION || 'dev',
      nodeEnv: process.env.NODE_ENV || 'development',
      ts: new Date().toISOString(),
    };
    if (strictReady && !redisOk) throw new ServiceUnavailableException(payload);
    if (!strictReady && !redisOk) throw new ServiceUnavailableException(payload);
    return payload;
  }
}
