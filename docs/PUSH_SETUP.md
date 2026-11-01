# Push-уведомления (Firebase) — КОРОЛИ ДОРОГ

Приложения используют **FCM при наличии ключей**, иначе — локальные уведомления (`PushService` + `flutter_local_notifications`).

## Файлы, которые кладёт пользователь

| Платформа | Файл | Путь (пассажир) | Путь (водитель) |
|-----------|------|-----------------|-----------------|
| Android | `google-services.json` | `android/app/google-services.json` | `driver_app/android/app/google-services.json` |
| iOS | `GoogleService-Info.plist` | `ios/Runner/GoogleService-Info.plist` | `driver_app/ios/Runner/GoogleService-Info.plist` |
| Backend (VPS) | Service Account JSON | `/opt/koroli-dorog-api/firebase-sa.json` или env | — |

### Backend env (VPS `/opt/koroli-dorog-api/.env`)

Один из вариантов:

```env
FIREBASE_SERVICE_ACCOUNT_PATH=/opt/koroli-dorog-api/firebase-sa.json
```

или одной строкой:

```env
FIREBASE_SERVICE_ACCOUNT_JSON={"type":"service_account","project_id":"..."}
```

Пакет `firebase-admin` уже закреплён в Docker-образе API.

Перезапуск: `cd /opt/koroli-dorog-api && docker compose up -d --force-recreate api`

## Flutter

Зависимости уже в `pubspec.yaml`: `firebase_core`, `firebase_messaging`.

Gradle подключает `com.google.gms.google-services` **только если** `android/app/google-services.json` существует.

`PushService` пытается включить Firebase при `--dart-define=FIREBASE_ENABLED=true`; без корректного platform-файла безопасно переходит на локальные foreground-уведомления и не отправляет серверу фиктивный токен.

## Эндпоинты регистрации токена

| Приложение | POST |
|------------|------|
| Пассажир | `/api/client/push-token` |
| Водитель | `/api/driver/push-token` |

```json
{ "token": "<fcm_device_token>", "platform": "android" | "ios" }
```

## Сервер → устройство

| Событие | Кому | Backend |
|---------|------|---------|
| `order:new` | водитель | `PushService.notifyDriversNewOrder` + Socket.IO |
| `order:status` | пассажир | `PushService.notifyClientOrderStatus` + Socket.IO |

Data payload:

```json
{ "type": "order:status", "status": "enroute", "orderId": "..." }
```

## Без ключей

- FCM-токен не создаётся и не записывается в backend.
- Доступны только локальные foreground-уведомления.
- Socket.IO и обновления активного экрана продолжают работать.

## Firebase Console

1. Создайте проект Firebase.
2. Добавьте Android-приложения с package id:
   - пассажир: `com.korolidorog.koroli_dorog`
   - водитель: `com.korolidorog.driver`
3. Скачайте `google-services.json` в пути выше.
4. Cloud Messaging → Service Account → JSON для backend.

Опционально: `flutterfire configure` для генерации `firebase_options.dart` (не обязательно — используется default init).
