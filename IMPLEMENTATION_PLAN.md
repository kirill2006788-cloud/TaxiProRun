# IMPLEMENTATION_PLAN — «КОРОЛИ ДОРОГ»

**Дата:** 16 июля 2026  
**Репозиторий:** `E:\project\Приложения\TaxiPro`  
**Junction:** `E:\project\TaxiProRun`  
**Цель:** production V1 (Yandex Go–level, адаптировано под такси + трезвый водитель)  
**Принцип:** эволюция существующего кода, **не rewrite**

**Легенда:** `[x]` DONE · `[ ]` TODO

---

## Сводка фаз

| Фаза | Название | Готовность | Приоритет |
|------|----------|------------|-----------|
| 1 | Фундамент / бренд / структура | **85%** | P2 |
| 2 | Авторизация OTP | **70%** | P0 |
| 3 | Гео + карты + маршрут | **65%** | P0 |
| 4 | Тарифы + server pricing | **40%** | P0 |
| 5 | Заказ + диспетчеризация | **60%** | P0 |
| 6 | Realtime (Socket) | **70%** | P0 |
| 7 | Профиль + автомобили клиента | **25%** | P1 |
| 8 | Чат поездки | **0%** | P1 |
| 9 | Оплата | **20%** | P1 |
| 10 | Push FCM | **15%** | P0 |
| 11 | Админ + durable DB | **45%** | P1 |
| 12 | Тесты + store release | **15%** | P0 |

---

## Фаза 1 — Фундамент, бренд, структура проекта

**Цель:** единая кодовая база, бренд «КОРОЛИ ДОРОГ», навигация, тема.

### Deliverables

- [x] Flutter monorepo: пассажир (root) + `driver_app/`
- [x] Бренд: gold/purple/dark — `lib/core/theme/app_theme.dart`, `driver_app/lib/core/theme/app_theme.dart`
- [x] go_router + shell — `lib/core/router/app_router.dart`, `driver_app/lib/core/router/app_router.dart`
- [x] Юридические тексты — `lib/data/legal_texts.dart`, `driver_app/lib/data/legal_texts.dart`
- [x] Junction для Windows — `E:\project\TaxiProRun`, `README.md`
- [x] Документация ключей — `docs/KEYS_CHECKLIST.md`, `docs/APP_ICON.md`
- [ ] Единый `melos` / workspace scripts для двух apps
- [ ] CI: `flutter analyze` + `flutter test` на PR

### Файлы

```
lib/main.dart
driver_app/lib/main.dart
lib/features/shell/main_shell.dart
driver_app/lib/features/shell/main_shell.dart
assets/images/logo.png
docs/STORE_CHECKLIST.md
```

---

## Фаза 2 — Авторизация (OTP + сессии)

**Цель:** production OTP, безопасные сессии, отключение demo-режима.

### Deliverables

- [x] OTP request/verify API — `backend/api/src/_vps_live/auth.controller.ts`
- [x] Пассажир OTP UI — `lib/features/auth/auth_screen.dart`, `lib/features/auth/providers/auth_provider.dart`
- [x] Водитель OTP UI — `driver_app/lib/features/auth/login_screen.dart`, `driver_app/lib/providers/auth_provider.dart`
- [x] JWT в secure storage — `lib/core/auth/auth_store.dart`, `driver_app/lib/core/auth/auth_store.dart`
- [x] Admin login — `backend/api/src/_vps_live/auth.controller.ts` `@Post('admin/login')`
- [ ] **SMS production на VPS** — `docs/SMS_SETUP.md`, `.env`: `SMS_*`, `OTP_DEBUG_LOG=0`
- [ ] **Refresh tokens** — новые файлы:
  - `backend/api/src/auth.controller.ts` → `POST /api/auth/refresh`, `POST /api/auth/logout`
  - `backend/api/src/refresh-token.service.ts`
  - Redis keys: `auth:refresh:{jti}`, `auth:blacklist:{jti}`
  - `lib/core/api/repositories/user_repository.dart` — auto-refresh в `ApiClient`
  - `driver_app/lib/core/api/api_client.dart` — то же
- [ ] **Mock OTP off в release** — `lib/core/api/api_config.dart`, `driver_app/lib/core/api/api_config.dart`:
  - `defaultValue: false` для release profile ИЛИ `assert(!kReleaseMode || !useMockApi)`
