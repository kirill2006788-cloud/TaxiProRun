/**
 * Lightweight unit-style checks for KV/OTP stores (no Redis required).
 * Run: npx ts-node --transpile-only src/store/kv-store.spec.ts
 * Or: node -e "require('ts-node/register'); require('./src/store/kv-store.spec.ts')"
 */
import { MemoryKvStore } from './kv-store';
import { KvOtpStore } from './otp.store';
import { MemoryRateLimitStore } from './rate-limit.store';
import {
  assertOrderStatusTransition,
  normalizeOrderStatus,
  assertPaymentStatusTransition,
} from '../order-status';

async function main() {
  let failed = 0;
  const assert = (cond: boolean, msg: string) => {
    if (!cond) {
      failed += 1;
      console.error('FAIL:', msg);
    } else {
      console.log('ok:', msg);
    }
  };

  const kv = new MemoryKvStore();
  await kv.set('a', '1', 2);
  assert((await kv.get('a')) === '1', 'memory get/set');
  assert((await kv.incr('c')) === 1, 'incr starts at 1');
  assert((await kv.incr('c')) === 2, 'incr increments');

  const otp = new KvOtpStore(kv);
  await otp.saveCode('+79001234567', 'hash', 60);
  assert((await otp.getHash('+79001234567')) === 'hash', 'otp store');
  await otp.clearCode('+79001234567');
  assert((await otp.getHash('+79001234567')) === null, 'otp clear');

  const rl = new MemoryRateLimitStore();
  const r1 = await rl.hit('t', 2, 60);
  const r2 = await rl.hit('t', 2, 60);
  const r3 = await rl.hit('t', 2, 60);
  assert(r1.allowed && r2.allowed && !r3.allowed, 'rate limit blocks 3rd');

  assert(normalizeOrderStatus('driver_arriving') === 'enroute', 'alias arriving');
  assert(normalizeOrderStatus('in_progress') === 'started', 'alias in_progress');
  try {
    assertOrderStatusTransition('searching', 'started', 'driver');
    assert(false, 'illegal transition should throw');
  } catch {
    assert(true, 'illegal transition rejected');
  }
  try {
    assertOrderStatusTransition('enroute', 'arrived', 'client');
    assert(false, 'client must not set arrived');
  } catch {
    assert(true, 'client forbidden on trip advance');
  }
  assertOrderStatusTransition('arrived', 'waiting', 'driver');
  assertOrderStatusTransition('waiting', 'started', 'driver');
  assertPaymentStatusTransition('paid', 'refunded');

  if (failed) {
    console.error(`\n${failed} failure(s)`);
    process.exit(1);
  }
  console.log('\nAll store/status checks passed');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
