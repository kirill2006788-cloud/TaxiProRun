# PRODUCT_AUDIT — «КОРОЛИ ДОРОГ»

**Дата:** 16 июля 2026  
**Объект:** `E:\project\Приложения\TaxiPro` (junction: `E:\project\TaxiProRun`)  
**Референс:** Yandex Go–level production V1 (адаптировано под такси + трезвый водитель)  
**Бренд:** «КОРОЛИ ДОРОГ» — gold `#F5C518` / purple `#7B5CFA` / dark `#0B0B0E`  
**Не переписывать с нуля:** кодовая база жизнеспособна, ~60% пути до V1 пройдено.

---

## 1. Резюме

Проект — зрелый **UI/UX-прототип с рабочим backend на Redis**, а не production V1. Пассажирское и водительское Flutter-приложения, веб-админка и NestJS API покрывают основной happy-path (OTP → заказ → диспетчеризация → статусы → оценка), но **по умолчанию включён mock API**, ценообразование на клиенте расходится с сервером, чат/оплата/FCM/авто клиента — заглушки, тестов почти нет.

**Общая готовность к production V1: ~42%**

| Область | Готовность | Комментарий |
|---------|------------|-------------|
| Пассажир — UI/бренд/навигация | **72%** | 20+ экранов, go_router, тема, онбординг |
| Пассажир — real API flow | **48%** | Mock по умолчанию; create/cancel/rate работают при `USE_MOCK_API=false` |
| Водитель — UI/бренд | **68%** | KYC wizard, заказы, активный заказ, профиль |
| Водитель — real API flow | **52%** | Socket accept/decline/status; mock по умолчанию |
| Backend API | **63%** | Redis + Socket.IO на VPS; локальный snapshot неполный |
| Админ-панель | **58%** | Диспетчерская, KYC, тарифы; карта — placeholder |
| Инфра / ключи / сторы | **28%** | FCM, SMS prod, payment gateway, release signing |
| Автотесты | **8%** | 1 widget test пассажир + 1 unit test водитель |
| Данные / персистентность | **35%** | Только Redis; нет Postgres/backup policy |

---

## 2. Что существует и работает

### 2.1 Пассажир (`lib/`)

| Компонент | Файлы | Статус |
|-----------|-------|--------|
| Запуск, бренд, тема | `lib/main.dart`, `lib/core/theme/app_theme.dart` | ✅ |
| Роутинг (splash → auth → onboarding → shell) | `lib/core/router/app_router.dart` | ✅ |
| OTP-авторизация | `lib/features/auth/auth_screen.dart`, `auth_provider.dart` | ✅ real + mock |
| Онбординг | `lib/features/onboarding/onboarding_screen.dart` | ✅ |
| Маршрут: адреса, остановки, дата, тип услуги | `lib/features/route/route_screen.dart`, `service_type_selector.dart` | ✅ |
| Тарифы (9 классов + трезвый) | `lib/features/tariffs/tariffs_screen.dart`, `lib/data/tariffs.dart` | ✅ UI; сервер — частично |
| Пожелания | `lib/features/preferences/preferences_screen.dart` | ✅ |
| Оплата (cash) | `lib/features/payment/payment_screen.dart` | ✅ cash |
| Подтверждение / отмена | `lib/features/confirmation/confirmation_screen.dart` | ✅ |
| Активная поездка + socket | `lib/features/active_trip/active_trip_screen.dart`, `active_trip_provider.dart`, `lib/core/api/socket_service.dart` | ✅ |
| История поездок | `lib/features/trips/trips_screen.dart` | ⚠️ mock fallback |
| Профиль, настройки, поддержка | `lib/features/profile/*` | ✅ |
| Геопоиск | `lib/core/geo/geo_search_service.dart` | ✅ server → Yandex → mock |
| Маршрутизация | `lib/core/geo/yandex_routing_service.dart` | ✅ с ключом; haversine fallback |
| Карта MapKit | `lib/features/map/yandex_mapkit_bridge.dart`, `map_host.dart` | ✅ + fallback canvas |
| Юридические тексты | `lib/data/legal_texts.dart` | ✅ 152-ФЗ шаблон |

