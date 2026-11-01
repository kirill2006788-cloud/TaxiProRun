import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { AppModule } from './app.module';
import { corsOrigin } from './cors-policy';
import { StoreModuleService } from './store/store.module';
import { initSentryIfConfigured, StructuredLogger } from './logging/structured-logger';

async function bootstrap() {
  initSentryIfConfigured();
  const logger = new StructuredLogger();

  if ((process.env.NODE_ENV || '').toLowerCase() === 'production') {
    if (process.env.OTP_DEBUG_LOG === '1') {
      logger.warn('OTP_DEBUG_LOG ignored in production (forced OFF)', 'bootstrap');
      delete process.env.OTP_DEBUG_LOG;
    }
  }

  const app = await NestFactory.create(AppModule, {
    bodyParser: false,
    logger,
    cors: {
      origin: corsOrigin,
      credentials: true,
    },
  });
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const express = require('express');
  const trustProxy = (process.env.TRUST_PROXY || '').split(',').map(value => value.trim()).filter(Boolean);
  if (trustProxy.length) app.getHttpAdapter().getInstance().set('trust proxy', trustProxy);
  app.use(express.json({ limit: process.env.BODY_LIMIT || '30mb' }));
  app.use(express.urlencoded({ extended: true, limit: process.env.BODY_LIMIT || '30mb' }));
  const rateLimit = app.get(StoreModuleService).rateLimit;
  app.use(async (req: any, res: any, next: any) => {
    const ip =
      (req.ip || req.socket?.remoteAddress || 'unknown')
        .toString()
        .trim();
    const path = (req.path || req.url || '').toString();
    if (req.method === 'GET' && /^\/api\/health(?:\/(?:live|ready))?$/.test(path)) return next();
    const isOtp = path.includes('/auth/otp');
    const normalizedPath = path
      .replace(/[0-9a-f]{8}-[0-9a-f-]{27,}/gi, ':id')
      .replace(/\/\d{7,}(?=\/|$)/g, '/:id');
    const key = `${ip}:${isOtp ? 'otp' : normalizedPath}`;
    const windowMs = Number(
      isOtp
        ? process.env.OTP_RATE_LIMIT_WINDOW_MS || 60_000
        : process.env.RATE_LIMIT_WINDOW_MS || 60_000,
    );
    const limit = Number(
      isOtp
        ? process.env.OTP_RATE_LIMIT_MAX || 12
        : process.env.RATE_LIMIT_MAX || 180,
    );
    try {
      const result = await rateLimit.hit(key, limit, Math.max(1, Math.ceil(windowMs / 1000)));
      if (!result.allowed) {
        res.setHeader('Retry-After', String(result.retryAfterSec || 60));
        return res.status(429).json({ ok: false, error: 'Too many requests' });
      }
      return next();
    } catch {
      return res.status(503).json({ ok: false, error: 'Rate limit store unavailable' });
    }
  });
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: false,
    }),
  );
  app.setGlobalPrefix('api');
  app.enableShutdownHooks();
  const port = Number(process.env.PORT || 3000);
  await app.listen(port, '0.0.0.0');
  logger.log(`API listening on :${port}`, 'bootstrap');
}
bootstrap();