- [ ] Валидация сессии при старте без silent fallback — `auth_provider.dart` L86–88 (сейчас `catch → authenticated`)

### Чеклист

- [x] `POST /api/auth/otp/request`
- [x] `POST /api/auth/otp/verify` + role client/driver
- [ ] `POST /api/auth/refresh`
- [ ] `POST /api/auth/logout`
- [x] Экран ввода имени — `lib/features/auth/name_screen.dart`
- [ ] Rate limit OTP через Redis (сейчас in-memory `main.ts`)

---

## Фаза 3 — Гео, карты, маршрутизация

**Цель:** Yandex MapKit + suggest + routing в production-сборке.

### Deliverables

- [x] MapKit bridge + fallback — `lib/features/map/yandex_mapkit_bridge.dart`, `driver_app/lib/features/map/yandex_mapkit_bridge.dart`
- [x] Premium canvas fallback — `lib/features/map/premium_map_canvas.dart`
- [x] Geo suggest (server → Yandex → mock) — `lib/core/geo/geo_search_service.dart`
- [x] Yandex routing service — `lib/core/geo/yandex_routing_service.dart`
- [x] Address search UI — `lib/shared/widgets/address_search_field.dart`
- [x] Location permission flow — `lib/features/map/location_permission_flow.dart`
- [x] Run script с ключами — `scripts/run_with_keys.ps1` (если есть в junction)
- [ ] **Routing key в production build** — `docs/API_REMAINING.md`: `YANDEX_ROUTING_KEY` в `keys.local.env`
- [ ] Убрать mock-адреса из default booking — `booking_provider.dart` L444–470 (сейчас «ул. Ленина, 10»)
- [ ] Driver turn-by-turn (опционально V1.1) — `driver_app/lib/features/active_order/widgets/nav_map_placeholder.dart` → rename + Yandex Navigation SDK

### Чеклист

- [x] `MAPKIT_API_KEY` + `USE_YANDEX_MAPKIT=true`
- [x] `YANDEX_GEOCODER_KEY`, `YANDEX_GEOSUGGEST_KEY`
- [ ] `YANDEX_ROUTING_KEY` — цена и полилиния без haversine fallback
- [x] Reverse geocode на карте
- [ ] Geo proxy на backend (если нужен для web-admin suggest)

### Файлы

```
lib/core/config/map_config.dart
lib/core/geo/geo_config.dart
docs/YANDEX_MAPS_SETUP.md
docs/GEO_SEARCH_SETUP.md
```

---

## Фаза 4 — Тарифы и server-side pricing

**Цель:** единый источник цены — backend; клиент только отображает.

### Deliverables

- [x] Статические тарифы UI — `lib/data/tariffs.dart` (9 классов + sober)
- [x] Service types (taxi + 3 sober modes) — `lib/models/service_type.dart`
- [x] Server pricing при create — `backend/api/src/orders.service.ts` `computePrice()`
- [x] Taxi tariffs API — `backend/api/src/taxi.controller.ts` `GET /api/taxi/tariffs`
- [ ] **`POST /api/taxi/quote`** — добавить в `backend/api/src/taxi.controller.ts`:
  ```ts
  // Input: from, to, tariffId, serviceType, routeDistanceMeters, scheduledAt, options
  // Output: { priceFrom, breakdown, markupPercent, source: 'server' }
  ```
- [ ] Клиент: вызов quote вместо `_recalculatePrice()` — `lib/features/booking/providers/booking_provider.dart`
- [ ] Убрать silent mock fallback тарифов — `lib/core/api/repositories/order_repository.dart` L172–196
- [ ] Показ server price на Payment — `lib/features/payment/payment_screen.dart`, `lib/shared/widgets/fare_breakdown_sheet.dart`
- [ ] Синхронизация sober tariffs admin ↔ app — `backend/api/src/admin.controller.ts` tariffs section

### Чеклист

- [x] `GET /api/taxi/tariffs`
- [ ] `POST /api/taxi/quote`
- [x] `GET /api/tariffs` (sober, VPS)
- [ ] Клиент отправляет `routeDistanceMeters` из Yandex routing в quote/create
- [ ] Price mismatch guard: если quote ≠ create response → показать server price

### Файлы

```
lib/features/tariffs/tariffs_screen.dart
lib/features/booking/providers/booking_provider.dart
backend/api/src/orders.service.ts
backend/api/src/taxi.controller.ts
lib/core/api/api_config.dart  # ApiEndpoints.taxiQuote
```

