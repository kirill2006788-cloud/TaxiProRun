/**
 * API-клиент админ-панели «КОРОЛИ ДОРОГ»
 */
const AdminApi = (() => {
  const TOKEN_KEY = 'koroli_admin_token';
  const API_URL_KEY = 'koroli_admin_api_url';
  let generation = 0;
  const pendingReads = new Map();
  const controllers = new Set();

  function normalizeBaseUrl(value) {
    const url = new URL(value.trim());
    if (!['http:', 'https:'].includes(url.protocol) || url.username || url.password) {
      throw new Error('Укажите адрес сервера в формате https://example.com/api');
    }
    url.search = '';
    url.hash = '';
    url.pathname = `${url.pathname.replace(/\/+$/, '').replace(/\/api$/, '')}/api`;
    if (typeof location !== 'undefined' && location.protocol === 'https:' && url.protocol !== 'https:') {
      throw new Error('Для защищённой админки требуется HTTPS-адрес API');
    }
    return url.toString().replace(/\/$/, '');
  }

  function cancelPending() {
    generation += 1;
    for (const controller of controllers) controller.abort();
    controllers.clear();
    pendingReads.clear();
  }

  function connection(state) {
    if (typeof window !== 'undefined') {
      window.dispatchEvent(new CustomEvent('admin:connection', { detail: { state } }));
    }
  }

  function getBaseUrl() {
    const saved = localStorage.getItem(API_URL_KEY);
    if (saved) {
      try { return normalizeBaseUrl(saved); } catch { localStorage.removeItem(API_URL_KEY); }
    }
    // Same host as admin panel when opened via http(s)://IP/admin/
    try {
      if (typeof location !== 'undefined' && location.protocol.startsWith('http') && location.hostname) {
        return `${location.protocol}//${location.host}/api`;
      }
    } catch (_) { /* ignore */ }
    return 'http://127.0.0.1:3000/api';
  }

  function setBaseUrl(url) {
    const normalized = normalizeBaseUrl(url);
    if (normalized !== getBaseUrl()) {
      setToken('');
      localStorage.setItem(API_URL_KEY, normalized);
    }
  }

  function getToken() {
    return localStorage.getItem(TOKEN_KEY) || '';
  }

  function setToken(token) {
    cancelPending();
    if (token) localStorage.setItem(TOKEN_KEY, token);
    else localStorage.removeItem(TOKEN_KEY);
  }

  function request(path, options = {}) {
    const key = `${generation}:${getBaseUrl()}:${path}`;
    if ((options.method || 'GET') !== 'GET') return performRequest(path, options);
    if (pendingReads.has(key)) return pendingReads.get(key);
    const promise = performRequest(path, options).finally(() => {
      if (pendingReads.get(key) === promise) pendingReads.delete(key);
    });
    pendingReads.set(key, promise);
    return promise;
  }

  async function performRequest(path, options = {}) {
    const requestGeneration = generation;
    const controller = new AbortController();
    controllers.add(controller);
    const timeout = setTimeout(() => controller.abort(), 15000);
    const url = `${getBaseUrl()}${path.startsWith('/') ? path : `/${path}`}`;
    const headers = {
      Accept: 'application/json',
      ...(options.headers || {}),
    };
    const token = getToken();
    if (token) headers.Authorization = `Bearer ${token}`;

    try {
      const res = await fetch(url, {
        ...options,
        headers,
        cache: 'no-store',
        signal: controller.signal,
      });

      if (requestGeneration !== generation) throw new Error('REQUEST_CANCELLED');
      connection('online');

      if (res.status === 401 && !path.includes('/admin/login')) {
        setToken('');
        throw new Error('AUTH_EXPIRED');
      }

      let data = null;
      const text = await res.text();
      try {
        data = text ? JSON.parse(text) : null;
      } catch {
        throw new Error('Сервер вернул некорректный ответ. Проверьте URL API.');
      }

      if (!res.ok) {
        const msg = data?.message || data?.error || `HTTP ${res.status}`;
        throw new Error(msg);
      }
      return data;
    } catch (error) {
      if (requestGeneration !== generation && error.message !== 'AUTH_EXPIRED') {
        throw new Error('REQUEST_CANCELLED');
      }
      if (error.name === 'AbortError' || error instanceof TypeError) {
        connection('offline');
        throw new Error(error.name === 'AbortError'
          ? 'Сервер не ответил за 15 секунд. Повторите запрос.'
          : 'Нет связи с сервером. Проверьте подключение и URL API.');
      }
      if (path.includes('/admin/login') && error.message === 'Unauthorized') {
        throw new Error('Неверный логин или пароль');
      }
      throw error;
    } finally {
      clearTimeout(timeout);
      controllers.delete(controller);
    }
  }

  return {
    getBaseUrl,
    setBaseUrl,
    cancelPending,
    getToken,
    setToken,
    isLoggedIn: () => !!getToken(),

    async login(login, password) {
      const data = await request('/auth/otp/admin/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ login, password }),
      });
      if (data?.token) setToken(data.token);
      return data;
    },

    logout() {
      setToken('');
    },

    // Stats
    getStats(period = 'day', mode = 'orders') {
      return request(`/admin/stats/orders?period=${period}&mode=${mode}`);
    },

    getCancelReasonStats(limit = 2000) {
      return request(`/admin/stats/cancel-reasons?limit=${limit}`);
    },

    // Drivers
    getDrivers(view = 'manage', opts = {}) {
      const q = new URLSearchParams({ view });
      if (opts.includeLocation) q.set('includeLocation', '1');
      if (opts.includePhotos) q.set('includePhotos', '1');
      return request(`/admin/drivers?${q}`);
    },

    getDriver(phone) {
      return request(`/admin/drivers/${encodeURIComponent(phone)}`);
    },

    getDriverPhotos(phone) {
      return request(`/admin/drivers/${encodeURIComponent(phone)}/photos`);
    },

    approveDriver(phone) {
      return request(`/admin/drivers/${encodeURIComponent(phone)}/approve`, { method: 'POST' });
    },

    rejectDriver(phone) {
      return request(`/admin/drivers/${encodeURIComponent(phone)}/reject`, { method: 'POST' });
    },

    forcePendingDriver(phone) {
      return request(`/admin/drivers/${encodeURIComponent(phone)}/force-pending`, { method: 'POST' });
    },

    blockDriver(phone, reason = '') {
      return request(`/admin/drivers/${encodeURIComponent(phone)}/block`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ reason }),
      });
    },

    unblockDriver(phone) {
      return request(`/admin/drivers/${encodeURIComponent(phone)}/unblock`, { method: 'POST' });
    },

    getDriverOrders(phone, limit = 50) {
      return request(`/admin/drivers/${encodeURIComponent(phone)}/orders?limit=${limit}`);
    },

    // Clients
    getClients() {
      return request('/admin/clients');
    },

    blockClient(id, reason = '') {
      return request(`/admin/clients/${encodeURIComponent(id)}/block`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ reason }),
      });
    },

    unblockClient(id) {
      return request(`/admin/clients/${encodeURIComponent(id)}/unblock`, { method: 'POST' });
    },

    getClientOrders(id, limit = 50) {
      return request(`/admin/clients/${encodeURIComponent(id)}/orders?limit=${limit}`);
    },

    getClientComment(id) {
      return request(`/admin/clients/${encodeURIComponent(id)}/comment`);
    },

    saveClientComment(id, comment) {
      return request(`/admin/clients/${encodeURIComponent(id)}/comment`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ comment }),
      });
    },

    // Orders
    getOrders(params = {}) {
      const q = new URLSearchParams({ limit: '200', ...params });
      return request(`/orders?${q}`);
    },

    cancelOrder(id, reason = '') {
      return request(`/admin/orders/${encodeURIComponent(id)}/cancel`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ reason }),
      });
    },

    assignOrder(id, driverPhone) {
      return request(`/admin/orders/${encodeURIComponent(id)}/assign`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ driverPhone }),
      });
    },

    getOrder(id) {
      return request(`/admin/orders/${encodeURIComponent(id)}`);
    },

    getAudit(limit = 100) {
      return request(`/admin/audit?limit=${limit}`);
    },

    payOrder(id) {
      return request(`/admin/orders/${encodeURIComponent(id)}/pay`, { method: 'POST' });
    },

    // Tariffs
    getTariffs() {
      return request('/admin/tariffs');
    },

    saveTariffs(tariffs) {
      return request('/admin/tariffs', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ tariffs }),
      });
    },

    getTaxiTariffs() {
      return request('/admin/taxi-tariffs');
    },

    saveTaxiTariffs(tariffs) {
      return request('/admin/taxi-tariffs', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ tariffs }),
      });
    },

    // Promos
    getPromos() {
      return request('/admin/promos');
    },

    createPromo(body) {
      return request('/admin/promos', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
    },

    disablePromo(code) {
      return request(`/admin/promos/${encodeURIComponent(code)}/disable`, { method: 'POST' });
    },

    // Settings
    getSubscriptionSettings() {
      return request('/admin/subscription/settings');
    },

    saveSubscriptionSettings(body) {
      return request('/admin/subscription/settings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
    },

    getOrderTimeoutSettings() {
      return request('/admin/order-timeout/settings');
    },

    saveOrderTimeoutSettings(orderAcceptTimeoutSec) {
      return request('/admin/order-timeout/settings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ orderAcceptTimeoutSec }),
      });
    },

    getAntifraudSettings() {
      return request('/admin/antifraud/settings');
    },

    saveAntifraudSettings(body) {
      return request('/admin/antifraud/settings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
    },

    // Support
    getSupportTickets() {
      return request('/admin/support/tickets');
    },

    replySupportTicket(id, message) {
      return request(`/admin/support/tickets/${encodeURIComponent(id)}/reply`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ body: message }),
      });
    },

    closeSupportTicket(id) {
      return request(`/admin/support/tickets/${encodeURIComponent(id)}/close`, {
        method: 'POST',
      });
    },

    // Payouts / finance
    getPayouts(limit = 50, driverPhone = '') {
      const q = new URLSearchParams({ limit: String(limit) });
      if (driverPhone) q.set('driverPhone', driverPhone);
      return request(`/admin/payouts?${q}`);
    },

    createPayout(body) {
      return request('/admin/payouts', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
    },

    // Broadcasts / service announcements
    getBroadcasts() {
      return request('/admin/broadcasts');
    },

    createBroadcast(body) {
      return request('/admin/broadcasts', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
    },

    deactivateBroadcast(id) {
      return request(`/admin/broadcasts/${encodeURIComponent(id)}/deactivate`, {
        method: 'POST',
      });
    },

    deleteBroadcast(id) {
      return request(`/admin/broadcasts/${encodeURIComponent(id)}`, {
        method: 'DELETE',
      });
    },

    getActiveBroadcasts(audience = 'all') {
      return request(`/broadcasts/active?audience=${encodeURIComponent(audience)}`);
    },
  };
})();
