import 'reflect-metadata';
import test from 'node:test';
import assert from 'node:assert/strict';
import jwt from 'jsonwebtoken';
import { AuthController } from './auth.controller';
import { EventsGateway } from './events.gateway';
import { allowOrigin } from './cors-policy';
import { OrdersController } from './orders.controller';
import { DriversService } from './drivers.service';
import { DriversController } from './drivers.controller';
import { OrdersService } from './orders.service';

test('refresh validates signatures and the expiry grace period', async () => {
  const previous = process.env.JWT_SECRET;
  process.env.JWT_SECRET = 'test-only-secret-with-at-least-32-characters';
  try {
    const auth = new AuthController(null as any, null as any, null as any);
    const payload = { phone: '+79000000001', role: 'client' };
    const expired = jwt.sign(payload, process.env.JWT_SECRET, { expiresIn: -60 });
    const result = await auth.refresh({ token: expired });
    assert.equal((jwt.verify(result.token, process.env.JWT_SECRET) as any).phone, payload.phone);
    const forged = jwt.sign(payload, 'another-secret', { expiresIn: -60 });
    await assert.rejects(() => auth.refresh({ token: forged }));
    const stale = jwt.sign(payload, process.env.JWT_SECRET, { expiresIn: -8 * 86400 });
    await assert.rejects(() => auth.refresh({ token: stale }));
    const noExpiry = jwt.sign(payload, process.env.JWT_SECRET);
    await assert.rejects(() => auth.refresh({ token: noExpiry }));
  } finally {
    if (previous === undefined) delete process.env.JWT_SECRET;
    else process.env.JWT_SECRET = previous;
  }
});

test('unauthorized chat send never joins another trip room', async () => {
  const orders = { addChatMessage: async () => { throw new Error('Access denied'); } };
  const gateway = new EventsGateway(orders as any, null as any, null as any, null as any);
  const joined: string[] = [];
  const client = { data: { user: { phone: '+79000000002', role: 'client' } },
    join: (room: string) => joined.push(room) };
  const result = await gateway.orderChat(client as any, { orderId: 'another-trip', text: 'hello' });
  assert.equal(result.ok, false);
  assert.deepEqual(joined, []);
});

test('targeted broadcasts emit once to the requested audience', () => {
  const emitted: Array<{ rooms: unknown; event: string }> = [];
  const gateway = new EventsGateway(null as any, null as any, null as any, null as any);
  gateway.server = { to: (rooms: unknown) => ({ emit: (event: string) => emitted.push({ rooms, event }) }) } as any;
  gateway.emitBroadcast({ id: 'test', title: 'Service', body: 'Notice', type: 'info', audience: 'drivers' });
  assert.deepEqual(emitted, [{ rooms: ['drivers'], event: 'broadcast:new' }]);
});

test('native clients are accepted and localhost lookalike domains are rejected', () => {
  assert.equal(allowOrigin(undefined), true);
  assert.equal(allowOrigin('http://localhost.attacker.example'), false);
  assert.equal(allowOrigin('http://127.0.0.1.attacker.example'), false);
  assert.equal(allowOrigin('not a URL'), false);
});

test('admin can open an order when admin and app JWT secrets differ', async () => {
  const previousApp = process.env.JWT_SECRET;
  const previousAdmin = process.env.ADMIN_JWT_SECRET;
  process.env.JWT_SECRET = 'app-test-secret';
  process.env.ADMIN_JWT_SECRET = 'separate-admin-test-secret';
  try {
    const orders = { getOrder: async () => ({ id: 'test-order', clientId: '+79000000001' }) };
    const controller = new OrdersController(orders as any, null as any, null as any, null as any);
    const token = jwt.sign({ role: 'admin', scope: 'admin:full' }, process.env.ADMIN_JWT_SECRET,
      { issuer: 'prostotaxi-admin', audience: 'prostotaxi-admin-panel', expiresIn: '5m' });
    assert.equal((await controller.get('test-order', `Bearer ${token}`)).order.id, 'test-order');
    const client = jwt.sign({ role: 'client', phone: '+79000000002' }, process.env.JWT_SECRET, { expiresIn: '5m' });
    await assert.rejects(() => controller.get('test-order', `Bearer ${client}`));
  } finally {
    if (previousApp === undefined) delete process.env.JWT_SECRET;
    else process.env.JWT_SECRET = previousApp;
    if (previousAdmin === undefined) delete process.env.ADMIN_JWT_SECRET;
    else process.env.ADMIN_JWT_SECRET = previousAdmin;
  }
});

test('driver identity keeps its plus prefix when selected by an administrator', async () => {
  const drivers = new DriversService({ client: { get: async (key: string) =>
    key === 'driver:profile:+79000000001' ? '{"registrationStatus":"completed"}' : null } } as any);
  assert.equal(await drivers.resolveProfilePhone('+7 (900) 000-00-01'), '+79000000001');
  assert.equal(await drivers.resolveProfilePhone('79000000001'), '+79000000001');
  assert.equal(await drivers.resolveProfilePhone('invalid'), null);
});

test('public driver profile never uses a passport scan as an avatar', async () => {
  const previous = process.env.JWT_SECRET;
  process.env.JWT_SECRET = 'only-for-avatar-test';
  try {
    const drivers = { resolveProfilePhone: async () => '+79000000001',
      getProfile: async () => ({ fullName: 'Test', passportFrontBase64: 'private-document', selfieBase64: 'private-selfie' }) };
    const orders = { getDriverRating: async () => ({ avg: 5, count: 1 }) };
    const redis = { client: { get: async () => null } };
    const controller = new DriversController(drivers as any, orders as any, redis as any);
    const token = jwt.sign({ phone: '+79000000002', role: 'client' }, process.env.JWT_SECRET);
    const result = await controller.getPublicProfile('+79000000001', `Bearer ${token}`);
    assert.equal(result.profile.avatarBase64, null);
    assert.equal(JSON.stringify(result).includes('private-document'), false);
    assert.equal(JSON.stringify(result).includes('private-selfie'), false);
  } finally {
    if (previous === undefined) delete process.env.JWT_SECRET;
    else process.env.JWT_SECRET = previous;
  }
});

test('taxi completion preserves its accepted price instead of sober-driver rates', async () => {
  const orders = new OrdersService(null as any, null as any);
  const result = await (orders as any).computeFinalPrice({ serviceType: 'taxi', priceFrom: 650,
    promoDiscountPercent: 20, startedAt: '2026-11-01T08:00:00Z', completedAt: '2026-11-01T08:15:00Z' });
  assert.deepEqual(result, { price: 650, minutes: 15 });
});
