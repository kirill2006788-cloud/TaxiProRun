# Backend production checklist (Короли дорог)

Do not commit real credentials. Fill values in the host secret store / `.env` on the server only.

## Before go-live

- [ ] `NODE_ENV=production`
- [ ] Strong unique `JWT_SECRET` and `ADMIN_JWT_SECRET`
- [ ] Redis reachable (`REDIS_HOST` / password); backups enabled
- [ ] SMS provider configured; confirm OTP arrives on a real handset
- [ ] Confirm `OTP_DEBUG_LOG` is unset and demo/test OTP phones are disabled
- [ ] FCM: place service account JSON; set `FIREBASE_SERVICE_ACCOUNT_PATH`
- [ ] Payments: HTTPS `PAYMENT_CHECKOUT_URL` + `PAYMENT_WEBHOOK_SECRET`; test webhook signature
- [ ] `CORS_ORIGINS` limited to real admin/web origins
- [ ] `SENTRY_DSN` set; `@sentry/node` installed on the image/host
- [ ] Health probes: `/api/health/live` + `/api/health/ready` wired in orchestrator
- [ ] TLS terminator in front of API (nginx/caddy/LB)
- [ ] Rate limits reviewed for OTP and public quote/create

## Postgres (when introducing durable SQL)

- [ ] Managed instance with private networking + automated backups
- [ ] `DATABASE_URL` (or discrete host/user/db/password vars) in secrets only
- [ ] Migration runner in deploy pipeline
- [ ] Dual-write or cutover plan from Redis order keys
- [ ] Retention / GDPR deletion path for PII

## CI (out of band)

- [ ] `npm run typecheck` / `npm run build` on every PR
- [ ] Container image build + scan
- [ ] Deploy to staging with smoke: health, OTP request (no debug), create quote

## Socket / push smoke

- [ ] Driver receives `order:new`, timeout → `order:offer_expired`, decline reassigns
- [ ] Client receives `order:status`, `driver:location`, `order:chat`, `payment:status`
- [ ] Backgrounded app gets FCM for assigned / arriving / arrived / cancelled / chat