---

## Фаза 5 — Заказ, статусы, диспетчеризация

**Цель:** полный lifecycle заказа без mock-данных.

### Deliverables

- [x] Create order API — `backend/api/src/orders.controller.ts` `POST /orders`
- [x] Cancel / rate — `orders.controller.ts`, `lib/features/confirmation/confirmation_screen.dart`, `lib/features/payment/rate_trip_screen.dart`
- [x] Driver accept/decline/status — `driver_app/lib/core/api/repositories/api_orders_repository.dart`
- [x] Status machine — `driver_app/lib/core/api/trip_status_machine.dart`
- [x] Admin assign/cancel — `admin/js/app.js`, `backend/api/src/admin.controller.ts`
- [x] Расширяющийся поиск водителей — `orders.service.ts` dispatch radii
- [ ] **Убрать mock trips из UI** — `lib/features/trips/trips_screen.dart` L312–321: показывать empty state, не `MockTrips`
- [ ] **Убрать mock recent addresses** — `lib/features/route/route_screen.dart` L95–99
- [ ] Idempotency `requestId` на клиенте — `lib/core/api/models/api_models.dart` `CreateOrderRequest`
- [ ] Scheduled orders UI polish — `lib/features/route/route_screen.dart` (дата есть; server `scheduledAt` — проверить E2E)
- [ ] Commission display driver — `driver_app/lib/shared/widgets/trip_summary_sheet.dart` (читает API — OK)

### Чеклист

- [x] `POST /api/orders`
- [x] `GET /api/orders/active/client`
- [x] `GET /api/orders/history/client`
- [x] `POST /api/orders/:id/cancel`
- [x] `POST /api/orders/:id/rate`
- [x] Driver: accept, enroute, arrived, started, completed
- [ ] E2E staging: client create → driver accept → complete → rate
- [ ] `restoreMockOrders` скрыть в release — `driver_app/lib/features/orders/orders_screen.dart` L200

---

## Фаза 6 — Realtime (Socket.IO)

**Цель:** стабильный realtime без polling-only режима.

### Deliverables

