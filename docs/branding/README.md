# App icon master placeholder

Файлы в этой папке — **brand placeholders** для стора (gold / purple / dark).

| Файл | Назначение |
|------|------------|
| `app_icon_1024.png` | Master пассажир |
| `app_icon_driver_1024.png` | Master водитель |
| `app_icon_fg.png` | Adaptive foreground |
| `app_icon_bg.png` | Adaptive background |

Цвета: Gold `#F5C518`, Purple `#7B5CFA`, Dark `#0B0B0E`.

См. также: [APP_ICON.md](../APP_ICON.md), [STORE_CHECKLIST.md](../STORE_CHECKLIST.md), [KEYS_CHECKLIST.md](../KEYS_CHECKLIST.md).

Замените master на финальный дизайн и выполните:

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```
