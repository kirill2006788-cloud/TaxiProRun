const { test } = require('node:test');
const assert = require('node:assert/strict');
const vm = require('node:vm');
const fs = require('node:fs');

function setup(fetch) {
  const values = new Map();
  const context = vm.createContext({ fetch, URL, URLSearchParams, AbortController, setTimeout, clearTimeout,
    location: { protocol: 'http:', hostname: 'localhost', host: 'localhost:8080' },
    localStorage: { getItem: key => values.get(key) || null,
      setItem: (key, value) => values.set(key, value), removeItem: key => values.delete(key) },
  });
  vm.runInContext(fs.readFileSync(require('node:path').join(__dirname, '../js/api.js'), 'utf8')
    + '\nthis.api = AdminApi;', context);
  return context.api;
}

test('API base URL is normalized and a server change clears credentials', () => {
  const api = setup(() => {});
  api.setToken('local-test-token');
  api.setBaseUrl('http://localhost:4000/');
  assert.equal(api.getBaseUrl(), 'http://localhost:4000/api');
  assert.equal(api.getToken(), '');
  assert.throws(() => api.setBaseUrl('javascript:alert(1)'));
});

test('local admin uses the same-origin API proxy by default', () => {
  const api = setup(() => {});
  assert.equal(api.getBaseUrl(), 'http://localhost:8080/api');
});

test('simultaneous duplicate reads share one request', async () => {
  let count = 0;
  const api = setup(async () => { count++; return new Response('{"drivers":[]}', { status: 200 }); });
  await Promise.all([api.getDrivers(), api.getDrivers()]);
  assert.equal(count, 1);
});

test('403 preserves session while 401 expires it', async () => {
  let status = 403;
  const api = setup(async () => new Response('{"message":"Denied"}', { status }));
  api.setToken('local-test-token');
  await assert.rejects(api.getDrivers());
  assert.equal(api.getToken(), 'local-test-token');
  status = 401;
  await assert.rejects(api.getDrivers(), /AUTH_EXPIRED/);
  assert.equal(api.getToken(), '');
});

test('HTML returned instead of JSON is reported as a configuration error', async () => {
  const api = setup(async () => new Response('<html>Wrong host</html>', { status: 200 }));
  await assert.rejects(api.getDrivers(), /URL API/);
});

test('navigation cancels stale reads', async () => {
  const api = setup((url, options) => new Promise((resolve, reject) => {
    options.signal.addEventListener('abort', () => reject(new DOMException('Aborted', 'AbortError')));
  }));
  const read = api.getDrivers();
  api.cancelPending();
  await assert.rejects(read, /REQUEST_CANCELLED/);
});