### 2.2 Водитель (`driver_app/lib/`)

| Компонент | Файлы | Статус |
|-----------|-------|--------|
| OTP + регистрация KYC | `login_screen.dart`, `registration_wizard_screen.dart` | ✅ |
| Статус регистрации | `registration_status_screen.dart` | ✅ |
| Очередь заказов | `orders_screen.dart`, `OrdersProvider` | ✅ |
| Активный заказ + статусы | `active_order_screen.dart`, `trip_status_machine.dart` | ✅ |
| Socket accept/decline/update | `socket_service.dart`, `api_orders_repository.dart` | ✅ |
| Геолокация на линии | `driver_location_ticker.dart` | ✅ |
| История | `history_screen.dart` | ✅ |
| Профиль, документы | `profile_screen.dart` | ⚠️ фото — mock fallback |
| Поддержка | `support_screens.dart` | ✅ |
| Карта | `yandex_mapkit_bridge.dart`, `nav_map_placeholder.dart` | ✅ bridge; placeholder-обёртка |

### 2.3 Backend (`backend/api/src/`)

| Компонент | Файлы | Статус |
|-----------|-------|--------|
| Health | `health.controller.ts`, `_vps_live/health.controller.ts` | ✅ Redis ping |
| OTP + JWT 30d | `_vps_live/auth.controller.ts` | ✅ без refresh |
| Заказы CRUD + диспетчеризация | `orders.service.ts`, `orders.controller.ts` | ✅ server pricing при create |
| Водители geo/online/block | `drivers.service.ts` | ✅ |
| Клиенты profile/promo/bonus | `clients.controller.ts` | ✅ Redis |
| Тарифы такси | `taxi.controller.ts` | ✅ GET `/api/taxi/tariffs` |
| Тарифы трезвого (legacy) | `/api/tariffs` (в `_vps_live`) | ✅ на VPS |
| Socket.IO gateway | `_remote/events.gateway.ts` | ✅ на VPS |
| Админ | `admin.controller.ts` | ✅ KYC, assign, stats |
| Broadcasts | `broadcasts.controller.ts` | ✅ |
| Support tickets | `support.controller.ts` | ✅ Redis; не в root `app.module.ts` |
| Deploy scripts | `backend/deploy_*.py` | ✅ |

**Production snapshot:** `backend/api/src/_vps_live/` — полный `app.module.ts` с `SupportController`, `EventsGateway`, `OtpService`, `SmsService`. Корневой `app.module.ts` **неполный** (см. §6).

### 2.4 Админ (`admin/`)

| Раздел | Файл | Статус |
|--------|------|--------|
| Дашборд, диспетчерская | `admin/js/app.js` | ✅ |
| KYC проверка | `admin/js/app.js` | ✅ |
| Тарифы, промокоды, антифрод | `admin/js/app.js`, `admin/js/api.js` | ✅ |
| Карта водителей | `admin/js/app.js` L301–314 | ⚠️ placeholder grid без GPS |
| Деплой | `admin/deploy.ps1`, `admin/README.md` | ✅ |

---

## 3. Что сломано / неверно

### 3.1 Критичные расхождения mock ↔ production

