# Иконка приложения КОРОЛИ ДОРОГ

## Статус

Сгенерированы **brand placeholder**-иконки (gold `#F5C518` / purple `#7B5CFA` на `#0B0B0E`):

- `docs/branding/app_icon_1024.png` — master (пассажир)
- `docs/branding/app_icon_driver_1024.png` — master (водитель, метка V)
- `docs/branding/app_icon_fg.png` / `app_icon_bg.png` — adaptive
- Android mipmap `ic_launcher` / `ic_launcher_round` / `ic_launcher_foreground` + adaptive XML
- Splash: `assets/branding/splash_logo.png`

Перед стором желательно заменить master на финальный дизайн от дизайнера и перегенерировать.

## Конфиг

В `pubspec.yaml` обоих приложений:

```yaml
# dart run flutter_launcher_icons
# dart run flutter_native_splash:create
flutter_launcher_icons: ...
flutter_native_splash: ...
```

Flutter SDK на машине агента не был в PATH — иконки/mipmap собраны вручную; при наличии Flutter выполните команды выше.

## Android label

- Пассажир: `КОРОЛИ ДОРОГ`
- Водитель: `КОРОЛИ ДОРОГ Водитель`
