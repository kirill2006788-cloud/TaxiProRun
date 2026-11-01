# Что осталось по API / ключам — КОРОЛИ ДОРОГ

Краткий чеклист: что уже работает, что ждёт ключей, что ещё нужно подключить.

---

## ✅ DONE — уже подключено в коде и в `keys.local.env`

| Компонент | Define / место | Статус |
|-----------|----------------|--------|
| **MapKit key + UI** | `MAPKIT_API_KEY` + `USE_YANDEX_MAPKIT=true` → `MapConfig` / `yandex_maps_mapkit` | Пакет в pubspec, `initMapkit` в `main.dart`, живая `YandexMap` в passenger + driver (`YandexMapKitBridge`); soft-fallback на Premium canvas |
| **Geocoder** | `YANDEX_GEOCODER_KEY` → `GeoConfig` | Поиск / reverse geocode через HTTP |
| **Geosuggest** | `YANDEX_GEOSUGGEST_KEY` → `GeoConfig` | Подсказки адресов в полях «Откуда / Куда» |

Запуск с ключами (обязательно для карты):

```powershell
.\scripts\run_with_keys.ps1
# или явно passenger / driver:
.\scripts\run_with_keys.ps1 -App passenger
.\scripts\run_with_keys.ps1 -App driver
```

Пересборка после смены `USE_YANDEX_MAPKIT` / ключей — через тот же скрипт (dart-defines подхватываются только при compile/run).

---

## 🟡 CODE READY — код есть, ключ Routing **опционален**

| Компонент | Define | Куда вставить |
|-----------|--------|---------------|
| **Route Details** (линия маршрута + точные км + ETA) | `YANDEX_ROUTE_DETAILS_KEY` или общий `YANDEX_ROUTING_KEY` | `keys.local.env` |
| **Distance Matrix** (км / время A→B) | `YANDEX_DISTANCE_MATRIX_KEY` или общий `YANDEX_ROUTING_KEY` | `keys.local.env` |

**Без Routing-ключа приложение работает:** расстояние = haversine × 1.35 (`lib/core/geo/geo_math.dart`), цена = локальный калькулятор (`lib/core/pricing/fare_calculator.dart`) и тот же алгоритм на backend (`backend/api/src/pricing/taxi-pricing.ts`). Ключ нужен только для более точной полилинии и ETA.

**Важно:** в кабинете Яндекса [developer.tech.yandex.ru](https://developer.tech.yandex.ru/) API «Получение деталей маршрута» и «Матрица расстояний» часто выдают **один** ключ Routing. Его достаточно положить в:

```env
# опционально — для точного маршрута на карте
YANDEX_ROUTING_KEY=ваш_ключ_routing
```

Отдельные `YANDEX_ROUTE_DETAILS_KEY` / `YANDEX_DISTANCE_MATRIX_KEY` — только если ключи разные.

После вставки:

```powershell
.\scripts\run_with_keys.ps1
```

Код: `YandexRoutingService` → `BookingProvider` (цена, полилиния на карте, `routeDistanceMeters` в заказе). Без ключа — soft-fail на haversine × 1.35.

См. также: [KEYS_CHECKLIST.md](KEYS_CHECKLIST.md), [GEO_SEARCH_SETUP.md](GEO_SEARCH_SETUP.md).

---

## 🔜 SOON — с вашей стороны (сервер)

| Компонент | Куда | Документация |
|-----------|------|--------------|
| **SMS OTP** (SMS Aero или SMSC) | VPS: `/opt/koroli-dorog-api/.env` | [SMS_SETUP.md](SMS_SETUP.md) |

Клиент ключи SMS **не** хранит. После правок `.env` на VPS — пересоздать контейнер API.

---

## ❌ STILL NEEDED — ещё не готово к стору

| Компонент | Что сделать |
|-----------|-------------|
| **FCM / google-services** | `google-services.json` (+ iOS plist), Firebase SDK — [PUSH_SETUP.md](PUSH_SETUP.md) |
| **Payment gateway** | `PAYMENT_URL` / эквайринг на backend — [PAYMENTS_SETUP.md](PAYMENTS_SETUP.md) |

---

## Быстрый порядок действий

1. *(Опционально)* Вставить **Routing**-ключ в `YANDEX_ROUTING_KEY` → более точная полилиния и ETA на карте.
2. Настроить **SMS** на VPS по `SMS_SETUP.md`.
3. Подключить **FCM** и **оплату**.
4. Карта MapKit уже включена (`USE_YANDEX_MAPKIT=true`) — запускать через `run_with_keys.ps1`.