| Проблема | Где | Детали |
|----------|-----|--------|
| **Mock API по умолчанию** | `lib/core/api/api_config.dart` L8–10 `defaultValue: true`; `driver_app/lib/core/api/api_config.dart` L20 `_useMock = true` | Release-сборка без `--dart-define=USE_MOCK_API=false` = демо, не продукт |
| **Цена на клиенте ≠ сервер** | `lib/features/booking/providers/booking_provider.dart` `_recalculatePrice()` L439–458 | Клиент считает `rate×km`; сервер — `orders.service.ts` `computePrice()` с МКАД/регион/наценки. Пассажир видит одну сумму, заказ создаётся с другой |
| **Нет `/api/taxi/quote`** | `lib/core/api/api_config.dart` L52 — endpoint объявлен, **не реализован** в `taxi.controller.ts` | Pre-order quote только локально |
| **Tariffs fallback на mock** | `lib/core/api/repositories/order_repository.dart` L172–196 | При ошибке API — тихий откат на `MockOrderRepository` |
| **История с mock-данными** | `lib/features/trips/trips_screen.dart` L219–315 | При пустом сервере показываются `MockTrips.all` |
| **Недавние адреса с mock** | `lib/features/route/route_screen.dart` L95–99 | Подмешивает `MockTrips` |

### 3.2 Заглушки «скоро» (grep)

| Текст / поведение | Файл |
|-------------------|------|
| `Чат с водителем скоро будет доступен` | `lib/features/active_trip/active_trip_screen.dart` L84 |
| `Чат с клиентом скоро` | `driver_app/lib/features/active_order/active_order_screen.dart` L263 |
| `Оплата картой/СБП скоро` | `lib/core/services/payment_service.dart` L48–49 |
| `'скоро'` на payment UI | `lib/features/payment/payment_screen.dart` L439 |
| `Загрузка фото — скоро` (аватар) | `lib/features/profile/profile_screen.dart` L310 |
| `Добавление карты — демо` | `lib/features/profile/payment_methods_screen.dart` L58 |
| Push stub `local-$platform-...` | `lib/core/services/push_service.dart` L26–31 |
| Driver push stub | `driver_app/lib/core/services/push_service.dart` L22–26 |
| `stub «высокий спрос»` | `lib/features/profile/providers/settings_provider.dart` L44; `broadcast_banner.dart`; `driver_app/.../demand_banner.dart` |
| Фото KYC mock | `driver_app/lib/shared/photo_picker.dart`, `mock_data.dart` |
| `simulateIncomingOrder только в mock` | `driver_app/lib/core/api/repositories/api_orders_repository.dart` L91 |

### 3.3 Backend / архитектура

| Проблема | Детали |
|----------|--------|
| **Неполный локальный backend** | Root `app.module.ts` импортирует `./redis.service`, `./auth.controller`, `./events.gateway`, `./otp.service`, `./sms.service`, `./tariffs.controller` — **файлов нет** в корне `src/`. Есть только `_vps_live/` и `_remote/` копии |
| **Support не в root module** | `support.controller.ts` есть, но не подключён в `backend/api/src/app.module.ts` (подключён в `_vps_live/app.module.ts`) |
| **Дублирование кода** | `orders.service.ts`, `admin.controller.ts`, `drivers.service.ts` ×3 (root, `_vps_live`, `_remote`) — риск рассинхрона |
| **JWT без refresh** | `_vps_live/auth.controller.ts` L112: `expiresIn: '30d'`, нет rotation/revocation |
| **CORS открыт** | `main.ts` L22–23: rejected origin всё равно `cb(null, true)` |
| **Rate limit in-memory** | `main.ts` L51–63: `globalThis.__apiRateLimitMap` — не переживает рестарт, не кластер |

### 3.4 Redis-only vs durable DB

Все сущности в Redis:

- Заказы: `order:{id}`
- Профили: `client:profile:*`, `driver:profile:*`
- Support: `support:tickets`
- Статистика: `stats:day:*` (частично durable buckets в admin)

**Риски:** потеря данных при flush/сбое Redis, нет миграций, нет SQL-отчётов, нет долгосрочного аудита. Admin `buildDurableStats` (`_vps_live/admin.controller.ts` L1224+) — workaround, не замена БД.

---

## 4. Отсутствующие фичи vs production V1 spec

### 4.1 Обязательные для Yandex Go–level V1

