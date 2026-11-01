# Онлайн-оплата и касса — TaxiProRun

Мобильный клиент и backend готовы к серверному checkout-потоку. Приложение не хранит карты и никогда само не выставляет `paid`.

## Текущее поведение

| Метод | `paymentMethod` | Доступность |
|---|---|---|
| Наличные | `cash` | Всегда |
| Карта | `card` | Только если backend настроил эквайринг |
| СБП | `sbp` | Только если backend настроил эквайринг |

Перед созданием онлайн-заказа клиент читает `GET /api/payments/config`. После создания заказа он вызывает `POST /api/payments/intents` и открывает возвращённый HTTPS checkout URL. Повторный запрос по заказу возвращает тот же intent.

## Переменные backend

Добавить в `/opt/koroli-dorog-api/.env`:

```env
PAYMENT_CHECKOUT_URL=https://pay.provider.example/checkout
PAYMENT_WEBHOOK_SECRET=replace-with-long-random-secret
```

Пока обе переменные не заданы, карта и СБП честно отображаются как неподключённые, наличные продолжают работать.

## Эндпоинты

| Метод | Путь | Назначение |
|---|---|---|
| GET | `/api/payments/config` | Доступные способы оплаты |
| POST | `/api/payments/intents` | Идемпотентный checkout для заказа клиента |
| POST | `/api/payments/webhook` | Подписанное изменение `paid`/`failed` |
| POST | `/api/orders/:id/pay` | Ручная отметка администратором только завершённой поездки |

Webhook передаёт JSON:

```json
{ "intentId": "...", "status": "paid", "amount": 1200 }
```

Заголовок `x-payment-signature` — HMAC-SHA256 строки `intentId:status:amount` на `PAYMENT_WEBHOOK_SECRET`.

## Что требуется от банка/кассы

Нужно выбрать провайдера (например, ЮKassa, CloudPayments или Т-Банк) и получить боевые реквизиты магазина. Его адаптер должен создавать платёжную страницу и после фискализации вызывать защищённый webhook. Без договора, shop id, API key, системы налогообложения, ИНН продавца и параметров чека реальную онлайн-кассу активировать нельзя.
