# TaxiPro API — production readiness

NestJS backend for **Короли дорог** (`koroli-dorog-api`).

## Quick start

```bash
cd backend/api
npm ci
npm run build
NODE_ENV=production JWT_SECRET=… REDIS_HOST=… node dist/main.js
```

Health:

- `GET /api/health` — Redis + deps
- `GET /api/health/live` — process up
- `GET /api/health/ready` — ready to serve (Redis required)

## Order lifecycle (wire statuses)

Stored / emitted statuses (Flutter-compatible):

`searching → accepted → enroute → arrived → [waiting] → started → completed`

Cancellations: `canceled` (with `canceledBy`: client | driver | admin | system).

TZ aliases accepted on input and normalized:

| TZ / alias | Wire status |
|------------|-------------|
| `assigned`, `driver_assigned`, `driver_accepted` | `accepted` |
| `arriving`, `driver_arriving` | `enroute` |
| `driver_arrived` | `arrived` |
| `in_progress` | `started` |
| `cancelled*` | `canceled` |

Clients cannot advance trip status; only cancel. Drivers cannot set `searching`/`accepted` via free-form update (use accept). Transitions are actor-checked in `order-status.ts`.

Payment statuses: `unpaid → pending → paid | failed`; `paid → refunded`.

## Socket events (client parity)

| Event | Direction | Purpose |
|-------|-----------|---------|
| `order:new` | → driver | Incoming offer (+ accept timeout) |
| `order:offer_expired` | → driver | Offer timed out |
| `order:status` | → client/driver | Lifecycle update |
| `order:canceled` | → client/driver | Cancel |
| `order:taken` | → drivers | Remove from offer list |
| `order:nearby` | → driver | Nearby searching order |
| `order:chat` | ↔ | In-trip chat |
| `driver:location` | → client | Geo during trip |
| `payment:status` | → client/driver | Payment / refund |

## Env vars (production)

### Core

| Variable | Required | Notes |
|----------|----------|-------|
| `NODE_ENV` | yes | `production` forces OTP debug OFF |
| `JWT_SECRET` | yes | App JWT |
| `ADMIN_JWT_SECRET` | recommended | Admin panel JWT (falls back to `JWT_SECRET`) |
| `CORS_ORIGINS` | recommended | Comma-separated allowlist |
| `APP_VERSION` | recommended | Shown in `/health` |
| `BODY_LIMIT` | no | Default `30mb` |

### Redis

| Variable | Required | Notes |
|----------|----------|-------|
| `REDIS_HOST` | yes* | Default `redis` |
| `REDIS_PORT` | no | Default `6379` |
| `REDIS_PASSWORD` | if secured | |
| `KV_BACKEND` | no | `redis` (default) or `memory` (OTP/rate-limit only; unit tests) |

\*Orders/dispatch still use RedisService; host Redis for production.

### SMS / OTP

| Variable | Required | Notes |
|----------|----------|-------|
| `SMS_PROVIDER` | yes | `smsaero` (default) or `smsc` |
| `SMSAERO_EMAIL` / `SMSAERO_API_KEY` | if smsaero | |
| `SMSAERO_SIGN` | no | Sender name |
| `SMSC_LOGIN` / `SMSC_PASSWORD` | if smsc | |
| `OTP_TTL_SEC` | no | Default 300 |
| `OTP_COOLDOWN_SEC` | no | Default 60 |
| `OTP_MAX_ATTEMPTS` | no | Default 5 |
| `OTP_RATE_LIMIT_MAX` / `OTP_RATE_LIMIT_WINDOW_MS` | no | |
| `OTP_DEBUG_LOG` | **never in prod** | Forced off when `NODE_ENV=production` |
| `DEMO_OTP_*` / `TEST_OTP_*` | **never in prod** | Ignored in production |

### Push (FCM)

| Variable | Required | Notes |
|----------|----------|-------|
| `FIREBASE_SERVICE_ACCOUNT_PATH` | one of | Path to service-account JSON |
| `FIREBASE_SERVICE_ACCOUNT_JSON` | one of | Inline JSON (prefer path in prod) |

Events: order assigned/arriving/arrived/cancelled + chat.

### Payments

| Variable | Required | Notes |
|----------|----------|-------|
| `PAYMENT_CHECKOUT_URL` | for online pay | HTTPS checkout base |
| `PAYMENT_WEBHOOK_SECRET` | for online pay | HMAC secret |
| `FISCAL_PROVIDER` | no | Receipt stub label (default `stub`) |

Endpoints: `POST /api/payments/intents` (Idempotency-Key), `POST /api/payments/webhook`, `POST /api/payments/refunds`, `GET/POST /api/payments/receipts`, `GET /api/payments/audit`.

### Observability

| Variable | Required | Notes |
|----------|----------|-------|
| `SENTRY_DSN` | recommended | Soft-loads `@sentry/node` if installed |
| `SENTRY_ENVIRONMENT` | no | Defaults to `NODE_ENV` |
| `SENTRY_TRACES_SAMPLE_RATE` | no | Default `0.05` |
| `LOG_FORMAT` | no | `json` (default in production) or `text` |
| `LOG_LEVEL` | no | `error` \| `warn` \| `log` \| `debug` |
| `RATE_LIMIT_MAX` / `RATE_LIMIT_WINDOW_MS` | no | HTTP middleware |

### Admin hardening

| Variable | Notes |
|----------|-------|
| `ADMIN_IP_ALLOWLIST` | Optional comma list / prefixes |
| `ADMIN_LOGIN_MAX_ATTEMPTS` / `ADMIN_LOGIN_LOCK_MS` | |

## Postgres checklist (future durable store)

Current runtime is **Redis-backed**. For Postgres migration (not inventing credentials here):

1. Provision managed Postgres (private network, TLS, backups).
2. Set connection via env only, e.g. `DATABASE_URL` — never commit secrets.
3. Add migrations tool (Prisma/Knex/TypeORM) under `backend/api/migrations/` when introducing SQL schema.
4. Move orders, payments audit, receipts, users off Redis keys into tables; keep Redis for geo, OTP, rate limits, locks.
5. Run migrations in CI/CD before rolling new API pods.
6. Verify `/api/health/ready` after cutover.

See also `docs/PRODUCTION_CHECKLIST.md`.

## Quarantine

`src/_remote`, `src/_vps_live`, `*.patched.ts` — see `src/QUARANTINE.md`. Excluded from `tsc`.

## Remaining infra (out of repo)

- Managed Redis + (optional) Postgres hosting, TLS, backups
- CI: build, typecheck, image push, migrate, deploy
- Real acquiring PSP + OFD fiscal provider
- Install `@sentry/node` on hosts when `SENTRY_DSN` is set
- FCM service account file on disk (`FIREBASE_SERVICE_ACCOUNT_PATH`)
- SMS provider credentials
