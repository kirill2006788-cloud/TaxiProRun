# Release readiness — КОРОЛИ ДОРОГ

Версия приложений: **1.1.4+6** · пассажир + водитель (`driver_app/`)  
Обновлено: 22 июля 2026 г.  
Ориентир: [FULL_TZ_YANDEX_GO_PARITY.md](../FULL_TZ_YANDEX_GO_PARITY.md) **§2**, **§8**, **§9**.

Стор-чеклист: [STORE_CHECKLIST.md](STORE_CHECKLIST.md) · Мониторинг: [MONITORING.md](MONITORING.md) · Smoke: [SMOKE_E2E.md](SMOKE_E2E.md) · Ключи: [KEYS_CHECKLIST.md](KEYS_CHECKLIST.md)

---

## Соответствие ТЗ

### §2 — главные production-блокеры

| Блокер | In-repo | Human / ops |
|--------|---------|-------------|
| Postgres + backup / Redis rate-limit | KV Redis path есть; Postgres — TODO на VPS | Staging vs prod, dumps |
| CI analyze/test/build notes | `.github/workflows/ci.yml` | Deploy secrets, signing |
| Sentry / Crashlytics | Stub + [MONITORING.md](MONITORING.md) | DSN, Firebase Console |
| SMS / FCM / Payment production | Docs + env examples | Провайдеры, webhook, SA JSON |
| `USE_MOCK_API=false` | Default `false` + env examples | Smoke на staging |
| Убрать видимые «скоро» | Частично (см. ниже) | Оставшиеся product gaps |
| Placeholder-карты | MapHost / premium canvas при ключе; admin grid без GPS | MapKit + admin JS map |

### §8 — остатки в репозитории (чеклист)

- [ ] FCM production: `google-services.json` / plist + backend SA
- [ ] Платежи: провайдер + webhook + refunds
- [ ] SMS: выключить debug OTP на VPS
- [ ] Admin live map (не только placeholder без GPS)
- [ ] Driver nav: MapKit + маршрут (не только premium canvas)
- [ ] Smoke A→D: [SMOKE_E2E.md](SMOKE_E2E.md)
- [ ] E2E / golden tests
- [ ] Store assets + signing
- [ ] Crashlytics/Sentry DSN wired
- [ ] Чистка `*.patched` / `_remote` / `_vps_live` если не в сборке

### §9 — acceptance «full release»

| Критерий | Как проверить |
|----------|----------------|
| Пассажир end-to-end без mock | Smoke A+C |
| Водитель end-to-end без mock | Smoke B |
| Админ видит путь | Smoke D |
| OTP SMS real | VPS env, без debug |
| Push Android/iOS | [PUSH_SETUP.md](PUSH_SETUP.md) |
| Оплата + webhook | [PAYMENTS_SETUP.md](PAYMENTS_SETUP.md) |
| Живые карты в primary | MapKit keys + admin markers |
| Нет mock / debug OTP в prod | dart-define + server env |
| Legal + store packaging | [STORE_CHECKLIST.md](STORE_CHECKLIST.md) |
| Backup / monitoring / rollback | [MONITORING.md](MONITORING.md) |

---

## Общий прогресс (оценка)

| Область | Сейчас | Цель |
|--------|--------|------|
| Тесты | ~58% | ≥70% |
| Store packaging / signing | ~60% | 100% после release + keystore |
| Monitoring stubs | ~40% → stubs in-repo | 100% после DSN/ops |
| Производительность | ~45% | profile на слабом Android |

---

## Тесты

### Сделано

- [x] Unit/widget пассажир + driver smoke
- [x] CI: analyze + test (пассажир, водитель); stubs backend/admin
- [x] Skeleton `integration_test/` (skip до эмулятора)

### TODO

- [ ] E2E на эмуляторе
- [ ] Golden screenshots
- [ ] Driver unit: orders / KYC / online
- [ ] Coverage ≥ 50%

```bash
flutter pub get && flutter analyze --no-fatal-infos && flutter test
cd driver_app && flutter pub get && flutter analyze --no-fatal-infos && flutter test
cd backend/api && npm ci && npm run typecheck
```

---

## Store packaging

### Сделано

- [x] Версия `1.1.4+6` в обоих `pubspec.yaml`
- [x] Icons / splash / branding docs
- [x] Legal texts + ссылки на auth/onboarding (пассажир + водитель)
- [x] Артефакты в `release/<version>/` (APK/AAB) — **не удалять** без запроса
- [x] `scripts/build_release.ps1` + [RELEASE_ONE_COMMAND.md](RELEASE_ONE_COMMAND.md)

### TODO (блокеры стора)

| Пункт | Статус |
|-------|--------|
| Android keystore / `key.properties` | TODO (не коммитить) |
| iOS certs / profiles | TODO |
| ProGuard/R8 проверка | после release |
| Crashlytics / Sentry live | stub → ops |
| Screenshots без map placeholder | TODO |
| Data safety / Privacy labels | TODO |
| Production smoke | [SMOKE_E2E.md](SMOKE_E2E.md) |

### Release commands

```powershell
# Рекомендуется: ASCII-путь при кириллице в path — см. scripts/build_release.ps1
.\scripts\build_release.ps1
.\scripts\build_release.ps1 -Apk
```

Или вручную — полный набор defines из `keys.local.env.example`.

---

## CI

Workflow **CI** (`.github/workflows/ci.yml`):

| Job | Что |
|-----|-----|
| passenger | `flutter analyze` + `flutter test` |
| driver | то же в `driver_app/` |
| backend | `npm ci` + `npm run typecheck` |
| admin | static presence check (index.html / js) |

Секреты не требуются для analyze/test. Build AAB/IPA — локально или отдельный protected workflow с secrets.

---

## Видимые заглушки (инвентарь)

| Место | Текст / UI | Статус |
|-------|------------|--------|
| Driver preorder без `scheduledAt` | было «скоро» | → «время уточняется» |
| Profile gallery avatar | upload | скрыто за `ENABLE_AVATAR_UPLOAD` |
| Card/SBP | «ещё не подключена» / unavailable | OK до эквайера; не «скоро» |
| Admin map без GPS | `map-placeholder` grid | допустимо; live markers при lat/lng |
| Driver/passenger map без MapKit | premium canvas | нужен ключ для стора |

---

## Перед отправкой в стор

1. `flutter test` + CI зелёный.
2. `USE_MOCK_API=false`, production `API_BASE_URL`, keys из [KEYS_CHECKLIST.md](KEYS_CHECKLIST.md).
3. Release-сборки + signing.
4. Smoke [SMOKE_E2E.md](SMOKE_E2E.md).
5. [STORE_CHECKLIST.md](STORE_CHECKLIST.md) + [MONITORING.md](MONITORING.md).
6. Закрыть OTP debug на VPS.
