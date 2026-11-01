# Настройка геопоиска (подсказки адресов) для TaxiPro

Пошаговая инструкция по подключению Yandex Suggest / Geocoder в приложении пассажира «КОРОЛИ ДОРОГ».

Карта MapKit настраивается отдельно: [YANDEX_MAPS_SETUP.md](YANDEX_MAPS_SETUP.md).

## Содержание

1. [Как работает геопоиск сейчас](#1-как-работает-геопоиск-сейчас)
2. [Получение ключа Geocoder / Suggest](#2-получение-ключа-geocoder--suggest)
3. [Передача ключа через dart-define](#3-передача-ключа-через-dart-define)
4. [Серверные эндпоинты](#4-серверные-эндпоинты)
5. [UX в приложении](#5-ux-в-приложении)
6. [Код и файлы](#6-код-и-файлы)
7. [Частые проблемы](#7-частые-проблемы)

---

## 1. Как работает геопоиск сейчас

`GeoSearchService` пробует источники **по порядку**:

| Шаг | Источник | Условие |
|-----|----------|---------|
| 1 | Backend `GET/POST /api/geo/suggest` и `/api/geocode/suggest` | `USE_MOCK_API=false` и сервер отвечает 2xx |
| 2 | Yandex Suggest HTTP API (+ Geocoder при необходимости) | задан `--dart-define=YANDEX_GEOCODER_KEY=...` |
| 3 | Локальный mock адресов Москвы | всегда доступен как fallback |

Без ключа и без сервера подсказки всё равно работают: фильтр по `lib/core/geo/moscow_sample_addresses.dart`. Карта остаётся заглушкой (`YandexMapPlaceholder`).

> Ключ **MapKit** (`MAPKIT_API_KEY`) и ключ **Geocoder/Suggest** (`YANDEX_GEOCODER_KEY`) — разные продукты в кабинете Яндекса. Для подсказок нужен именно HTTP Geocoder / Suggest.

---

## 2. Получение ключа Geocoder / Suggest

1. Откройте [Кабинет разработчика Яндекс](https://developer.tech.yandex.ru/).
2. Подключите API **JavaScript API и HTTP Геокодер** (или отдельный продукт **Suggest API**, если доступен в кабинете).
3. Создайте ключ и дождитесь активации (~15 минут).
4. Ограничьте ключ по HTTP Referer / IP по возможности.

Документация:

- [HTTP Геокодер](https://yandex.ru/dev/geocode/doc/ru/)
- [Suggest API](https://yandex.ru/maps-api/docs/suggest-api/index.html)

---

## 3. Передача ключа через dart-define

### Запуск

```bash
flutter run --dart-define=YANDEX_GEOCODER_KEY=ваш_ключ_здесь
```

### Сборка APK

```bash
flutter build apk --dart-define=YANDEX_GEOCODER_KEY=ваш_ключ_здесь
```

### Вместе с MapKit и API

```bash
flutter run ^
  --dart-define=YANDEX_GEOCODER_KEY=ключ_геокодера ^
  --dart-define=YANDEX_GEOSUGGEST_KEY=ключ_геосаджеста ^
  --dart-define=MAPKIT_API_KEY=ключ_mapkit ^
  --dart-define=USE_MOCK_API=false ^
  --dart-define=API_BASE_URL=http://161.104.19.23
```

Или из корня проекта:

```powershell
.\scripts\run_with_keys.ps1
```

Ключи читаются в `lib/core/geo/geo_config.dart`:

```dart
static const String yandexGeocoderKey = String.fromEnvironment('YANDEX_GEOCODER_KEY');
static const String yandexGeosuggestKey = String.fromEnvironment('YANDEX_GEOSUGGEST_KEY');
```
**Не коммитьте ключ** в репозиторий. Для CI используйте secrets → `--dart-define`.

### Windows (PowerShell)

```powershell
flutter run --dart-define=YANDEX_GEOCODER_KEY=$env:YANDEX_GEOCODER_KEY
```

---

## 4. Серверные эндпоинты

Клиент вызывает (сначала GET, затем POST):

| Метод | Путь |
|-------|------|
| GET / POST | `/api/geo/suggest` |
| GET / POST | `/api/geocode/suggest` |

Параметры / тело:

```json
{ "q": "тверская", "query": "тверская", "text": "тверская" }
```

Ожидаемый JSON (любой из ключей списка):

```json
{
  "items": [
    {
      "title": "Тверская улица, 1",
      "subtitle": "Москва",
      "lat": 55.7575,
      "lng": 37.6138
    }
  ]
}
```

Также принимаются `suggestions`, `results`, `data`. Поля адреса: `title`/`value`, `subtitle`/`description`, `lat`/`latitude`, `lng`/`longitude`/`lon`.

Если эндпоинт ещё не реализован (404) — клиент тихо переходит к Yandex / mock. Ничего дополнительно включать не нужно.

---

## 5. UX в приложении

1. Пользователь открывает экран **«Куда едем?»** или **«Избранные адреса»**.
2. Фокус на поле → клавиатура `streetAddress`, `scrollPadding` чтобы поле не перекрывалось.
3. После **2+ символов** и debounce **300 мс** — панель подсказок.
4. Состояния по-русски:
   - загрузка: «Ищем адреса…»
   - пусто: «Ничего не найдено»
   - ошибка: «Не удалось загрузить подсказки» + «Повторить»
5. Тап по подсказке → адрес в поле, клавиатура закрывается, координаты доступны в `AddressSuggestionDto`.
6. Свайп списка / тап вне поля — клавиатура скрывается.

Компонент: `AddressSearchField` (`lib/shared/widgets/address_search_field.dart`).

---

## 6. Код и файлы

| Файл | Назначение |
|------|------------|
| `lib/core/geo/geo_config.dart` | `YANDEX_GEOCODER_KEY`, debounce, лимиты |
| `lib/core/geo/geo_search_service.dart` | Сервер → Yandex → mock |
| `lib/core/geo/moscow_sample_addresses.dart` | Локальные адреса Москвы |
| `lib/shared/widgets/address_search_field.dart` | UI подсказок |
| `lib/features/route/route_screen.dart` | Откуда / Куда / остановки |
| `lib/features/profile/favorites_screen.dart` | Дом / Работа / Избранное |

Приложение водителя адреса не вводит (только показывает) — слой подсказок там не подключён.

---

## 7. Частые проблемы

| Проблема | Решение |
|----------|---------|
| Подсказки только по Москве из списка | Нет ключа / сервер 404 — это ожидаемый mock |
| Yandex не отвечает | Проверьте ключ, квоту, активацию (~15 мин) |
| Сервер игнорируется | `USE_MOCK_API` по умолчанию `true` — передайте `false` |
| Клавиатура закрывает поле | Используется `scrollPadding` и dismiss on drag |
| Ключ попал в git | Отзовите ключ в кабинете, перевыпустите, используйте secrets |

### Полезные ссылки

- MapKit (карта): [YANDEX_MAPS_SETUP.md](YANDEX_MAPS_SETUP.md)
- [Suggest API](https://yandex.ru/maps-api/docs/suggest-api/index.html)
- [HTTP Геокодер](https://yandex.ru/dev/geocode/doc/ru/)
