# КОРОЛИ ДОРОГ — Водитель



Flutter-приложение водителя. По умолчанию — mock API; реальный сервер: `http://161.104.19.23`.



## Запуск



`TaxiProRun` — ASCII-junction на `E:\project\Приложения\TaxiPro` (избегает проблем кириллицы в пути при сборке):



```powershell

cd E:\project\TaxiProRun\driver_app

flutter pub get

flutter run

```



Подключение к реальному API:



```powershell

flutter run --dart-define=USE_MOCK_API=false --dart-define=API_BASE_URL=http://161.104.19.23

```



Затем в **Настройки** выключите mock. Health: `curl http://161.104.19.23/api/health`.



## Авторизация и регистрация



1. **Вход:** экран `/login` — OTP по SMS или «Войти (демо)».

2. **Регистрация:** после первого входа — мастер `/registration` (ФИО, авто, документы).

3. **Статус:** `/registration-status` — «На проверке» / «Отклонено» / «Завершено».

4. **На линии:** переключатель «На линии» активен только при `registrationStatus == completed` (верификация пройдена).



### Тестирование сценариев



| Сценарий | Как проверить |

|----------|----------------|

| Демо-вход | `/login` → «Войти (демо)» |

| OTP (real) | `USE_MOCK_API=false`, номер + код с сервера |

| Регистрация pending | mock-профиль с `registrationStatus: pending` |

| Офлайн | выключить «На линии» на экране заказов |

| Новый заказ | «Симулировать новый заказ» (mock) |



## Проверка качества



```powershell

cd E:\project\TaxiProRun\driver_app

flutter analyze

flutter test

```



## Package / имя



- `com.korolidorog.driver`

- **КОРОЛИ ДОРОГ — Водитель**

