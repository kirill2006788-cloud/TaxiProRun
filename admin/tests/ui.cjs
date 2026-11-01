// Local UI checks use synthetic API fixtures and never access production accounts.
const assert = require('node:assert/strict');
const http = require('node:http');
const fs = require('node:fs/promises');
const path = require('node:path');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');

(async () => {
  const root = path.resolve(__dirname, '..');
  const output = path.resolve(root, '../artifacts');
  await fs.mkdir(output, { recursive: true });
  const server = http.createServer(async (req, res) => {
    try {
      const url = new URL(req.url, 'http://localhost');
      const file = path.resolve(root, '.' + (url.pathname === '/' ? '/index.html' : url.pathname));
      if (!file.startsWith(root + path.sep)) { res.writeHead(403).end(); return; }
      const type = { '.html': 'text/html', '.css': 'text/css', '.js': 'application/javascript' }[path.extname(file)];
      res.setHeader('Content-Type', `${type || 'application/octet-stream'}; charset=utf-8`);
      res.end(await fs.readFile(file));
    } catch { res.writeHead(404).end(); }
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  let browser;
  try {
    browser = await chromium.launch({ headless: true,
      ...(process.env.PLAYWRIGHT_CHROMIUM_PATH ? { executablePath: process.env.PLAYWRIGHT_CHROMIUM_PATH } : {}) });
    const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    let dispatchRequests = 0;
    const order = { id: 'test-order-1', clientId: 'test-client', clientName: 'Тестовый пассажир',
      fromAddress: 'Тестовая улица, 1', toAddress: 'Тестовый проспект, 2',
      from: { lat: 55.75, lng: 37.61 }, to: { lat: 55.77, lng: 37.64 },
      priceFrom: 650, status: 'waiting', driverPhone: 'test-driver', paymentMethod: 'cash',
      createdAt: '2026-11-01T08:00:00Z' };
    await page.route('**/api/**', async route => {
      const url = new URL(route.request().url());
      let payload = { ok: true };
      if (url.pathname.endsWith('/admin/login')) payload.token = 'synthetic-ui-test-token';
      else if (url.pathname.includes('/stats/orders')) payload = { list: [{ k: 'GMV', v: '12 500 ₽' },
        { k: 'Заказы', v: '18' }], labels: [], series: [], source: 'Тестовые данные' };
      else if (url.pathname.includes('/stats/cancel-reasons')) payload.items = [];
      else if (url.pathname.endsWith('/drivers')) payload.drivers = [{ phone: 'test-driver', status: 'busy',
        profile: { fullName: 'Тестовый водитель', registrationStatus: 'completed' } }];
      else if (url.pathname.endsWith('/orders')) {
        if (url.searchParams.get('active')) dispatchRequests++;
        payload.orders = [order];
      } else if (url.pathname.endsWith('/test-order-1')) payload.order = order;
      else if (url.pathname.endsWith('/status-history')) payload.history = [];
      else if (url.pathname.includes('/broadcasts')) payload.broadcasts = [];
      else if (url.pathname.includes('/clients')) payload.clients = [];
      else if (url.pathname.includes('/tariffs')) payload.tariffs = [];
      else if (url.pathname.includes('/tickets')) payload.tickets = [];
      else if (url.pathname.includes('/promos')) payload.promos = [];
      else if (url.pathname.includes('/payouts')) payload.payouts = [];
      else if (url.pathname.includes('/audit')) payload.items = [];
      await route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(payload) });
    });
    await page.goto(`http://127.0.0.1:${server.address().port}`);
    // Avoid external map/CDN dependencies in a deterministic UI test.
    await page.evaluate(() => {
      AdminYandexMap.render = async () => false;
      AdminLeafletMap.render = async () => false;
    });
    await page.screenshot({ path: path.join(output, 'admin-login.png'), fullPage: true });
    await page.locator('#apiUrlInput').fill('http://localhost:3000/api');
    await page.locator('#loginInput').fill('test-admin');
    await page.locator('#passwordInput').fill('test-password-only');
    await page.locator('#loginBtn').click();
    await page.locator('#dashPrimary').waitFor();
    assert.match(await page.locator('#apiStatus').innerText(), /на связи/);
    await page.screenshot({ path: path.join(output, 'admin-dashboard.png'), fullPage: true });
    await page.locator('[data-nav="dispatch"]').click();
    await page.locator('#dispatchOrders .dispatch-order').waitFor();
    assert.match(await page.locator('#dispatchOrders').innerText(), /Ожидает клиента/);
    assert.equal(await page.locator('.stats .v').first().innerText(), '1');
    await page.screenshot({ path: path.join(output, 'admin-dispatch.png'), fullPage: true });
    await page.locator('#dispatchOrders [data-order]').click();
    await page.locator('#modalBg:not(.hidden)').waitFor();
    await page.keyboard.press('Escape');
    assert.equal(await page.locator('#modalBg').isVisible(), false);
    for (const section of ['drivers', 'clients', 'orders', 'support', 'tariffs', 'audit', 'settings']) {
      await page.locator(`[data-nav="${section}"]`).click();
      await page.locator('#content h1').waitFor();
      assert.equal(await page.locator('#content > .empty > [data-retry]').count(), 0, `${section} failed to load`);
    }
    await page.setViewportSize({ width: 390, height: 844 });
    await page.locator('#menuBtn').click();
    await page.locator('[data-nav="dispatch"]').click();
    await page.locator('#dispatchOrders .dispatch-order').waitFor();
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true,
      'mobile page must not overflow horizontally');
    await page.screenshot({ path: path.join(output, 'admin-mobile.png'), fullPage: true, animations: 'disabled' });
    await page.locator('#menuBtn').click();
    await page.locator('#logoutBtn').click();
    await page.locator('#loginScreen:not(.hidden)').waitFor();
    assert.equal(await page.evaluate(() => localStorage.getItem('koroli_admin_token')), null);
    assert.deepEqual(errors, []);
    console.log(`Admin UI passed: login, dashboard, dispatch/waiting, modal, 7 sections, mobile, logout (${dispatchRequests} dispatch reads).`);
  } finally {
    if (browser) await browser.close();
    await new Promise(resolve => server.close(resolve));
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
