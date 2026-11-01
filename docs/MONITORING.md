# Monitoring & observability — КОРОЛИ ДОРОГ

Связано с ТЗ §2.1 (инфраструктура), §8 (Crashlytics/Sentry), §9 (backup, monitoring, alerts, rollback).

> Секреты (DSN, service account) **не** коммитятся. Только имена переменных и шаги.

---

## 1. Клиенты (Flutter)

| Канал | Define / условие | Статус в репо |
|-------|------------------|---------------|
| **Sentry** | `--dart-define=SENTRY_DSN=…` (+ опц. `SENTRY_ENVIRONMENT`, `SENTRY_RELEASE`) | Stub: `ObservabilityService` в пассажире и водителе — no-op без DSN; пакет `sentry_flutter` подключается ops-ом |
| **Crashlytics** | `FIREBASE_ENABLED=true` + `google-services.json` / `GoogleService-Info.plist` + `--dart-define=CRASHLYTICS_ENABLED=true` | Stub: тот же сервис; пакет `firebase_crashlytics` — после Firebase Console |
| Локальные логи | `debugPrint` / structured events | Всегда в debug; в release — только через Sentry/Crashlytics при включении |

Инициализация: `await ObservabilityService.instance.init()` в `main()` (до `runApp`).

### Включение Sentry (ops)

```bash
# pubspec (оба приложения), затем:
flutter pub add sentry_flutter
# Раскомментировать реализацию в ObservabilityService / заменить stub import.
```

```powershell
.\scripts\build_release.ps1  # SENTRY_DSN из keys.local.env → dart-define
```

### Включение Crashlytics (ops)

1. Firebase Console → Crashlytics для обоих Android/iOS apps.
2. `flutter pub add firebase_crashlytics` (+ Gradle plugin по доке Firebase).
3. `CRASHLYTICS_ENABLED=true` в `keys.local.env`.
4. Smoke: искусственный non-fatal → видно в Console за ~5 мин.

---

## 2. Backend (NestJS)

| Канал | Env | Где |
|-------|-----|-----|
| Structured JSON logs | `LOG_FORMAT=json`, `LOG_LEVEL=…` | `backend/api/src/logging/structured-logger.ts` |
| Sentry (optional) | `SENTRY_DSN`, `SENTRY_ENVIRONMENT`, `SENTRY_TRACES_SAMPLE_RATE` | `initSentryIfConfigured()` — soft-fail без `@sentry/node` |
| Health | HTTP `/api/health` (или аналог на VPS) | Проверять из uptime-монитора |

### Ops: алерты (вне репо)

- [ ] Uptime: ping API + admin static каждые 1–5 мин (UptimeRobot / Hetrix / Grafana).
- [ ] Disk / Redis / Docker restart alerts на VPS.
- [ ] Sentry alert rules: new issue, spike, payment webhook failures.
- [ ] SMS provider balance / delivery failure webhook.

---

## 3. Админка

- Ошибки API → Network tab + backend JSON logs.
- Карта диспетчерской без GPS точек показывает grid-placeholder (не crash) — см. [SMOKE_E2E.md](SMOKE_E2E.md).

---

## 4. Backup & rollback (human checklist)

- [ ] Redis RDB/AOF или периодический dump ключевых ключей (`orders:*`, `settings:*`).
- [ ] Postgres (когда появится) — daily dump + restore drill.
- [ ] Docker image tag / compose pin для rollback API.
- [ ] Хранить AAB/APK + mapping.txt в `release/<version>/` (уже есть; **не удалять** старые артефакты без явного запроса).

---

## 5. Acceptance (ТЗ §9, monitoring slice)

- [ ] Краш в debug/release с DSN → событие в Sentry **или** Crashlytics.
- [ ] Backend error → JSON log line + (опц.) Sentry.
- [ ] Uptime alert срабатывает при остановке API.
- [ ] Известен rollback: предыдущий Docker tag + предыдущий AAB в `release/`.
