# Настройка Yandex MapKit для TaxiPro

Пошаговая инструкция по подключению карт и маршрутизации в Flutter-приложении «КОРОЛИ ДОРОГ».

## Содержание

1. [Получение API-ключа](#1-получение-api-ключа)
2. [Установка пакета](#2-установка-пакета)
3. [Конфигурация Android](#3-конфигурация-android)
4. [Конфигурация iOS](#4-конфигурация-ios)
5. [Передача API-ключа](#5-передача-api-ключа)
6. [Инициализация в main.dart](#6-инициализация-в-maindart)
7. [Пример: карта с маршрутом](#7-пример-карта-с-маршрутом)
8. [Замена заглушки на реальную карту](#8-замена-заглушки-на-реальную-карту)
9. [Лицензирование и тарифы](#9-лицензирование-и-тарифы)
10. [Частые проблемы](#10-частые-проблемы)

---

## 1. Получение API-ключа

1. Перейдите в [Кабинет разработчика Яндекс](https://developer.tech.yandex.ru/).
2. Войдите в аккаунт Яндекс или создайте новый.
3. Нажмите **«Подключить API»** → выберите **MapKit Mobile SDK**.
4. Заполните информацию о проекте, выберите тарифный план → **«Продолжить»**.
5. Ключ появится в разделе **API-интерфейсы → MapKit Mobile SDK**.

> **Важно:** активация ключа занимает ~15 минут.

### Тарифы (кратко)

| Лицензия | MAU (пользователей/мес.) | Стоимость |
|----------|--------------------------|-----------|
| Free | до 25 000 | Бесплатно |
| Basic | до 125 000 | от $4 800/год |
| Advanced | Индивидуально | По запросу |

Для такси-приложения с маршрутизацией нужна **full-версия** SDK и лицензия с поддержкой Routing.

---

## 2. Установка пакета

### Выбор пакета

| Пакет | Назначение |
|-------|-----------|
| `yandex_maps_mapkit` | **Full** — карта + маршрутизация + поиск + геокодинг. **Для TaxiPro.** |
| `yandex_maps_mapkit_lite` | **Lite** — только карта, геолокация, пробки. Без маршрутов. |

### pubspec.yaml

Раскомментируйте в `pubspec.yaml`:

```yaml
dependencies:
  yandex_maps_mapkit:
    version: ^4.41.0
```

Выполните:

```bash
flutter pub get
```

### Android: дополнительная зависимость

В `android/app/build.gradle`:

```gradle
dependencies {
    implementation "com.google.android.gms:play-services-location:21.1.0"
}
```

---

## 3. Конфигурация Android

### 3.1. Разрешения в AndroidManifest.xml

Файл: `android/app/src/main/AndroidManifest.xml`

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>

    <application
        android:label="КОРОЛИ ДОРОГ"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <!-- ... -->
    </application>
</manifest>
```

> Официальный пакет `yandex_maps_mapkit` инициализирует API-ключ через Dart (`initMapkit`), **не требуя** кастомного `Application`-класса.

### 3.2. minSdkVersion

Убедитесь, что `minSdkVersion` ≥ 21 в `android/app/build.gradle`.

---

## 4. Конфигурация iOS

### 4.1. Минимальная версия iOS

В `ios/Podfile`:

```ruby
platform :ios, '13.0'
```

### 4.2. Info.plist — разрешения геолокации

Файл: `ios/Runner/Info.plist`

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>КОРОЛИ ДОРОГ использует геолокацию для отображения вашего местоположения на карте и построения маршрутов.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>КОРОЛИ ДОРОГ использует геолокацию для отслеживания поездки.</string>
```

> API-ключ для официального пакета задаётся в Dart, **не в Info.plist**.

---

## 5. Передача API-ключа

### Способ 1: --dart-define (рекомендуется)

```bash
flutter run --dart-define MAPKIT_API_KEY=ваш_ключ_здесь
```

```bash
flutter build apk --dart-define MAPKIT_API_KEY=ваш_ключ_здесь
```

Ключ читается в `lib/core/config/map_config.dart`.

### Способ 2: .env файл (не коммитить!)

1. Создайте `.env` в корне проекта:
   ```
   MAPKIT_API_KEY=ваш_ключ
   ```
2. Добавьте `.env` в `.gitignore`.
3. Используйте пакет `envied` или `flutter_dotenv` для загрузки.

---

## 6. Инициализация в main.dart

```dart
import 'package:flutter/material.dart';
import 'package:yandex_maps_mapkit/init.dart' as mapkit_init;
import 'package:yandex_maps_mapkit/mapkit.dart' as mapkit;

import 'core/config/map_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Passenger / driver: см. lib/main.dart — init только при MapConfig.isMapKitReady
  if (MapConfig.isMapKitReady) {
    await mapkit_init.initMapkit(apiKey: MapConfig.apiKey);
  }

  runApp(const TaxiProApp());
}
```

### Жизненный цикл MapKit

MapKit требует вызовов `onStart()` / `onStop()` при появлении/скрытии карты:

```dart
@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) {
    mapkit.mapkit.onStart();
  } else if (state == AppLifecycleState.paused) {
    mapkit.mapkit.onStop();
  }
}
```

---

## 7. Пример: карта с маршрутом

### 7.1. Базовая карта

```dart
import 'package:flutter/material.dart';
import 'package:yandex_maps_mapkit/mapkit.dart';

class TaxiMapScreen extends StatefulWidget {
  const TaxiMapScreen({super.key});

  @override
  State<TaxiMapScreen> createState() => _TaxiMapScreenState();
}

class _TaxiMapScreenState extends State<TaxiMapScreen> {
  MapWindow? _mapWindow;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: YandexMap(
        onMapCreated: (mapWindow) {
          _mapWindow = mapWindow;
          _mapWindow!.map.move(
            const CameraPosition(
              Point(latitude: 55.751244, longitude: 37.618423),
              zoom: 14.0,
              azimuth: 0.0,
              tilt: 0.0,
            ),
          );
        },
      ),
    );
  }
}
```

### 7.2. Построение маршрута (DrivingRouter)

> Маршрутизация доступна **только в full-версии** (`yandex_maps_mapkit`).

См. [официальный туториал по маршрутизации](https://yandex.com/maps-api/docs/mapkit/flutter/generated/tutorials/map_routing.html).

---

## 8. Замена заглушки на реальную карту

Точка входа UI — **`MapHost`** (`lib/features/map/map_host.dart`).

Без ключа: премиум-canvas (маршрут, A/B, машинка).
С ключом (без флага): тот же canvas + бейдж «MapKit · ключ готов».
С ключом + флагом: `YandexMapKitBridge` → вставьте `YandexMap`.

1. Получите API-ключ (раздел 1).
2. Раскомментируйте зависимость в `pubspec.yaml` (раздел 2).
3. Настройте Android/iOS (разделы 3–4).
4. Раскомментируйте `initMapkit` в `main.dart` (раздел 6).
5. Запуск:

```bash
flutter run --dart-define=MAPKIT_API_KEY=ваш_ключ --dart-define=USE_YANDEX_MAPKIT=true
```

6. В `lib/features/map/yandex_mapkit_bridge.dart` замените fallback на `YandexMap`:

```dart
// Было (fallback внутри MapHost → PremiumMapCanvas):
MapHost(routePoints: kDefaultMockRoute, showDriverMarker: true)

// Стало внутри YandexMapKitBridge.build:
import 'package:yandex_maps_mapkit/mapkit.dart';
YandexMap(onMapCreated: (mapWindow) {
  // polyline + placemarks + driver marker
})
```

Экраны `RouteScreen` / `ActiveTripScreen` (пассажир) и `ActiveOrderScreen` (водитель) уже ходят через `MapHost` — менять экраны не нужно.

---

## 9. Лицензирование и тарифы

- **Free:** до 25 000 MAU, стилизованные карты.
- **Basic:** до 125 000 MAU, маршрутизация, поиск.
- **Advanced:** индивидуальный расчёт.

Подробнее: [yandex.com/maps-api/products/mapkit](https://yandex.com/maps-api/products/mapkit)

---

## 10. Частые проблемы

| Проблема | Решение |
|----------|---------|
| Карта не отображается | Проверьте API-ключ, подождите 15 мин после создания |
| `initMapkit` не вызван | Добавьте вызов в `main()` до `runApp()` |
| Карта чёрная/пустая | Вызовите `mapkit.onStart()` при `AppLifecycleState.resumed` |
| Маршрут не строится | Используйте **full** (`yandex_maps_mapkit`), не lite |
| Ошибка на iOS | Проверьте `platform :ios, '13.0'` в Podfile, выполните `pod install` |
| Геолокация не работает | Добавьте `NSLocationWhenInUseUsageDescription` в Info.plist |
| Ключ в git | Используйте `--dart-define` или `.env` в `.gitignore` |

### Полезные ссылки

- [Документация MapKit Flutter](https://yandex.com/maps-api/docs/mapkit/flutter/)
- [Демо-приложения (GitHub)](https://github.com/yandex/mapkit-flutter-demo)
- [Маршрутизация](https://yandex.com/maps-api/docs/mapkit/flutter/generated/tutorials/map_routing.html)
- [Объекты на карте (полилинии)](https://yandex.com/maps-api/docs/mapkit/flutter/generated/tutorials/map_objects.html)
