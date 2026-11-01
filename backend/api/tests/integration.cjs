// Run only against a disposable local/CI Redis database, never a live installation.
require('reflect-metadata');
const assert = require('node:assert/strict');
const { randomUUID } = require('node:crypto');
const jwt = require('jsonwebtoken');
const { NestFactory } = require('@nestjs/core');
const { AppModule } = require('../dist/app.module');
const { DriversService } = require('../dist/drivers.service');
const { EventsGateway } = require('../dist/events.gateway');
const { RedisService } = require('../dist/redis.service');

(async () => {
  assert.equal(process.env.ALLOW_TEST_REDIS, '1', 'Set ALLOW_TEST_REDIS=1 for disposable Redis only');
  const redisUrl = new URL(process.env.REDIS_URL || 'redis://127.0.0.1:6379/15');
  assert(['127.0.0.1', 'localhost', 'redis'].includes(redisUrl.hostname), 'Test requires local Redis');
  assert.equal(redisUrl.pathname, '/15', 'Test requires isolated Redis database 15');
  process.env.REDIS_URL = redisUrl.toString();
  process.env.NODE_ENV = 'test';
  process.env.JWT_SECRET = randomUUID();
  process.env.ADMIN_JWT_SECRET = randomUUID();
  process.env.ADMIN_LOGIN = 'integration-admin';
  process.env.ADMIN_PASSWORD = randomUUID();
  const app = await NestFactory.create(AppModule, { logger: false });
  app.setGlobalPrefix('api');
  try {
    await app.listen(0, '127.0.0.1');
    const base = await app.getUrl();
    const drivers = app.get(DriversService);
    const gateway = app.get(EventsGateway);
    const redis = app.get(RedisService).client;
    const clientPhone = '+79000000001';
    const driverPhone = '+79000000002';
    await drivers.saveProfile(driverPhone, { fullName: 'Integration test driver', registrationStatus: 'completed' });
    const clientToken = jwt.sign({ phone: clientPhone, role: 'client' }, process.env.JWT_SECRET, { expiresIn: '5m' });
    async function request(endpoint, token, body) {
      const res = await fetch(`${base}/api${endpoint}`, { method: body ? 'POST' : 'GET',
        headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
        ...(body ? { body: JSON.stringify(body) } : {}) });
      const data = await res.json();
      assert(res.ok, `${endpoint}: ${res.status} ${JSON.stringify(data)}`);
      return data;
    }
    assert.equal((await request('/health/ready')).ok, true);
    const adminToken = (await request('/auth/otp/admin/login', null,
      { login: process.env.ADMIN_LOGIN, password: process.env.ADMIN_PASSWORD })).token;
    const route = { from: { lat: 55.75, lng: 37.61 }, to: { lat: 55.77, lng: 37.64 },
      serviceType: 'taxi', tariffId: 'economy', routeDistanceMeters: 5000,
      fromAddress: 'Integration A', toAddress: 'Integration B', paymentMethod: 'cash' };
    const quote = (await request('/orders/quote', null, route)).quote;
    await redis.set(`client:profile:${clientPhone}`, JSON.stringify({ promoDiscountPercent: 20, promoCode: 'TEST20' }));
    const create = { ...route, discountPercent: 99, requestId: randomUUID() };
    const order = (await request('/orders', clientToken, create)).order;
    assert.equal(order.priceFrom, Math.round(quote.priceFrom * .8), 'Only server promo is applied, exactly once');
    assert.equal((await request('/orders', clientToken, create)).order.id, order.id, 'Request replay is idempotent');
    assert.equal((await request(`/orders/${order.id}`, adminToken)).order.id, order.id);
    const assigned = (await request(`/admin/orders/${order.id}/assign`, adminToken, { driverPhone })).order;
    assert.equal(assigned.driverPhone, driverPhone);
    const clientSocket = { data: { user: { role: 'client', phone: clientPhone } }, join: async () => {} };
    assert.equal((await gateway.orderChat(clientSocket, { orderId: order.id, text: 'Integration hello' })).ok, true);
    const outsiderSocket = { data: { user: { role: 'client', phone: '+79000000003' } },
      join: async () => { throw new Error('Unauthorized room membership'); } };
    assert.equal((await gateway.orderChat(outsiderSocket, { orderId: order.id, text: 'Denied' })).ok, false);
    const driverSocket = { data: { user: { role: 'driver', phone: driverPhone } } };
    for (const status of ['enroute', 'arrived', 'waiting', 'started', 'completed']) {
      const ack = await gateway.update(driverSocket, { orderId: order.id, status });
      assert.equal(ack.ok, true, JSON.stringify(ack));
    }
    const final = (await request(`/orders/${order.id}`, clientToken)).order;
    assert.equal(final.status, 'completed');
    assert.equal(final.paymentStatus, 'paid');
    assert.equal(final.priceFinal, order.priceFrom, 'Taxi final price matches the accepted discounted fare');
    const history = (await request('/orders/history/client', clientToken)).orders;
    assert(history.some(item => item.id === order.id));
    const audit = await redis.lrange('admin:audit', 0, 20);
    assert(audit.some(item => item.includes(order.id)));
    console.log('Integration passed: real Redis, readiness, admin login, quote/order parity, assignment, chat authorization, full trip, history and audit.');
  } finally { await app.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
