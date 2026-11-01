# Release build — одна команда

Скрипт читает `keys.local.env` и собирает release APK/AAB для пассажира и водителя.

## Перед сборкой

1. Скопируйте `keys.local.env.example` → `keys.local.env` и заполните ключи (`USE_MOCK_API=false` для prod).
2. (Android release) Скопируйте `android/key.properties.example` → `android/key.properties`, положите keystore.
3. (Push) Положите Firebase-файлы — см. [PUSH_SETUP.md](PUSH_SETUP.md).
4. **Кириллица в пути:** если workspace вроде `E:\project\Приложения\TaxiPro` ломает Gradle/NDK:

```powershell
subst R: "E:\project\Приложения\TaxiPro"
R:
.\scripts\build_release.ps1
# после сборки:
subst R: /d
```

Скрипт сам предупреждает, если путь non-ASCII. Артефакты в `release\<version>\` **не удалять**.

## Команды

```powershell
# Оба приложения — appbundle (Google Play)
.\scripts\build_release.ps1

# Только пассажир
.\scripts\build_release.ps1 -PassengerOnly

# Только водитель
.\scripts\build_release.ps1 -DriverOnly

# APK вместо appbundle
.\scripts\build_release.ps1 -Apk
```

## Что делает скрипт

- Все непустые ключи из `keys.local.env` → `--dart-define=KEY=VALUE`
- Если есть `android/app/google-services.json` (или driver) → `FIREBASE_ENABLED=true`
- `flutter pub get` в каждом приложении
- `flutter build appbundle --release` (или `apk`)

## Артефакты

| Приложение | AAB | APK |
|------------|-----|-----|
| Пассажир | `build/app/outputs/bundle/release/app-release.aab` | `build/app/outputs/flutter-apk/app-release.apk` |
| Водитель | `driver_app/build/app/outputs/bundle/release/app-release.aab` | `driver_app/build/app/outputs/flutter-apk/app-release.apk` |

## Без keystore

Release-сборка подпишется debug-ключом (для локальной проверки). Для стора нужны `key.properties` + `.jks`.

Полный чеклист: [KEYS_CHECKLIST.md](KEYS_CHECKLIST.md).
