# Чеклист ключей — КОРОЛИ ДОРОГ

Одна страница: **куда вставить** каждый ключ и примеры `--dart-define` / файлов.

> Не коммитьте секреты в git. Передавайте через CI secrets или локальный `keys.env` вне репозитория.

---

## Сводная таблица

| # | Ключ / артефакт | Куда вставить | Кто использует | Без ключа |
|---|-----------------|---------------|----------------|-----------|
| 1 | **MAPKIT_API_KEY** | `--dart-define` → `lib/core/config/map_config.dart` | Пассажир + водитель (карта) | Заглушка `MapHost` / Premium canvas |
| 2 | **YANDEX_GEOCODER_KEY** | `--dart-define` → `lib/core/geo/geo_config.dart` | Пассажир (геокод) | Mock Москва + сервер `/api/geo` |
| 2b | **YANDEX_GEOSUGGEST_KEY** | `--dart-define` → `lib/core/geo/geo_config.dart` | Пассажир (подсказки) | Fallback на geocoder key / mock |
| 2c | **YANDEX_ROUTING_KEY** | `--dart-define` → `lib/core/geo/geo_config.dart` | Пассажир (точный маршрут / полилиния) | **Не обязателен:** цена и км — haversine × 1.35 локально |
| 2d | **YANDEX_ROUTE_DETAILS_KEY** | опционально, иначе = `YANDEX_ROUTING_KEY` | Пассажир (линия + км + ETA) | См. 2c — без ключа работает fallback |
| 2e | **YANDEX_DISTANCE_MATRIX_KEY** | опционально, иначе = `YANDEX_ROUTING_KEY` | Пассажир (км / время A→B) | См. 2c — без ключа работает fallback |
| 3 | **SMS** (`SMSAERO_*` / `SMSC_*`) | VPS: `/opt/koroli-dorog-api/.env` | API OTP (оба приложения) | Только debug/demo OTP |
| 4 | **FCM** | `google-services.json`, `GoogleService-Info.plist`, backend Service Account JSON | Push (оба + API) | Локальные уведомления, stub-token |
| 5 | **PAYMENT_URL** | опц. legacy define; прод — backend `/api/payments/config` | Пассажир (карта / СБП) | Cash; card/SBP disabled в UI до эквайера |
| 6 | **API_BASE_URL** | `--dart-define` | Оба | Дефолт VPS `http://161.104.19.23` |
| 7 | **USE_MOCK_API** | `--dart-define` (пассажир) | Пассажир | По умолчанию **`false`** (реальный API) |
| 8 | **FIREBASE_ENABLED** | `--dart-define` (auto если json есть) | Оба | Локальные уведомления |
| 9 | **SENTRY_DSN** | `--dart-define` → `ObservabilityService` | Оба | Stub no-op без DSN / пакета |
| 10 | **CRASHLYTICS_ENABLED** | `--dart-define` (+ Firebase files) | Оба | Stub; нужен `firebase_crashlytics` |
| 11 | **ENABLE_AVATAR_UPLOAD** | `--dart-define` → `FeatureFlags` | Пассажир | `false` — скрыт пункт галереи |

Детали по каждому блоку ниже.

---

## 1. Yandex MapKit — `MAPKIT_API_KEY`