| Фича | Статус | Gap |
|------|--------|-----|
| **Автомобили клиента** (для трезвого/перегона) | ❌ | `ServiceType.soberDriver/personalDriver/vehicleTransfer` в `lib/models/service_type.dart` — UI есть, **нет модели, экрана, API** для сохранения марки/номера/цвета авто клиента |
| **Чат поездки** (in-app) | ❌ | Только snackbar-заглушка; нет WebSocket channel, нет экрана, нет Redis/DB storage |
| **Server-side pricing / quote** | ⚠️ | Цена считается на сервере **только при POST /orders**; pre-booking quote на клиенте; `/api/taxi/quote` — stub |
| **Refresh tokens** | ❌ | Один JWT 30d; нет `/auth/refresh`, нет blacklist |
| **FCM push (оба приложения)** | ❌ | Локальные уведомления; `docs/PUSH_SETUP.md` — не подключено |
| **Онлайн-оплата card/SBP** | ❌ | `docs/PAYMENTS_SETUP.md`; `PAYMENT_URL` не wired |
| **SMS OTP production** | ⚠️ | Код готов; `docs/SMS_SETUP.md` — зависит от VPS `.env` |
| **E2E / integration tests** | ❌ | Почти нет |
| **Crashlytics / мониторинг** | ❌ | Не настроено |
| **Публичный URL политики** | ⚠️ | Текст в приложении; URL для сторов — TBD (`docs/STORE_CHECKLIST.md`) |

### 4.2 Экраны: есть vs stub

| Экран | Путь | Статус |
|-------|------|--------|
| Splash | `/splash` | ✅ redirect only |
| Auth OTP | `/auth` | ✅ |
| Name | `/auth/name` | ✅ |
| Onboarding | `/` | ✅ |
| Route (home) | `/home` | ✅ |
| Tariffs | `/tariffs` | ✅ |
| Preferences | `/preferences` | ✅ |
| Payment | `/payment` | ⚠️ card/SBP stub |
| Confirmation | `/confirmation` | ✅ |
| Active trip | `/active-trip` | ⚠️ chat stub |
| Rate trip | `/rate-trip` | ✅ |
| Trips history | `/trips` | ⚠️ mock fallback |
| Profile subtree (12 экранов) | `/profile/*` | ⚠️ avatar upload stub |
| **Client vehicles** | — | ❌ отсутствует |
| **Trip chat** | — | ❌ отсутствует |
| Driver registration | `/registration` | ✅ |
| Driver active order | `/active-order` | ⚠️ chat stub, nav placeholder name |
| Driver earnings/payouts | — | ❌ только mock в `mock_data.dart` |

### 4.3 Режимы трезвого водителя (2048 parity)

| Режим | UI | Backend `serviceIndex` | Client vehicle |
|-------|-----|------------------------|----------------|
| Трезвый водитель (0) | ✅ | ✅ `orders.service.ts` | ❌ |
| Личный водитель (1) | ✅ submode chip | ✅ pricing branch | ❌ |
| Перегон а/м (2) | ✅ | ✅ | ❌ |

---

## 5. Потребности в рефакторинге (без переписывания)

1. **Единый источник backend** — консолидировать `_vps_live` → `src/`, удалить тройники `admin.controller.ts` / `orders.service.ts`.
2. **Mock guard для release** — `assert(!kReleaseMode || !useMockApi)` + CI check на `USE_MOCK_API=false`.
3. **Pricing pipeline** — `POST /api/taxi/quote` + клиентский `BookingProvider` читает только server quote.
4. **Repository layer** — убрать silent mock fallback в `RealOrderRepository` (fail loud + retry UI).
5. **Auth** — refresh token pair + secure storage rotation.
6. **Socket lifecycle** — пассажир: явный connect в `AuthProvider` после login (сейчас только в `ActiveTripProvider`).
7. **Driver photo upload** — заменить `pickImageBase64OrMock` + `mockUpload*` на реальный multipart к `drivers.controller.ts`.
8. **Admin map** — Yandex Maps JS API или Leaflet вместо CSS grid placeholder.
9. **Тесты** — golden path: OTP → create order → driver accept → complete → rate.

---