- [x] Gateway — `backend/api/src/_remote/events.gateway.ts` (деплой на VPS)
- [x] Passenger socket — `lib/core/api/socket_service.dart`, `lib/features/active_trip/active_trip_provider.dart`
- [x] Driver socket — `driver_app/lib/core/api/socket_service.dart`, `driver_app/lib/providers/app_providers.dart`
- [x] Location ticker — `driver_app/lib/core/api/driver_location_ticker.dart`
- [ ] **Консолидировать gateway в main src/** — скопировать `_remote/events.gateway.ts` → `backend/api/src/events.gateway.ts`, подключить в `app.module.ts`
- [ ] Passenger socket connect сразу после login — `lib/features/auth/providers/auth_provider.dart` (сейчас только в active trip)
- [ ] Reconnect backoff + offline banner — `lib/shared/widgets/connectivity_banner.dart` (есть; расширить для socket)
- [ ] Integration test socket ack — новый `backend/api/test/events.gateway.spec.ts`

### События (контракт)

| Событие | Направление | Статус |
|---------|-------------|--------|
| `order:new` | server → driver | [x] |
| `order:status` | server → client | [x] |
| `driver:location` | server → client | [x] |
| `order:accept` | driver → server | [x] |
| `order:update` | driver → server | [x] |
| `broadcast:new` | server → all | [x] |
| `chat:message` | bidirectional | [ ] фаза 8 |

---

## Фаза 7 — Профиль, автомобили клиента, KYC водителя

**Цель:** данные клиента/водителя полные для sober modes и модерации.

### Deliverables — клиент

- [x] Профиль OTP — `lib/features/profile/personal_data_screen.dart`, `account_screen.dart`
- [x] Избранные адреса (local) — `lib/features/profile/favorites_screen.dart`, `profile_provider.dart`
- [x] Промо / реферал — `promo_screen.dart`, `referral_screen.dart`; API `clients.controller.ts`
- [x] Поддержка — `support_tickets_screen.dart`, `support_repository.dart`
- [ ] **CRUD автомобилей клиента** — новые файлы:
  - `lib/models/client_vehicle.dart`
  - `lib/features/profile/vehicles_screen.dart`
  - `lib/features/profile/vehicle_edit_screen.dart`
  - `lib/core/api/repositories/vehicle_repository.dart`
  - `backend/api/src/vehicles.controller.ts` (или секция в `clients.controller.ts`)
  - Redis: `client:vehicles:{phone}` → JSON array
- [ ] Выбор авто при sober mode — `lib/features/route/route_screen.dart` или `preferences_screen.dart`
- [ ] Загрузка аватара — `lib/features/profile/profile_screen.dart` L310 (сейчас «скоро») → `POST /api/client/profile` multipart

### Deliverables — водитель

- [x] KYC wizard — `driver_app/lib/features/registration/registration_wizard_screen.dart`
- [x] Registration API — `backend/api/src/drivers.controller.ts`, `api_driver_profile_repository.dart`
- [x] Admin KYC review — `admin/js/app.js` verification section
- [ ] **Реальная загрузка фото** (не mock) — заменить:
  - `driver_app/lib/shared/photo_picker.dart` — убрать `MockPhotoData` fallback в release
  - `driver_app/lib/features/profile/profile_screen.dart` — `mockUploadAvatar` → API upload
  - `backend/api/src/drivers.controller.ts` — проверить лимиты base64 30mb (`main.ts` BODY_LIMIT)
- [ ] Earnings/payouts real API — сейчас mock в `driver_app/lib/data/mock_data.dart`

### Чеклист client vehicles

- [ ] `GET /api/client/vehicles`
- [ ] `POST /api/client/vehicles`
- [ ] `PUT /api/client/vehicles/:id`
- [ ] `DELETE /api/client/vehicles/:id`
- [ ] Поля: make, model, color, plate, year, photoUrl?
- [ ] Привязка к заказу: `CreateOrderInput.clientVehicleId`
- [ ] UI: список + добавить + выбрать по умолчанию

---

## Фаза 8 — Чат поездки

**Цель:** in-app чат клиент ↔ водитель на время активного заказа.

### Deliverables (все TODO)

- [ ] Backend:
  - `backend/api/src/chat.controller.ts` — `GET/POST /api/orders/:id/chat`
  - Redis: `order:chat:{orderId}` list capped 500 msgs
  - Socket: `chat:message` в `events.gateway.ts` — rooms `order:{id}`
- [ ] Passenger:
  - `lib/features/active_trip/trip_chat_screen.dart`
  - `lib/features/active_trip/active_trip_screen.dart` — заменить L84 snackbar на `context.push`
  - `lib/core/api/repositories/chat_repository.dart`
- [ ] Driver:
  - `driver_app/lib/features/active_order/trip_chat_screen.dart`
  - `driver_app/lib/features/active_order/active_order_screen.dart` — L261–263
- [ ] Push notify on new message (после фазы 10)
- [ ] Модерация: admin read-only в `admin/js/app.js` dispatch detail

### Чеклист

- [ ] Текстовые сообщения only (V1)
- [ ] Нет чата после `completed` / `canceled`
- [ ] Rate limit 30 msg/min per user
- [ ] UTF-8 + max 2000 chars

---

## Фаза 9 — Оплата (cash + card + SBP)

**Цель:** cash работает; card/SBP через эквайер.

### Deliverables

- [x] Cash flow — `lib/core/services/payment_service.dart`, `payment_screen.dart`
- [x] Payment methods UI (demo) — `lib/features/profile/payment_methods_screen.dart`
- [x] Promo discount — `clients.controller.ts`, `payment_screen.dart`
- [x] Bonus points — `clients.controller.ts`
- [ ] **Payment gateway** — `docs/PAYMENTS_SETUP.md`:
  - Backend: `backend/api/src/payments.controller.ts` — webhook, `paymentStatus`
  - `PAYMENT_URL` dart-define → `PaymentService.openCheckout()`
  - Убрать `comingSoonMessage` — `payment_service.dart` L48–49
- [ ] Receipt 54-ФЗ — `lib/features/payment/payment_receipt_screen.dart` + server fiscal hook
- [ ] Driver payout tracking — admin + driver profile

### Чеклист

- [x] `paymentMethod: cash` в create order
- [ ] `paymentMethod: sbp|card` + redirect URL
- [ ] Webhook `POST /api/payments/webhook`
- [ ] `paymentStatus: paid` → socket `order:status`
- [ ] Store listing: не обещать онлайн-оплату до [x] webhook

---

## Фаза 10 — Push (FCM)

**Цель:** реальные push клиенту и водителю.

### Deliverables

- [x] Local notifications fallback — `lib/core/services/push_service.dart`, `driver_app/lib/core/services/push_service.dart`
- [x] Push token API — `clients.controller.ts` `push-token`, `drivers.controller.ts`
- [x] Документация — `docs/PUSH_SETUP.md`
- [ ] Firebase SDK в оба `pubspec.yaml`
- [ ] `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`
- [ ] Заменить `getTokenForApi()` stub на `FirebaseMessaging.instance.getToken()`
- [ ] Server FCM sender — `backend/api/src/push.service.ts` (firebase-admin)
- [ ] Events: new order → driver, status → client, chat → both

### Чеклист

- [ ] `POST /api/client/push-token` с real FCM token
- [ ] `POST /api/driver/push-token`
- [ ] Background handler driver — `driver_app/lib/core/services/push_service.dart`
- [ ] Не крашит без google-services (graceful degrade) — [x] частично

---

## Фаза 11 — Админ, аналитика, durable DB

**Цель:** операционная панель + сохранность данных.

### Deliverables

- [x] Admin SPA — `admin/index.html`, `admin/js/app.js`, `admin/js/api.js`
- [x] Dispatch, KYC, tariffs, promos, antifraud — `admin/js/app.js`
- [x] Support admin — `admin/README.md`
- [x] Day stats buckets — `admin.controller.ts` `buildDurableStats`
- [ ] **Live map** вместо placeholder — `admin/js/app.js` L301–314 → Yandex Maps JS API
- [ ] **Postgres (или Mongo) для orders/profiles**:
  - `backend/api/src/database/` — TypeORM или Prisma
  - Sync: write-through Redis + async persist
  - Migrations folder
- [ ] **Backend consolidate**:
  - [ ] Merge `_vps_live/*` → `backend/api/src/`
  - [ ] Add missing: `otp.service.ts`, `sms.service.ts`, `tariffs.controller.ts`, `events.gateway.ts`
  - [ ] Single `app.module.ts` with `SupportController`
  - [ ] Delete duplicates: `admin.controller.patched.ts`, `drivers.service.patched.ts`
- [ ] Redis AOF + backup playbook — ops doc
- [ ] CORS strict mode — `main.ts` L22 fix

### Чеклист durable DB

- [ ] Таблицы: `orders`, `clients`, `drivers`, `support_tickets`, `client_vehicles`
- [ ] Redis остаётся для: geo index, online status, pub/sub cache
- [ ] Admin stats из SQL, не full scan Redis keys
- [ ] GDPR export/delete endpoint

---

## Фаза 12 — Тесты, hardening, store release

**Цель:** Google Play + App Store submission.

### Deliverables

- [x] Store checklist doc — `docs/STORE_CHECKLIST.md`
- [x] Version 1.0.0+1 — `pubspec.yaml` (проверить оба apps)
- [x] Иконка/splash docs — `docs/APP_ICON.md`
- [ ] **Тесты** (минимальный набор):
  - [ ] `test/booking_provider_test.dart` — quote integration mock
  - [ ] `test/order_repository_test.dart`
  - [ ] `test/auth_provider_test.dart`
  - [ ] `driver_app/test/orders_provider_test.dart`
  - [ ] `driver_app/test/trip_status_machine_test.dart`
  - [ ] `backend/api/test/orders.service.spec.ts` — pricing cases
  - [ ] `integration_test/e2e_order_test.dart` — staging only
- [ ] **Release builds**:
  ```powershell
  # Пассажир
  flutter build appbundle --release `
    --dart-define=USE_MOCK_API=false `
    --dart-define=API_BASE_URL=https://api.trezv7777.ru `
    --dart-define=MAPKIT_API_KEY=... `
    --dart-define=YANDEX_ROUTING_KEY=... `
    --dart-define=PAYMENT_URL=...

  # Водитель
  cd driver_app
  flutter build appbundle --release `
    --dart-define=API_BASE_URL=https://api.trezv7777.ru
  ```
- [ ] Keystore + Play App Signing
- [ ] Apple Developer + Archive
- [ ] Privacy policy public URL
- [ ] Data safety / Privacy Nutrition Labels
- [ ] Screenshots без placeholder/map hint
- [ ] Review notes: test OTP phone

### Release gate checklist

- [ ] `USE_MOCK_API=false` в обоих apps
- [ ] `flutter analyze` 0 errors
- [ ] `flutter test` green
- [ ] Staging E2E passed
- [ ] OTP demo disabled VPS
- [ ] FCM configured
- [ ] SMS live
- [ ] No «скоро» в primary user flows (или hidden)
- [ ] Server health `/api/health` → `redis: ok`

---

## Приоритетный backlog (порядок выполнения)

### Sprint A — «Убрать mock, real flows» (2–3 нед.)

1. [ ] Backend consolidate `_vps_live` → `src/` — `backend/api/src/`
2. [ ] `USE_MOCK_API=false` default + release assert — `api_config.dart` (оба apps)
3. [ ] Убрать `MockTrips` из `trips_screen.dart`, mock addresses из `route_screen.dart`
4. [ ] `POST /api/taxi/quote` + `booking_provider.dart` refactor
5. [ ] SMS prod — VPS `.env`
6. [ ] Staging E2E manual script в `docs/E2E_STAGING.md` (создать)

### Sprint B — «Production infra» (2 нед.)

7. [ ] FCM both apps — `docs/PUSH_SETUP.md`
8. [ ] Refresh tokens — `auth.controller.ts`
9. [ ] Postgres sync layer — `backend/api/src/database/`
10. [ ] Убрать silent mock fallback — `order_repository.dart`

### Sprint C — «V1 parity» (3–4 нед.)

11. [ ] Client vehicles — §фаза 7
12. [ ] Trip chat — §фаза 8
13. [ ] Payment gateway — §фаза 9
14. [ ] Driver real photo upload
15. [ ] Admin live map

### Sprint D — «Store» (1–2 нед.)

16. [ ] Tests §фаза 12
17. [ ] Release builds + store listings — `docs/STORE_CHECKLIST.md`
18. [ ] App Review + hotfix process

---

## Карта файлов по задачам (quick reference)

| Задача | Файлы |
|--------|-------|
| Mock off | `lib/core/api/api_config.dart`, `driver_app/lib/core/api/api_config.dart`, `lib/core/api/services/api_services.dart`, `driver_app/lib/core/api/app_services.dart` |
| Server quote | `backend/api/src/taxi.controller.ts`, `lib/features/booking/providers/booking_provider.dart` |
| Chat | `lib/features/active_trip/active_trip_screen.dart`, `driver_app/.../active_order_screen.dart`, NEW `chat.controller.ts` |
| Client vehicles | NEW `lib/features/profile/vehicles_screen.dart`, `clients.controller.ts` |
| Refresh token | `backend/api/src/_vps_live/auth.controller.ts`, `lib/core/api/api_client.dart` |
| FCM | `lib/core/services/push_service.dart`, `driver_app/lib/core/services/push_service.dart`, NEW `push.service.ts` |
| Payments | `lib/core/services/payment_service.dart`, NEW `payments.controller.ts` |
| Tests | `test/`, `driver_app/test/`, NEW `backend/api/test/` |
| Admin map | `admin/js/app.js`, `admin/css/styles.css` |
| DB | NEW `backend/api/src/database/`, `docker-compose.yml` (если есть — дополнить) |

---

## DONE summary (не трогать без необходимости)

- [x] Полный UI flow пассажира (20+ экранов)
- [x] Полный UI flow водителя (KYC → orders → active)
- [x] Redis backend на VPS с dispatch + antifraud
- [x] Socket.IO контракт 2048-совместимый
- [x] Админ-панель HTML с диспетчерской
- [x] MapKit + geo search (при ключах)
- [x] Support tickets client/driver/admin
- [x] Бренд «КОРОЛИ ДОРОГ» везде (не «0 промилле»)
- [x] Юридические тексты 152-ФЗ шаблон
- [x] Cash payment path

---

## Метрики готовности к релизу

| Критерий | Текущее | Target V1 |
|----------|---------|-----------|
| Mock-free release build | ❌ | ✅ |
| Server-authoritative price | ❌ | ✅ |
| E2E order cycle | ⚠️ manual | ✅ automated |
| Push delivery rate | 0% | >95% |
| Test coverage (critical path) | ~8% | >60% |
| Data durability | Redis only | Redis + SQL |
| Store submission | ❌ | ✅ |

---

*План привязан к фактическому состоянию репозитория на 16.07.2026. Обновлять по мере закрытия фаз.*