**Где получить:** [Кабинет разработчика Яндекс](https://developer.tech.yandex.ru/) → MapKit Mobile SDK.

**Куда вставить**

| Место | Как |
|-------|-----|
| Сборка / run | `--dart-define=MAPKIT_API_KEY=ваш_ключ` |
| Код | `lib/core/config/map_config.dart` → `String.fromEnvironment('MAPKIT_API_KEY')` |
| (позже) Android | при подключении SDK — ключ в init / gradle по [YANDEX_MAPS_SETUP.md](YANDEX_MAPS_SETUP.md) |
| (позже) iOS | то же в `AppDelegate` / init MapKit |

**Пример**

```bash
flutter run --dart-define=MAPKIT_API_KEY=xxxxxxxxxxxxxxxx
flutter build apk --dart-define=MAPKIT_API_KEY=xxxxxxxxxxxxxxxx
```

Полная инструкция: [YANDEX_MAPS_SETUP.md](YANDEX_MAPS_SETUP.md).

---

## 2. Yandex Geocoder + Geosuggest

**Важно:** MapKit, Geocoder и Geosuggest — **три разных ключа**. Routing (Route Details / Distance Matrix) — ещё один; часто **один** ключ на оба API → `YANDEX_ROUTING_KEY`.

| Define | API в кабинете |
|--------|----------------|
| `MAPKIT_API_KEY` | MapKit SDK |
| `YANDEX_GEOCODER_KEY` | API Геокодера |
| `YANDEX_GEOSUGGEST_KEY` | API Геосаджеста |
| `YANDEX_ROUTING_KEY` | Routing (общий; см. [API_REMAINING.md](API_REMAINING.md)) |
| `YANDEX_ROUTE_DETAILS_KEY` | Получение деталей маршрута (опционально) |
| `YANDEX_DISTANCE_MATRIX_KEY` | Матрица расстояний (опционально) |

**Куда вставить**

| Место | Как |
|-------|-----|
| Локально (удобно) | `keys.local.env` + `.\scripts\run_with_keys.ps1` |
| Сборка | `--dart-define=YANDEX_GEOCODER_KEY=… --dart-define=YANDEX_GEOSUGGEST_KEY=…` |
| Код | `lib/core/geo/geo_config.dart` |

**Пример**

```bash
flutter run ^
  --dart-define=MAPKIT_API_KEY=ключ_mapkit ^
  --dart-define=YANDEX_GEOCODER_KEY=ключ_geocoder ^
  --dart-define=YANDEX_GEOSUGGEST_KEY=ключ_suggest
```

Или:

```powershell
.\scripts\run_with_keys.ps1
```

Подробнее: [GEO_SEARCH_SETUP.md](GEO_SEARCH_SETUP.md).

---

## 3. SMS OTP (сервер)

Клиент **не** хранит SMS-ключи. Ключи только на API (VPS).

**Куда вставить:** `/opt/koroli-dorog-api/.env` на сервере, затем:

```bash
cd /opt/koroli-dorog-api && docker compose up -d --force-recreate api
```

| Переменная | Назначение |
|------------|------------|
| `SMS_PROVIDER` | `smsaero` или `smsc` |
| `SMSAERO_EMAIL` / `SMSAERO_API_KEY` | SMS Aero |
| `SMSC_LOGIN` / `SMSC_PASSWORD` | SMSC |
| `OTP_DEBUG_LOG` | `0` в проде |
| `DEMO_OTP_PHONE` / `DEMO_OTP_CODE` | убрать перед стором |

Пример `.env`:

```env
OTP_DEBUG_LOG=0
SMS_PROVIDER=smsaero
SMSAERO_EMAIL=your-email@example.com
SMSAERO_API_KEY=your_api_key
```

Инструкция: [SMS_SETUP.md](SMS_SETUP.md).

---

## 4. Firebase Cloud Messaging (FCM)

**Клиент:** `firebase_core` + `firebase_messaging` уже в pubspec.  
**Сервер:** `backend/api/src/push.service.ts` (firebase-admin, no-op без ключа).

**Куда положить файлы**

| Платформа | Файл | Пассажир | Водитель |
|-----------|------|----------|----------|
| Android | `google-services.json` | `android/app/google-services.json` | `driver_app/android/app/google-services.json` |
| iOS | `GoogleService-Info.plist` | `ios/Runner/GoogleService-Info.plist` | `driver_app/ios/Runner/GoogleService-Info.plist` |
| Backend VPS | Service Account JSON | `FIREBASE_SERVICE_ACCOUNT_PATH` или `FIREBASE_SERVICE_ACCOUNT_JSON` в `.env` | — |

**Dart-define (опционально):** `FIREBASE_ENABLED=true` — скрипты ставят автоматически при наличии `google-services.json`.

Токены POST:

- пассажир: `POST /api/client/push-token`
- водитель: `POST /api/driver/push-token`

Инструкция: [PUSH_SETUP.md](PUSH_SETUP.md).

---

## 5. Оплата — `PAYMENT_URL` (+ будущий эквайринг)

**Сейчас:** внешняя страница checkout через `url_launcher`.

| Место | Как |
|-------|-----|
| Сборка | `--dart-define=PAYMENT_URL=https://pay.example.com/checkout` |
| Код | `lib/core/services/payment_service.dart` |

**Позже (эквайер):** shopId / secretKey — **только backend**, не в Flutter. Webhook → `markPaid`. ЮKassa / CloudPayments / Тинькофф — см. [PAYMENTS_SETUP.md](PAYMENTS_SETUP.md).

```bash
flutter run --dart-define=PAYMENT_URL=https://pay.example.com/checkout
```

---

## 6. API — `API_BASE_URL` / `USE_MOCK_API`

| Define | Пассажир | Водитель |
|--------|----------|----------|
| `API_BASE_URL` | `lib/core/api/api_config.dart` | `driver_app/lib/core/api/api_config.dart` |
| `USE_MOCK_API` | `bool.fromEnvironment`, default **`false`** | runtime prefs + mock mode |

```bash
# Пассажир — прод API
flutter run ^
  --dart-define=USE_MOCK_API=false ^
  --dart-define=API_BASE_URL=http://161.104.19.23

# Водитель
cd driver_app
flutter run --dart-define=API_BASE_URL=http://161.104.19.23
```

---

## Полный пример production (пассажир)

```bash
flutter build appbundle --release ^
  --dart-define=USE_MOCK_API=false ^
  --dart-define=API_BASE_URL=https://api.koroli-dorog.ru ^
  --dart-define=MAPKIT_API_KEY=ВАШ_MAPKIT ^
  --dart-define=YANDEX_GEOCODER_KEY=ВАШ_GEOCODER ^
  --dart-define=PAYMENT_URL=https://pay.example.com/checkout
```

## Полный пример (водитель)

```bash
cd driver_app
flutter build appbundle --release ^
  --dart-define=API_BASE_URL=https://api.koroli-dorog.ru
```

(+ файлы FCM в `android/app/` и `ios/Runner/`)

---

## Локальный файл (опционально)

Создайте **вне git** `keys.local.env`:

Полный шаблон: **`keys.local.env.example`** (и root **`.env.example`**). Backend: **`backend/api/.env.example`**.

```env
MAPKIT_API_KEY=
YANDEX_GEOCODER_KEY=
YANDEX_GEOSUGGEST_KEY=
YANDEX_ROUTING_KEY=
YANDEX_ROUTE_DETAILS_KEY=
YANDEX_DISTANCE_MATRIX_KEY=
PAYMENT_URL=
API_BASE_URL=http://161.104.19.23
USE_MOCK_API=false
FIREBASE_ENABLED=false
SENTRY_DSN=
CRASHLYTICS_ENABLED=false
ENABLE_AVATAR_UPLOAD=false
```

Запуск через скрипт / CI, который разворачивает `keys.local.env` в `--dart-define=...`.

---

## Статус «готово к стору»

| Ключ | Вставлен? |
|------|-----------|
| MapKit | ☐ |
| Geocoder | ☐ |
| Geosuggest | ☐ |
| Routing (Route Details / Matrix) | ☐ |
| SMS (VPS) | ☐ |
| FCM files + SDK | ☐ |
| Payment / эквайринг (server) | ☐ |
| Sentry DSN / Crashlytics | ☐ |
| Production API URL | ☐ |
| Mock API выключен | ☐ |