## 6. API / DB gaps

### 6.1 API endpoints: объявлено vs реализовано

| Endpoint | Клиент | Сервер |
|----------|--------|--------|
| `/api/auth/otp/*` | ✅ | ✅ `_vps_live` |
| `/api/auth/refresh` | ❌ | ❌ |
| `/api/taxi/tariffs` | ✅ | ✅ `taxi.controller.ts` |
| `/api/taxi/quote` | объявлен `api_config.dart` | ❌ |
| `/api/orders` | ✅ | ✅ |
| `/api/support/tickets` | ✅ | ✅ (VPS module) |
| `/api/client/vehicles` | ❌ | ❌ |
| `/api/orders/:id/chat` | ❌ | ❌ |
| `/api/geo/suggest` | ✅ клиент | ⚠️ зависит от VPS geo proxy |
| WebSocket events | ✅ оба apps | ✅ `_remote/events.gateway.ts` |

### 6.2 Отсутствующие файлы в root `backend/api/src/`

```
redis.service.ts      → только _vps_live/, _remote/
auth.controller.ts    → только _vps_live/, _remote/
events.gateway.ts     → только _remote/
otp.service.ts        → отсутствует в репозитории
sms.service.ts        → отсутствует в репозитории
tariffs.controller.ts → отсутствует в репозитории
support.controller.ts → есть, не в root app.module
```

Локальная сборка `nest build` из корня `src/` **сломана** без копирования из `_vps_live`.

### 6.3 Redis keys (основные)

| Key pattern | Назначение |
|-------------|------------|
| `order:*` | Заказы |
| `driver:profile:*` | Профили водителей |
| `client:profile:*` | Профили клиентов |
| `drivers:geo` | GEOINDEX |
| `support:tickets` | Тикеты |
| `taxi_tariffs:list` | Тарифы такси |
| `stats:day:*` | Дневная статистика |

**Нет:** `client:vehicles:*`, `order:chat:*`, `auth:refresh:*`.

---

## 7. Что блокирует production release

### P0 — без этого нельзя в стор

1. `USE_MOCK_API=false` по умолчанию + CI gate (`docs/STORE_CHECKLIST.md` L17)
2. Реальный SMS OTP на VPS, `OTP_DEBUG_LOG=0`
3. Согласование цены клиент ↔ сервер (quote API)
4. FCM + `google-services.json` / iOS plist
5. Release signing (keystore, Apple certs)
6. Публичный URL политики конфиденциальности
7. Убрать mock trips из production UI (`trips_screen.dart`)
8. E2E smoke: полный цикл заказа на staging

### P1 — блокирует полноценный V1

9. Чат поездки  
10. Автомобили клиента (sober modes)  
11. Refresh tokens  
12. Payment gateway (card/SBP)  
13. Postgres или Redis persistence (AOF + backup) для заказов/профилей  
14. Автотесты (минимум 20% coverage critical path)  
15. Backend monorepo cleanup (один deployable `src/`)

### P2 — качество / parity с Go

16. In-app навигация водителя (turn-by-turn)  
17. Surge pricing (сейчас stub banner)  
18. Crashlytics  
19. Admin live map  
20. i18n (сейчас только ru_RU — ок для РФ)

---

## 8. Инвентаризация mock/stub/TODO (grep scan)

### Пассажир `lib/`

| Паттерн | Кол-во файлов | Ключевые |
|---------|---------------|----------|
| `Mock*` classes | 5 repos | `order_repository.dart`, `user_repository.dart`, `settings_repository.dart`, `support_repository.dart` |
| `useMockApi` | 8+ | `api_config.dart`, `settings_provider.dart`, `route_screen.dart`, `trips_screen.dart` |
| `mock_trips` | 2 | `data/mock_trips.dart`, `trips_screen.dart` |
| `скоро` | 4 | active_trip, payment, profile |
| `placeholder` | 3 | map, onboarding PlaceholderAlignment |

### Водитель `driver_app/lib/`

