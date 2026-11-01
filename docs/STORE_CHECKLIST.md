# Чеклист публикации в сторы — КОРОЛИ ДОРОГ

Версия приложений: **1.1.4+6**  
Бренд: пассажир **КОРОЛИ ДОРОГ**, водитель **КОРОЛИ ДОРОГ Водитель**  
Дата чеклиста: 22 июля 2026 г.  
ТЗ: §2 / §8 / §9 — см. [RELEASE_READINESS.md](RELEASE_READINESS.md), [MONITORING.md](MONITORING.md), [SMOKE_E2E.md](SMOKE_E2E.md).

Подробные ключи: [KEYS_CHECKLIST.md](KEYS_CHECKLIST.md) · шаблон: `keys.local.env.example` / `.env.example`.

---

## Перед сборкой (оба приложения)

- [ ] Версия в `pubspec.yaml` = `1.0.0+1` (или выше) и совпадает с экраном «О приложении»
- [ ] Юридические тексты (политика / оферта) актуальны, дата и версия **1.0.1**
- [ ] Ссылки на политику и условия открываются с онбординга / экрана входа
- [ ] Подставлены все ключи из [KEYS_CHECKLIST.md](KEYS_CHECKLIST.md)
- [ ] `USE_MOCK_API=false` и рабочий `API_BASE_URL` для production-сборки
- [ ] SMS на сервере: реальный провайдер, `OTP_DEBUG_LOG=0`, demo OTP отключён
- [ ] Иконка и splash: `dart run flutter_launcher_icons` и `dart run flutter_native_splash:create`
- [ ] Release-подпись (keystore / Apple certificates), без debug-ключей в сторе
- [ ] Сборки: `flutter build appbundle` / `flutter build ipa` (или Xcode Archive)

---

## Google Play — пассажир

| Поле | Значение / действие |
|------|---------------------|
| Название | КОРОЛИ ДОРОГ |
| Package | `com.korolidorog.koroli_dorog` (`android/app/build.gradle.kts`) |
| Краткое описание | Такси и трезвый водитель — закажите поездку за минуты |
| Полное описание | Возможности: классы авто, остановки, дети/животные, предзаказ, онлайн-оплата |
| Категория | Карты и навигация / Путешествия |
| Контент-рейтинг | Заполнить опросник IARC |
| Политика конфиденциальности URL | URL публичной политики (сайт / GitHub Pages) — **обязательно** |
| Data safety | Геолокация, телефон, платежи, crash/diagnostics — заполнить честно |
| Скриншоты | Телефон: ≥2, планшет по желанию; без placeholder «Yandex MapKit не подключён» |
| Иконка 512 | `docs/branding/app_icon_1024.png` → экспорт 512 без альфы |
| Feature graphic 1024×500 | Бренд gold `#F5C518` / purple `#7B5CFA` на `#0B0B0E` |
| Разрешения | Location (fine/coarse), Internet, Notifications (API 33+) — объяснить в формуляре |

### Функциональный smoke (пассажир)

- [ ] Онбординг → вход по телефону (OTP)
- [ ] Политика и условия открываются с auth / onboarding
- [ ] Геопоиск адресов, карта (с MapKit-ключом)
- [ ] Создание заказа: cash работает; card/SBP при заданном `PAYMENT_URL`
- [ ] Push (локальные или FCM) не крашат приложение
- [ ] Тема светлая/тёмная, выход из аккаунта

---

## Google Play — водитель

| Поле | Значение / действие |
|------|---------------------|
| Название | КОРОЛИ ДОРОГ Водитель |
| Package | `com.korolidorog.driver` |
| Описание | Приложение водителя: линия, заказы, KYC, навигация |
| Политика URL | Та же / водительская политика |
| Data safety | Документы KYC (фото), геолокация в фоне, телефон |
| Background location | Обосновать («на линии», передача позиции клиенту) |
| Скриншоты | Заказы, карта, профиль, статус регистрации |

### Функциональный smoke (водитель)

- [ ] Вход OTP + ссылки на политику / соглашение
- [ ] Регистрация / KYC (фото документов)
- [ ] Online / offline, принятие заказа, статусы поездки
- [ ] Push о новом заказе

---

## App Store — пассажир

| Поле | Значение / действие |
|------|---------------------|
| Display name | КОРОЛИ ДОРОГ |
| Bundle ID | `com.korolidorog.koroliDorog` |
| Privacy Nutrition Labels | Location, Contact Info, Usage Data — по факту сбора |
| Location purpose strings | Уже в `ios/Runner/Info.plist` (`NSLocationWhenInUse…`) |
| App Privacy Policy URL | Обязателен |
| Screenshots | 6.7" и 6.1" (минимум), без debug UI |
| Age rating | Обычно 4+ / 12+ при наличии пользовательского контента — проверить |
| Review notes | Тестовый телефон OTP, demo-аккаунт, карта/оплата: что включено в build |

### App Review checklist

- [ ] Нет сломанных placeholder-экранов в основном сценарии
- [ ] Запрос геолокации только с понятным пояснением
- [ ] Оплата: если card/SBP «скоро» — не обещать в маркетинге «полная онлайн-оплата»
- [ ] Ссылка на поддержку / email в «О приложении»

---

## App Store — водитель

- [ ] Display name: **КОРОЛИ ДОРОГ Водитель**
- [ ] Camera / Photo Library purpose strings (KYC) — в Info.plist
- [ ] Always/WhenInUse location strings для фонового режима
- [ ] Review notes: тестовый водитель, как пройти KYC без реальных паспортов (или предоставить sandbox-доки)

---

## Юридическое и комплаенс (РФ)

- [ ] Политика персональных данных (152-ФЗ) опубликована на сайте и встроена в приложение
- [ ] Пользовательское соглашение / оферта доступны до оплаты заказа
- [ ] Согласие на обработку ПДн на экране регистрации
- [ ] Контакты оператора ПДн и поддержки актуальны (`support@…`, телефон)
- [ ] При реальных платежах — чек 54-ФЗ через эквайер / ОФД

---

## После релиза

- [ ] Закрыть OTP demo / debug на VPS
- [ ] Включить Sentry DSN и/или Crashlytics (`CRASHLYTICS_ENABLED`) — [MONITORING.md](MONITORING.md)
- [ ] Uptime alert на API + admin
- [ ] Ответить на вопросы ревью сторов в 24–48 ч
- [ ] Зафиксировать build number; сохранить AAB/APK в `release/<version>/`

---

## Быстрые команды

```bash
# Пассажир
cd E:\project\Приложения\TaxiPro
flutter pub get
dart run flutter_launcher_icons
dart run flutter_native_splash:create
flutter build appbundle --release \
  --dart-define=USE_MOCK_API=false \
  --dart-define=API_BASE_URL=https://ваш-хост \
  --dart-define=MAPKIT_API_KEY=... \
  --dart-define=YANDEX_GEOCODER_KEY=... \
  --dart-define=PAYMENT_URL=...

# Водитель
cd E:\project\Приложения\TaxiPro\driver_app
flutter pub get
dart run flutter_launcher_icons
dart run flutter_native_splash:create
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://ваш-хост
```

Ключевые ссылки по настройкам:  
[YANDEX_MAPS_SETUP.md](YANDEX_MAPS_SETUP.md) · [GEO_SEARCH_SETUP.md](GEO_SEARCH_SETUP.md) · [SMS_SETUP.md](SMS_SETUP.md) · [PUSH_SETUP.md](PUSH_SETUP.md) · [PAYMENTS_SETUP.md](PAYMENTS_SETUP.md) · [APP_ICON.md](APP_ICON.md)