| Паттерн | Кол-во файлов | Ключевые |
|---------|---------------|----------|
| `Mock*` | 4 | `mock_orders_repository.dart`, `mock_driver_profile_repository.dart`, `mock_settings_repository.dart`, `mock_data.dart` |
| `mockUpload*` | 1 | `profile_screen.dart` |
| `pickImageBase64OrMock` | 2 | `photo_picker.dart`, `registration_wizard_screen.dart` |
| `NavMapPlaceholder` | 1 | делегирует в MapHost — имя вводит в заблуждение |
| `restoreMockOrders` | 1 | `orders_screen.dart` L200 |

### Backend

| Паттерн | Файлы |
|---------|-------|
| `fromDurable` stats fallback | `admin.controller.ts` |
| Deploy patches | `deploy_*.py` — ручной деплой, не CI |

### Admin

| Паттерн | Файлы |
|---------|-------|
| `map-placeholder` | `app.js` L301–314, `styles.css` L461 |
| HTML `placeholder=` attrs | `index.html`, form fields — OK (UI hints) |

---

## 9. Тесты

| Файл | Что проверяет |
|------|---------------|
| `test/widget_test.dart` | Splash → auth screen |
| `driver_app/test/widget_test.dart` | `AppServices` mock default |

**Нет:** API integration, socket, booking flow, driver accept, pricing, admin.

---

## 10. Документация в репозитории

| Документ | Актуальность |
|----------|--------------|
| `README.md` | ✅ mock default задокументирован |
| `docs/STORE_CHECKLIST.md` | ✅ хороший release guide |
| `docs/API_REMAINING.md` | ✅ keys/SMS/FCM/payment gaps |
| `docs/KEYS_CHECKLIST.md` | ✅ |
| `admin/README.md` | ✅ |
| `driver_app/README.md` | ✅ |

---

## 11. TOP-10 блокеров production

| # | Блокер | Impact | Файлы / действие |
|---|--------|--------|------------------|
| 1 | **Mock API включён по умолчанию** | Стор получит демо-приложение | `lib/core/api/api_config.dart`, `driver_app/lib/core/api/api_config.dart` |
| 2 | **Расхождение цены клиент/сервер** | Споры, отмены, недоверие | `booking_provider.dart` vs `orders.service.ts`; нужен `/api/taxi/quote` |
| 3 | **Нет чата поездки** | Базовый UX такси | `active_trip_screen.dart`, `active_order_screen.dart` — snackbar only |
| 4 | **Нет автомобилей клиента** | Трезвый/перегон неполноценны | Нет `client/vehicles` API и экрана |
| 5 | **Нет refresh tokens** | Security + session management | `auth.controller.ts` — только JWT 30d |
| 6 | **Redis-only без durable DB** | Потеря заказов/профилей | Весь backend; нужен Postgres + sync |
| 7 | **FCM не подключён** | Нет push о заказах | `push_service.dart` (оба apps), `docs/PUSH_SETUP.md` |
| 8 | **Оплата card/SBP — stub** | Нельзя обещать онлайн-оплату | `payment_service.dart`, backend payment webhook |
| 9 | **Минимум автотестов** | Регрессии при каждом релизе | `test/` — 2 файла |
| 10 | **Неполный/дублированный backend в repo** | Локальная разработка и CI сломаны | `app.module.ts` vs `_vps_live/`; missing `otp.service.ts` |

---

## 12. Рекомендуемый порядок (не rewrite)

1. Фаза 0: mock off + backend consolidate + staging E2E  
2. Фаза 1: server quote + убрать mock fallbacks в UI  
3. Фаза 2: FCM + SMS prod + client vehicles  
4. Фаза 3: trip chat + refresh tokens  
5. Фаза 4: payments + Postgres + tests + store submit  

Детальный план: **`IMPLEMENTATION_PLAN.md`**.

---

*Аудит выполнен сканированием кодовой базы `E:\project\Приложения\TaxiPro` без внесения изменений в код.*
