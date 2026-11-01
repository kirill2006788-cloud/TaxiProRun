/**
 * Админ-панель «КОРОЛИ ДОРОГ»
 */
(() => {
  'use strict';

  const ICONS = {
    dashboard: '<svg class="icon" viewBox="0 0 24 24"><rect x="3" y="3" width="7" height="9" rx="1.5"/><rect x="14" y="3" width="7" height="5" rx="1.5"/><rect x="14" y="12" width="7" height="9" rx="1.5"/><rect x="3" y="16" width="7" height="5" rx="1.5"/></svg>',
    dispatch: '<svg class="icon" viewBox="0 0 24 24"><circle cx="12" cy="12" r="3"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M4.9 19.1L7 17M17 7l2.1-2.1"/></svg>',
    verify: '<svg class="icon" viewBox="0 0 24 24"><path d="M9 12l2 2 4-4"/><circle cx="12" cy="12" r="9"/></svg>',
    drivers: '<svg class="icon" viewBox="0 0 24 24"><path d="M3 13l2-5a2 2 0 012-1h10a2 2 0 012 1l2 5"/><path d="M5 16h14"/><circle cx="7.5" cy="16.5" r="1.5"/><circle cx="16.5" cy="16.5" r="1.5"/><path d="M5 13h14"/></svg>',
    clients: '<svg class="icon" viewBox="0 0 24 24"><circle cx="12" cy="8" r="3.5"/><path d="M5 19a7 7 0 0114 0"/></svg>',
    orders: '<svg class="icon" viewBox="0 0 24 24"><path d="M8 6h13M8 12h13M8 18h13"/><path d="M3 6h.01M3 12h.01M3 18h.01"/></svg>',
    support: '<svg class="icon" viewBox="0 0 24 24"><path d="M21 15a4 4 0 01-4 4H8l-5 3V7a4 4 0 014-4h10a4 4 0 014 4v8z"/></svg>',
    broadcasts: '<svg class="icon" viewBox="0 0 24 24"><path d="M12 3v1M12 20v1M4.2 4.2l.7.7M19.1 19.1l.7.7M3 12h1M20 12h1M4.2 19.8l.7-.7M19.1 4.9l.7-.7"/><circle cx="12" cy="12" r="4"/><path d="M12 8a8 8 0 018 8"/></svg>',
    tariffs: '<svg class="icon" viewBox="0 0 24 24"><path d="M12 3v18"/><path d="M17 8a4 4 0 00-8 0c0 3 8 2 8 6a4 4 0 01-8 0"/></svg>',
    promos: '<svg class="icon" viewBox="0 0 24 24"><path d="M20 12l-8-8H6v6l8 8 6-6z"/><circle cx="8.5" cy="8.5" r="1"/></svg>',
    finance: '<svg class="icon" viewBox="0 0 24 24"><path d="M12 3v18"/><path d="M17 8H9.5a2.5 2.5 0 000 5h5a2.5 2.5 0 010 5H7"/></svg>',
    settings: '<svg class="icon" viewBox="0 0 24 24"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 00.3 1.8l.1.1a2 2 0 11-2.8 2.8l-.1-.1a1.7 1.7 0 00-1.8-.3 1.7 1.7 0 00-1 1.5V21a2 2 0 11-4 0v-.1a1.7 1.7 0 00-1-1.5 1.7 1.7 0 00-1.8.3l-.1.1a2 2 0 11-2.8-2.8l.1-.1a1.7 1.7 0 00.3-1.8 1.7 1.7 0 00-1.5-1H3a2 2 0 110-4h.1a1.7 1.7 0 001.5-1 1.7 1.7 0 00-.3-1.8l-.1-.1a2 2 0 112.8-2.8l.1.1a1.7 1.7 0 001.8.3H9a1.7 1.7 0 001-1.5V3a2 2 0 114 0v.1a1.7 1.7 0 001 1.5 1.7 1.7 0 001.8-.3l.1-.1a2 2 0 112.8 2.8l-.1.1a1.7 1.7 0 00-.3 1.8V9c.3.6.9 1 1.5 1H21a2 2 0 110 4h-.1a1.7 1.7 0 00-1.5 1z"/></svg>',
    audit: '<svg class="icon" viewBox="0 0 24 24"><path d="M14 2H6a2 2 0 00-2 2v16a2 2 0 002 2h12a2 2 0 002-2V8z"/><path d="M14 2v6h6M9 13h6M9 17h6"/></svg>',
  };

  const PAGES = [
    { id: 'dashboard', title: 'Дашборд', icon: 'dashboard' },
    { id: 'dispatch', title: 'Диспетчерская', icon: 'dispatch' },
    { id: 'verify', title: 'Проверка', icon: 'verify', badge: true },
    { id: 'support', title: 'Поддержка', icon: 'support' },
    { id: 'broadcasts', title: 'Уведомления', icon: 'broadcasts' },
    { id: 'drivers', title: 'Водители', icon: 'drivers' },
    { id: 'clients', title: 'Клиенты', icon: 'clients' },
    { id: 'orders', title: 'Заказы', icon: 'orders' },
    { id: 'finance', title: 'Финансы', icon: 'finance' },
    { id: 'tariffs', title: 'Тарифы', icon: 'tariffs' },
    { id: 'promos', title: 'Промокоды', icon: 'promos' },
    { id: 'audit', title: 'Журнал', icon: 'audit' },
    { id: 'settings', title: 'Настройки', icon: 'settings' },
  ];

  const LOCAL_AUDIT_KEY = 'koroli_admin_local_audit';
  const LOCAL_AUDIT_LABEL = 'Локальный журнал (браузер)';

  function pushLocalAudit(action, target = '', details = '') {
    try {
      const raw = localStorage.getItem(LOCAL_AUDIT_KEY);
      const list = raw ? JSON.parse(raw) : [];
      const entry = {
        id: `local_${Date.now()}_${Math.random().toString(36).slice(2, 7)}`,
        action,
        target,
        details,
        admin: 'local',
        createdAt: new Date().toISOString(),
        source: 'local',
      };
      list.unshift(entry);
      localStorage.setItem(LOCAL_AUDIT_KEY, JSON.stringify(list.slice(0, 200)));
    } catch (_) { /* ignore */ }
  }

  function readLocalAudit(limit = 100) {
    try {
      const raw = localStorage.getItem(LOCAL_AUDIT_KEY);
      const list = raw ? JSON.parse(raw) : [];
      return Array.isArray(list) ? list.slice(0, limit) : [];
    } catch {
      return [];
    }
  }

  let page = 'dashboard';
  let verifyCount = 0;
  let bound = false;
  let supportCache = [];
  let clientsCache = [];
  let photoLightbox = [];
  let photoLightboxIdx = 0;
  let dispatchTimer = null;
  let dispatchDriversCache = [];
  let dispatchOrdersCache = [];
  let dispatchMapProvider = '';
  let modalReturnFocus = null;
  let navigationVersion = 0;

  const DISPATCH_REFRESH_MS = 15000;

  function stopDispatchRefresh() {
    if (dispatchTimer) {
      clearInterval(dispatchTimer);
      dispatchTimer = null;
    }
    if (typeof AdminYandexMap !== 'undefined') AdminYandexMap.destroy();
    if (typeof AdminLeafletMap !== 'undefined') AdminLeafletMap.destroy();
    dispatchMapProvider = '';
  }

  function yandexKeyPresent() {
    return !!(window.ADMIN_CONFIG && String(window.ADMIN_CONFIG.yandexMapsApiKey || '').trim());
  }

  async function mountDispatchMap(drivers, orders) {
    const host = document.getElementById('dispatchMapHost');
    if (!host) return;
    const prefer = (window.ADMIN_CONFIG && window.ADMIN_CONFIG.mapProvider) || 'auto';

    const tryYandex = async () => {
      if (typeof AdminYandexMap === 'undefined' || !yandexKeyPresent()) return false;
      if (dispatchMapProvider && dispatchMapProvider !== 'yandex') {
        if (typeof AdminLeafletMap !== 'undefined') AdminLeafletMap.destroy();
      }
      const ok = await AdminYandexMap.render(host, drivers, orders);
      if (ok) {
        dispatchMapProvider = 'yandex';
        const lbl = $('#dispatchMapLabel');
        if (lbl) lbl.textContent = 'Карта · Яндекс';
        return true;
      }
      return false;
    };

    const tryLeaflet = async () => {
      if (typeof AdminLeafletMap === 'undefined') return false;
      if (dispatchMapProvider && dispatchMapProvider !== 'leaflet') {
        if (typeof AdminYandexMap !== 'undefined') AdminYandexMap.destroy();
      }
      const ok = await AdminLeafletMap.render(host, drivers, orders);
      if (ok) {
        dispatchMapProvider = 'leaflet';
        const lbl = $('#dispatchMapLabel');
        if (lbl) lbl.textContent = 'Карта · OpenStreetMap';
        return true;
      }
      return false;
    };

    if (prefer === 'leaflet') {
      if (await tryLeaflet()) return;
      if (await tryYandex()) return;
    } else if (prefer === 'yandex') {
      if (await tryYandex()) return;
      if (await tryLeaflet()) return;
    } else {
      if (await tryYandex()) return;
      if (await tryLeaflet()) return;
    }

    dispatchMapProvider = 'placeholder';
    const lbl = $('#dispatchMapLabel');
    if (lbl) lbl.textContent = 'Карта · без GPS / офлайн';
    host.innerHTML = renderDriverMap(drivers);
  }

  function startDispatchRefresh() {
    if (dispatchTimer) clearTimeout(dispatchTimer);
    dispatchTimer = setTimeout(async () => {
      try {
        if (page === 'dispatch' && !document.hidden && AdminApi.isLoggedIn()) {
          await loadDispatch({ silent: true });
        }
      } catch (error) {
        if (error.message === 'AUTH_EXPIRED') return showLogin();
        if (error.message !== 'REQUEST_CANCELLED') {
          const stamp = $('#dispatchLiveStamp');
          if (stamp) stamp.textContent = 'Обновление не удалось · повторим автоматически';
        }
      } finally {
        if (page === 'dispatch' && AdminApi.isLoggedIn()) startDispatchRefresh();
      }
    }, DISPATCH_REFRESH_MS);
  }

  function statusLabel(status) {
    const map = {
      searching: 'Поиск водителя',
      accepted: 'Принят',
      enroute: 'В пути к клиенту',
      arrived: 'Прибыл',
      waiting: 'Ожидает клиента',
      started: 'Поездка',
      completed: 'Завершён',
      canceled: 'Отменён',
    };
    return map[status] || status || '—';
  }

  function actorLabel(actor) {
    const map = { client: 'Клиент', driver: 'Водитель', admin: 'Админ', system: 'Система' };
    return map[actor] || actor || '—';
  }

  function renderTimeline(items) {
    if (!items?.length) {
      return '<div class="empty">История статусов пока пуста</div>';
    }
    return `<div class="timeline">${items.map((e) => `
      <div class="timeline-item">
        <div class="timeline-dot"></div>
        <div class="timeline-body">
          <div class="timeline-top">
            <strong>${esc(statusLabel(e.to))}</strong>
            <span class="dim">${date(e.at)}</span>
          </div>
          <div class="dim">${esc(actorLabel(e.actor))}${e.from ? ` · ${esc(statusLabel(e.from))} → ${esc(statusLabel(e.to))}` : ''}</div>
          ${e.reason ? `<div class="timeline-reason">Причина: ${esc(e.reason)}</div>` : ''}
        </div>
      </div>`).join('')}</div>`;
  }

  function renderChat(messages) {
    if (!messages?.length) {
      return '<div class="empty">Сообщений в чате поездки нет</div>';
    }
    return `<div class="ticket-thread">${messages.map((m) => `
      <div class="ticket-msg ${m.senderRole === 'driver' ? 'admin' : ''}">
        <div class="ticket-msg-h">${m.senderRole === 'driver' ? 'Водитель' : 'Клиент'} · ${date(m.createdAt)}</div>
        <div class="ticket-msg-b">${esc(m.text)}</div>
      </div>`).join('')}</div>`;
  }

  const $ = (s, root = document) => root.querySelector(s);
  const $$ = (s, root = document) => [...root.querySelectorAll(s)];
  const content = $('#content');
  const nav = $('#nav');
  const sidebar = $('#sidebar');
  const backdrop = $('#backdrop');

  function esc(v) {
    return String(v ?? '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  function money(n) {
    return `${Math.round(Number(n) || 0).toLocaleString('ru-RU')} ₽`;
  }

  function date(iso) {
    if (!iso) return '—';
    try {
      return new Date(iso).toLocaleString('ru-RU', {
        day: '2-digit', month: '2-digit', year: '2-digit', hour: '2-digit', minute: '2-digit',
      });
    } catch { return String(iso); }
  }

  function phone(p) {
    const d = String(p || '').replace(/\D/g, '');
    if (d.length === 11 && d.startsWith('7')) {
      return `+7 (${d.slice(1, 4)}) ${d.slice(4, 7)}-${d.slice(7, 9)}-${d.slice(9)}`;
    }
    return p || '—';
  }

  function badge(status) {
    const map = {
      pending: ['b-pending', 'На проверке'],
      completed: ['b-ok', 'Одобрен'],
      rejected: ['b-danger', 'Отклонён'],
      incomplete: ['b-muted', 'Не завершён'],
      searching: ['b-pending', 'Поиск'],
      accepted: ['b-pending', 'Принят'],
      enroute: ['b-pending', 'В пути'],
      arrived: ['b-pending', 'Прибыл'],
      waiting: ['b-pending', 'Ожидает клиента'],
      started: ['b-ok', 'Поездка'],
      canceled: ['b-danger', 'Отменён'],
      online: ['b-ok', 'Онлайн'],
      offline: ['b-muted', 'Офлайн'],
      busy: ['b-pending', 'Занят'],
    };
    const [cls, label] = map[status] || ['b-muted', status || '—'];
    return `<span class="badge ${cls}">${esc(label)}</span>`;
  }

  function toast(msg, type = 'ok') {
    const el = document.createElement('div');
    el.className = `toast ${type === 'error' ? 'err' : 'ok'}`;
    el.textContent = msg;
    document.body.appendChild(el);
    setTimeout(() => el.remove(), 3200);
  }

  function loading() {
    content.innerHTML = '<div class="loading"><div class="spinner"></div>Загрузка…</div>';
  }

  function fail(err) {
    content.innerHTML = `<div class="empty"><p>${esc(err?.message || err || 'Ошибка')}</p>
      <button class="btn btn-primary btn-sm" type="button" data-retry>Обновить</button></div>`;
  }

  function openModal(title, body, footer = '', wide = false) {
    modalReturnFocus = document.activeElement;
    $('#modalTitle').textContent = title;
    $('#modalBody').innerHTML = body;
    $('#modalFooter').innerHTML = footer;
    $('#modalBg .modal').classList.toggle('wide', !!wide);
    $('#modalBg').classList.remove('hidden');
    $('#modalClose').focus();
  }
  function closeModal() {
    $('#modalBg').classList.add('hidden');
    if (modalReturnFocus?.isConnected) modalReturnFocus.focus();
    modalReturnFocus = null;
  }

  function closeMenu() {
    sidebar.classList.remove('open');
    backdrop.classList.remove('show');
    sidebar.inert = window.matchMedia('(max-width: 980px)').matches;
    $('#menuBtn').setAttribute('aria-expanded', 'false');
  }
  function openMenu() {
    sidebar.inert = false;
    sidebar.classList.add('open');
    backdrop.classList.add('show');
    $('#menuBtn').setAttribute('aria-expanded', 'true');
  }

  function showLogin() {
    navigationVersion += 1;
    stopDispatchRefresh();
    closeModal();
    closeMenu();
    AdminApi.logout();
    $('#loginScreen').classList.remove('hidden');
    $('#appShell').classList.add('hidden');
  }

  function showApp() {
    $('#loginScreen').classList.add('hidden');
    $('#appShell').classList.remove('hidden');
    renderNav();
    go('dashboard');
    refreshBadge();
  }

  function renderNav() {
    nav.innerHTML = PAGES.map((p) => {
      const active = page === p.id ? ' active' : '';
      const badgeHtml = p.badge && verifyCount > 0
        ? `<span class="nav-badge">${verifyCount}</span>` : '';
      return `<button type="button" class="nav-item${active}" data-nav="${p.id}">
        ${ICONS[p.icon] || ''}<span class="label">${esc(p.title)}</span>${badgeHtml}
      </button>`;
    }).join('');
  }

  function needsVerify(d) {
    const p = d.profile || {};
    const s = String(p.registrationStatus || d.registrationStatus || 'incomplete');
    if (s === 'pending' || s === 'rejected') return true;
    if (s === 'incomplete' && (p.docsSigned || p.hasVerificationPhotos)) return true;
    if (p.hasVerificationPhotos && s !== 'completed') return true;
    return false;
  }

  async function refreshBadge() {
    try {
      const data = await AdminApi.getDrivers('verify');
      verifyCount = (data.drivers || []).filter(needsVerify).length;
      renderNav();
    } catch (_) { /* ignore */ }
  }

  async function go(id) {
    const version = ++navigationVersion;
    AdminApi.cancelPending();
    page = id;
    stopDispatchRefresh();
    const meta = PAGES.find((p) => p.id === id);
    $('#pageTitle').textContent = meta?.title || id;
    renderNav();
    closeMenu();
    loading();
    try {
      const map = {
        dashboard: loadDashboard,
        dispatch: loadDispatch,
        verify: loadVerify,
        support: loadSupport,
        broadcasts: loadBroadcasts,
        drivers: loadDrivers,
        clients: loadClients,
        orders: loadOrders,
        finance: loadFinance,
        tariffs: loadTariffs,
        promos: loadPromos,
        audit: loadAudit,
        settings: loadSettings,
      };
      await (map[id] || loadDashboard)();
      if (version !== navigationVersion) return;
      if (id === 'dispatch') startDispatchRefresh();
    } catch (e) {
      if (version !== navigationVersion || e.message === 'REQUEST_CANCELLED') return;
      if (e.message === 'AUTH_EXPIRED') { showLogin(); return; }
      fail(e);
    }
  }

  function chart(labels, seriesList) {
    const series = Array.isArray(seriesList) ? seriesList : [];
    if (!labels?.length) {
      return '<div class="empty">Нет данных для графика — появятся после реальных заказов</div>';
    }
    const colors = ['var(--gold)', 'var(--purple)', 'var(--ok)', 'var(--danger)'];
    const max = Math.max(1, ...series.flatMap((s) => (s.values || []).map(Number)));
    const legend = series.map((s, i) =>
      `<span class="legend-item"><i style="background:${colors[i % colors.length]}"></i>${esc(s.name || `Серия ${i + 1}`)}</span>`
    ).join('');

    const cols = labels.map((label, i) => {
      const bars = series.map((s, si) => {
        const v = Number(s.values?.[i] || 0);
        const h = Math.max(v > 0 ? 6 : 2, Math.round((v / max) * 140));
        return `<div class="chart-bar" style="height:${h}px;background:${colors[si % colors.length]}" title="${esc(s.name)}: ${v}"></div>`;
      }).join('');
      return `<div class="chart-col"><div class="chart-stack">${bars}</div><div class="chart-lbl">${esc(label)}</div></div>`;
    }).join('');

    return `<div class="chart-legend">${legend}</div><div class="chart">${cols}</div>`;
  }

  function renderCancelReasonStats(data) {
    const items = (data?.items || []).slice(0, 6);
    if (!items.length) {
      return '<div class="empty">Отмен с причиной пока нет</div>';
    }
    return `<div class="cancel-reasons">${items.map((item) => `
      <div class="cancel-reason-row">
        <div>
          <strong>${esc(item.label)}</strong>
          <div class="dim">Клиент: ${Number(item.client || 0)} · Админ: ${Number(item.admin || 0)} · Система: ${Number(item.system || 0)}</div>
        </div>
        <span class="badge b-danger">${Number(item.count || 0)}</span>
      </div>`).join('')}</div>`;
  }

  async function loadDashboard() {
    const [company, ordersMode, driversData, ordersData, activeBc, cancelReasons] = await Promise.all([
      AdminApi.getStats('day', 'company'),
      AdminApi.getStats('day', 'orders').catch(() => null),
      AdminApi.getDrivers('manage').catch(() => ({ drivers: [] })),
      AdminApi.getOrders({ limit: '50' }).catch(() => ({ orders: [] })),
      AdminApi.getActiveBroadcasts('all').catch(() => ({ broadcasts: [] })),
      AdminApi.getCancelReasonStats().catch(() => ({ items: [] })),
    ]);
    const list = company.list || [];
    const convList = ordersMode?.list || [];
    const drivers = driversData.drivers || [];
    const online = drivers.filter((d) => d.status === 'online' && !d.blocked).length;
    const pending = drivers.filter(needsVerify).length;
    const orders = ordersData.orders || [];
    const broadcasts = activeBc.broadcasts || [];
    const hasMetrics = list.length > 0 || convList.length > 0;

    const metricByKey = (arr, ...keys) => {
      for (const k of keys) {
        const found = (arr || []).find((x) => String(x.k || '').toLowerCase().includes(k));
        if (found) return found.v;
      }
      return null;
    };

    const gmv = metricByKey(list, 'доход', 'gmv', 'revenue') || '0 ₽';
    const trips = metricByKey(list, 'заказ') || metricByKey(convList, 'заверш') || '0';
    const cancels = metricByKey(list, 'отмен') || metricByKey(convList, 'отмен') || '0';
    const conversion = metricByKey(convList, 'конверс') || '—';
    const avgCheck = metricByKey(list, 'средн') || '—';

    const primaryCards = [
      { k: 'GMV / Доход', v: gmv, hint: hasMetrics ? 'из API статистики' : 'нет данных за период' },
      { k: 'Поездки / заказы', v: trips, hint: 'за выбранный период' },
      { k: 'Отмены', v: cancels, hint: 'доля или число' },
      { k: 'Конверсия поиска', v: conversion, hint: 'завершено / всего' },
    ];

    content.innerHTML = `
      <div class="page-head">
        <div><h1>Дашборд</h1><p>Живые метрики с сервера · источник: ${esc(company.source || 'api')}</p></div>
        <button class="btn btn-ghost btn-sm" type="button" data-retry>Обновить</button>
      </div>
      <div class="stats metrics-primary" id="dashPrimary">
        ${primaryCards.map((x) => `<div class="stat">
          <div class="k">${esc(x.k)}</div>
          <div class="v">${esc(x.v)}</div>
          <div class="stat-hint">${esc(x.hint)}</div>
        </div>`).join('')}
      </div>
      ${!hasMetrics ? `<div class="empty-soft">Метрик за период пока нет — карточки показывают нули, а не «скоро». Данные появятся после реальных заказов.</div>` : ''}
      <div class="stats">
        <div class="stat"><div class="k">Средний чек</div><div class="v">${esc(avgCheck)}</div></div>
        <div class="stat"><div class="k">Водители онлайн</div><div class="v">${online}</div></div>
        <div class="stat"><div class="k">На проверке</div><div class="v">${pending}</div></div>
        <div class="stat"><div class="k">Активные уведомления</div><div class="v">${broadcasts.length}</div></div>
      </div>
      ${broadcasts.length ? `<div class="card"><div class="card-h">Активные уведомления в приложениях</div><div class="card-b">
        ${broadcasts.slice(0, 3).map((b) => `<div class="m-card" style="margin-bottom:8px">
          <div class="m-row"><span class="k">${esc(b.type)}</span><span class="v"><b>${esc(b.title)}</b></span></div>
          <div class="m-row"><span class="k">Аудитория</span><span class="v">${esc(b.audience)}</span></div>
          <div style="color:var(--muted);font-size:0.88rem;margin-top:6px">${esc(b.body)}</div>
        </div>`).join('')}
      </div></div>` : ''}
      <div class="tabs" id="dashTabs">
        <button class="tab active" data-p="day" data-m="company">Неделя · GMV</button>
        <button class="tab" data-p="month" data-m="company">6 месяцев</button>
        <button class="tab" data-p="hour" data-m="orders">24 часа</button>
        <button class="tab" data-p="day" data-m="orders">Заказы / конверсия</button>
        <button class="tab" data-p="day" data-m="drivers">Водители</button>
      </div>
      <div class="card">
        <div class="card-h"><span id="dashTitle">${esc(company.title || 'График')}</span></div>
        <div class="card-b" id="dashChart">${chart(company.labels || [], company.series || [])}</div>
      </div>
      <div class="card">
        <div class="card-h">Причины отмен</div>
        <div class="card-b">${renderCancelReasonStats(cancelReasons)}</div>
      </div>
      <div class="card">
        <div class="card-h">Последние заказы</div>
        <div class="card-b">
          ${orders.length ? `<div class="table-wrap desk"><table class="tbl"><thead><tr>
            <th>Маршрут</th><th>Статус</th><th>Цена</th><th>Дата</th><th></th>
          </tr></thead><tbody>
            ${orders.slice(0, 8).map((o) => `<tr>
              <td>${esc(o.fromAddress || '—')} → ${esc(o.toAddress || '—')}</td>
              <td>${badge(o.status)}</td>
              <td>${money(o.priceFinal || o.priceFrom)}</td>
              <td>${date(o.createdAt)}</td>
              <td class="actions"><button class="btn btn-ghost btn-sm" type="button" data-order="${esc(o.id)}">Детали</button></td>
            </tr>`).join('')}
          </tbody></table></div>
          <div class="cards">${orders.slice(0, 5).map((o) => `<div class="m-card">
            <div class="m-row"><span class="k">Маршрут</span><span class="v">${esc(o.fromAddress)} → ${esc(o.toAddress)}</span></div>
            <div class="m-row"><span class="k">Статус</span><span class="v">${badge(o.status)}</span></div>
          </div>`).join('')}</div>` : '<div class="empty">Заказов пока нет — метрики заполнятся после первых поездок</div>'}
        </div>
      </div>`;
  }

  function renderDriverMap(drivers) {
    const withLoc = drivers.filter((d) => d.location?.lat != null && d.location?.lng != null);
    if (!withLoc.length) {
      // Placeholder polished grid when no GPS
      const cells = drivers.slice(0, 12).map((d) => {
        const name = (d.profile || {}).fullName || phone(d.phone);
        const st = d.blocked ? 'rejected' : (d.status || 'offline');
        return `<div class="map-pin-card">
          <div class="map-pin-dot ${st === 'online' ? 'on' : st === 'busy' ? 'busy' : ''}"></div>
          <div class="map-pin-meta">
            <strong>${esc(name)}</strong>
            <span>${badge(st)}</span>
            <span class="dim">GPS недоступен</span>
          </div>
        </div>`;
      }).join('') || '<div class="empty">Нет водителей онлайн</div>';
      return `<div class="map-placeholder">
        <div class="map-grid-bg"></div>
        <div class="map-placeholder-banner">Живая карта появится, когда у водителей будет GPS. Список статусов ниже.</div>
        <div class="map-pin-list">${cells}</div>
      </div>`;
    }

    const lats = withLoc.map((d) => Number(d.location.lat));
    const lngs = withLoc.map((d) => Number(d.location.lng));
    const minLat = Math.min(...lats);
    const maxLat = Math.max(...lats);
    const minLng = Math.min(...lngs);
    const maxLng = Math.max(...lngs);
    const pad = 0.01;
    const dLat = Math.max(maxLat - minLat, pad * 2);
    const dLng = Math.max(maxLng - minLng, pad * 2);

    const markers = withLoc.map((d) => {
      const x = ((Number(d.location.lng) - minLng + pad) / (dLng + pad * 2)) * 100;
      const y = (1 - (Number(d.location.lat) - minLat + pad) / (dLat + pad * 2)) * 100;
      const name = (d.profile || {}).fullName || phone(d.phone);
      const st = d.status || 'offline';
      const cls = st === 'online' ? 'on' : st === 'busy' ? 'busy' : '';
      return `<div class="map-marker ${cls}" style="left:${x.toFixed(2)}%;top:${y.toFixed(2)}%" title="${esc(name)}">
        <span class="map-marker-dot"></span>
        <span class="map-marker-label">${esc(String(name).slice(0, 18))}</span>
      </div>`;
    }).join('');

    const coordsList = withLoc.map((d) => {
      const name = (d.profile || {}).fullName || phone(d.phone);
      return `<div class="map-coord-row">
        <span>${esc(name)}</span>
        <span class="mono">${Number(d.location.lat).toFixed(5)}, ${Number(d.location.lng).toFixed(5)}</span>
      </div>`;
    }).join('');

    return `<div class="map-stage">
      <div class="map-canvas">${markers}<div class="map-crosshair"></div></div>
      <div class="map-coords">${coordsList}</div>
    </div>`;
  }

  function dispatchOrderHtml(o) {
    const canAssign = o.status === 'searching' || (o.status === 'accepted' && !o.driverPhone);
    return `<div class="dispatch-order">
      <div class="dispatch-order-top">
        <div>
          <div class="route">${esc(o.fromAddress || '—')} → ${esc(o.toAddress || '—')}</div>
          <div class="meta">${esc(o.clientName || o.clientPhone || 'Клиент')} · ${money(o.priceFinal || o.priceFrom)} · ${date(o.createdAt)}</div>
        </div>
        ${badge(o.status)}
      </div>
      <div class="dispatch-order-actions">
        <button class="btn btn-ghost btn-sm" type="button" data-order="${esc(o.id)}">Детали</button>
        ${canAssign ? `<button class="btn btn-primary btn-sm" type="button" data-assign="${esc(o.id)}">Назначить</button>` : ''}
        ${o.status !== 'canceled' && o.status !== 'completed'
          ? `<button class="btn btn-danger btn-sm" type="button" data-cancel="${esc(o.id)}" data-cancel-goto="dispatch">Отменить</button>` : ''}
        ${o.driverPhone ? `<span class="dim">Водитель: ${phone(o.driverPhone)}</span>` : ''}
      </div>
    </div>`;
  }

  async function loadDispatch(opts = {}) {
    const [ordersData, driversData] = await Promise.all([
      AdminApi.getOrders({ active: '1', limit: '100' }),
      AdminApi.getDrivers('dispatch', { includeLocation: true }),
    ]);
    if (page !== 'dispatch' || !AdminApi.isLoggedIn()) return;
    const orders = (ordersData.orders || []).filter((o) =>
      ['searching', 'accepted', 'enroute', 'arrived', 'waiting', 'started'].includes(o.status));
    const live = orders.filter((o) => o.status === 'searching' || o.status === 'accepted'
      || o.status === 'enroute' || o.status === 'arrived' || o.status === 'waiting' || o.status === 'started');
    const drivers = driversData.drivers || [];
    dispatchDriversCache = drivers.filter((d) => !d.blocked && (d.status === 'online' || d.status === 'busy'));
    const online = dispatchDriversCache;

    dispatchOrdersCache = live;

    if (opts.silent && page === 'dispatch' && content.querySelector('#dispatchOrders')) {
      const values = content.querySelectorAll('.stats .stat .v');
      const counts = [live.length, live.filter(o => o.status === 'searching').length,
        `${online.filter(d => d.status === 'online').length} / ${online.filter(d => d.status === 'busy').length}`,
        online.filter(d => d.location?.lat != null).length];
      values.forEach((element, index) => { element.textContent = counts[index]; });
      const driverList = $('#dispatchDrivers');
      if (driverList) driverList.innerHTML = renderDispatchDrivers(online);
      const stamp = new Date().toLocaleTimeString('ru-RU', { hour: '2-digit', minute: '2-digit', second: '2-digit' });
      const liveEl = $('#dispatchLiveStamp');
      if (liveEl) liveEl.textContent = `Обновлено ${stamp}`;
      const ordersBox = $('#dispatchOrders');
      if (ordersBox) {
        ordersBox.innerHTML = live.length ? live.map((o) => dispatchOrderHtml(o)).join('')
          : '<div class="empty">Нет активных заказов</div>';
      }
      await mountDispatchMap(dispatchDriversCache, live);
      return;
    }

    content.innerHTML = `
      <div class="page-head">
        <div>
          <h1>Диспетчерская</h1>
          <p>Живые заказы и водители · автообновление каждые 15 с</p>
          <p class="dim" id="dispatchLiveStamp">Обновлено ${date(new Date().toISOString())}</p>
        </div>
        <button class="btn btn-ghost btn-sm" type="button" data-retry>Обновить</button>
      </div>
      <div class="stats">
        <div class="stat"><div class="k">Активных заказов</div><div class="v">${live.length}</div></div>
        <div class="stat"><div class="k">Поиск водителя</div><div class="v">${live.filter((o) => o.status === 'searching').length}</div></div>
        <div class="stat"><div class="k">Онлайн / заняты</div><div class="v">${online.filter((d) => d.status === 'online').length} / ${online.filter((d) => d.status === 'busy').length}</div></div>
        <div class="stat"><div class="k">С GPS</div><div class="v">${online.filter((d) => d.location?.lat != null).length}</div></div>
      </div>
      <div class="dispatch-grid">
        <div class="card">
          <div class="card-h">Живые заказы</div>
          <div class="card-b" id="dispatchOrders">
            ${live.length ? live.map((o) => dispatchOrderHtml(o)).join('') : '<div class="empty">Нет активных заказов</div>'}
          </div>
        </div>
        <div class="card">
          <div class="card-h">Водители онлайн</div>
          <div class="card-b" id="dispatchDrivers">
            ${renderDispatchDrivers(online)}
          </div>
        </div>
      </div>
      <div class="card">
        <div class="card-h"><span id="dispatchMapLabel">Карта</span></div>
        <div class="card-b">
          <div id="dispatchMapHost" class="map-yandex-host"></div>
          <p class="dim map-legend">Зелёный — свободен · Оранжевый — занят · Фиолетовый — подача заказа · без ключа Яндекса используется OpenStreetMap</p>
        </div>
      </div>`;

    await mountDispatchMap(online, live);
  }

  function renderDispatchDrivers(drivers) {
    return drivers.length ? drivers.map(driver => {
      const loc = driver.location;
      return `<div class="driver-online-row"><div>
        <strong>${esc(driver.profile?.fullName || 'Водитель')}</strong>
        <div class="dim">${phone(driver.phone)}</div>
        <div class="dim">${loc?.lat != null
          ? `${Number(loc.lat).toFixed(5)}, ${Number(loc.lng).toFixed(5)} · ${date(loc.recordedAt || loc.updatedAt)}`
          : 'Без координат'}</div></div>${badge(driver.status || 'offline')}</div>`;
    }).join('') : '<div class="empty">Нет водителей онлайн</div>';
  }

  function extractOrderIds(text) {
    const src = String(text || '');
    const ids = new Set();
    const uuid = src.match(/[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/gi) || [];
    uuid.forEach((id) => ids.add(id));
    const tagged = src.match(/(?:заказ|order)[\s#:№-]*([A-Za-z0-9_-]{8,})/gi) || [];
    tagged.forEach((m) => {
      const parts = m.split(/[\s#:№-]+/);
      const last = parts[parts.length - 1];
      if (last && last.length >= 8) ids.add(last);
    });
    return [...ids];
  }

  async function loadSupport() {
    const data = await AdminApi.getSupportTickets();
    const tickets = data.tickets || [];
    supportCache = tickets;
    const openCount = tickets.filter((t) => t.status !== 'closed').length;

    content.innerHTML = `
      <div class="page-head">
        <div>
          <h1>Поддержка</h1>
          <p>${openCount} открытых · ${tickets.length} всего</p>
        </div>
        <button class="btn btn-ghost btn-sm" type="button" data-retry>Обновить</button>
      </div>
      <div class="card desk"><div class="table-wrap">
        <table class="tbl"><thead><tr>
          <th>Тема</th><th>От кого</th><th>Заказ</th><th>Статус</th><th>Обновлено</th><th></th>
        </tr></thead><tbody>
          ${tickets.map((t) => {
            const orderIds = extractOrderIds(`${t.subject || ''} ${t.body || ''} ${(t.messages || []).map((m) => m.body).join(' ')}`);
            const oid = t.orderId || orderIds[0] || '';
            return `<tr>
            <td><b>${esc(t.subject)}</b><div class="dim" style="margin-top:4px;max-width:320px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${esc(t.body)}</div></td>
            <td>${esc(t.authorRole)} · ${phone(t.authorPhone)}${t.authorName ? `<div class="dim">${esc(t.authorName)}</div>` : ''}</td>
            <td>${oid ? `<button class="btn btn-ghost btn-sm" type="button" data-order="${esc(oid)}">${esc(String(oid).slice(0, 8))}…</button>` : '<span class="dim">—</span>'}</td>
            <td>${badge(t.status === 'open' ? 'pending' : t.status === 'replied' ? 'accepted' : 'canceled').replace('Поиск', 'Открыт').replace('Принят', 'Ответ').replace('Отменён', 'Закрыт')}</td>
            <td>${date(t.updatedAt)}</td>
            <td class="actions"><button class="btn btn-ghost btn-sm" data-ticket="${esc(t.id)}">Открыть</button></td>
          </tr>`;
          }).join('') || '<tr><td colspan="6">Тикетов пока нет</td></tr>'}
        </tbody></table>
      </div></div>
      <div class="cards">${tickets.map((t) => {
        const orderIds = extractOrderIds(`${t.subject || ''} ${t.body || ''}`);
        const oid = t.orderId || orderIds[0] || '';
        return `<div class="m-card">
        <div class="m-row"><span class="k">Тема</span><span class="v"><b>${esc(t.subject)}</b></span></div>
        <div class="m-row"><span class="k">От</span><span class="v">${esc(t.authorRole)} · ${phone(t.authorPhone)}</span></div>
        <div class="m-row"><span class="k">Статус</span><span class="v">${esc(t.status)}</span></div>
        <div class="m-actions">
          <button class="btn btn-ghost btn-sm" data-ticket="${esc(t.id)}">Открыть</button>
          ${oid ? `<button class="btn btn-primary btn-sm" type="button" data-order="${esc(oid)}">Заказ</button>` : ''}
        </div>
      </div>`;
      }).join('') || '<div class="empty">Тикетов пока нет</div>'}</div>`;
  }

  function openTicket(ticket) {
    const orderIds = extractOrderIds(`${ticket.subject || ''} ${ticket.body || ''} ${(ticket.messages || []).map((m) => m.body).join(' ')}`);
    if (ticket.orderId) orderIds.unshift(ticket.orderId);
    const uniqueOrders = [...new Set(orderIds)];
    const msgs = (ticket.messages || []).map((m) => `
      <div class="ticket-msg ${m.from === 'admin' ? 'admin' : 'user'}">
        <div class="ticket-msg-h">${m.from === 'admin' ? 'Поддержка' : 'Пользователь'} · ${date(m.createdAt)}</div>
        <div class="ticket-msg-b">${esc(m.body)}</div>
      </div>`).join('') || '<div class="empty">Нет сообщений</div>';

    openModal(`Тикет — ${ticket.subject}`, `
      <div class="ticket-meta">
        <div>${esc(ticket.authorRole)} · ${phone(ticket.authorPhone)}${ticket.authorName ? ` · ${esc(ticket.authorName)}` : ''}</div>
        <div class="dim">${esc(ticket.status)} · создан ${date(ticket.createdAt)}</div>
        ${uniqueOrders.length ? `<div class="ticket-orders">Связанные заказы: ${uniqueOrders.map((id) =>
          `<button class="btn btn-ghost btn-sm" type="button" data-order="${esc(id)}">${esc(String(id).slice(0, 10))}…</button>`).join(' ')}</div>` : ''}
      </div>
      <div class="ticket-thread">${msgs}</div>
      ${ticket.status !== 'closed' ? `
        <div class="field" style="margin-top:14px">
          <label>Ответ</label>
          <textarea id="ticketReply" rows="3" placeholder="Текст ответа…"></textarea>
        </div>` : '<div class="dim" style="margin-top:12px">Тикет закрыт</div>'}
    `, ticket.status !== 'closed'
      ? `<button class="btn btn-primary btn-sm" type="button" id="ticketSend">Ответить</button>
         <button class="btn btn-danger btn-sm" type="button" id="ticketClose">Закрыть</button>`
      : '');

    const send = $('#ticketSend');
    const closeBtn = $('#ticketClose');
    if (send) {
      send.onclick = async () => {
        const text = ($('#ticketReply')?.value || '').trim();
        if (!text) return toast('Введите ответ', 'error');
        try {
          await AdminApi.replySupportTicket(ticket.id, text);
          pushLocalAudit('support.reply', ticket.id, text.slice(0, 80));
          toast('Ответ отправлен');
          closeModal();
          go('support');
        } catch (e) { toast(e.message, 'error'); }
      };
    }
    if (closeBtn) {
      closeBtn.onclick = async () => {
        if (!confirm('Закрыть тикет?')) return;
        try {
          await AdminApi.closeSupportTicket(ticket.id);
          pushLocalAudit('support.close', ticket.id);
          toast('Тикет закрыт');
          closeModal();
          go('support');
        } catch (e) { toast(e.message, 'error'); }
      };
    }
  }

  async function loadBroadcasts() {
    const data = await AdminApi.getBroadcasts();
    const list = data.broadcasts || [];
    content.innerHTML = `
      <div class="page-head">
        <div>
          <h1>Уведомления</h1>
          <p>Техработы, обновления и новости — сразу в приложениях клиентов и водителей</p>
        </div>
        <button class="btn btn-gold btn-sm" type="button" id="addBroadcast">Отправить</button>
      </div>
      <div class="card"><div class="card-b">
        ${list.length ? list.map((b) => `
          <div class="m-card" style="margin-bottom:10px">
            <div class="m-row"><span class="k">Тип</span><span class="v">${badge(b.type === 'maintenance' ? 'pending' : b.type === 'alert' ? 'canceled' : 'completed')} ${esc(b.type)}</span></div>
            <div class="m-row"><span class="k">Заголовок</span><span class="v"><b>${esc(b.title)}</b></span></div>
            <div class="m-row"><span class="k">Кому</span><span class="v">${esc(b.audience)}</span></div>
            <div class="m-row"><span class="k">Статус</span><span class="v">${b.active ? badge('completed').replace('Одобрен', 'Активно') : badge('incomplete').replace('Не завершён', 'Выкл')}</span></div>
            <div class="m-row"><span class="k">Создано</span><span class="v">${date(b.createdAt)}</span></div>
            <div style="margin-top:8px;color:var(--muted);font-size:0.9rem;white-space:pre-wrap">${esc(b.body)}</div>
            <div class="m-actions">
              ${b.active ? `<button class="btn btn-ghost btn-sm" data-bc-off="${esc(b.id)}">Выключить</button>` : ''}
              <button class="btn btn-danger btn-sm" data-bc-del="${esc(b.id)}">Удалить</button>
            </div>
          </div>`).join('') : '<div class="empty">Пока нет объявлений. Нажмите «Отправить», чтобы разослать техработы или новость в приложения.</div>'}
      </div></div>`;

    $('#addBroadcast').onclick = () => {
      openModal('Новое уведомление', `
        <div class="field"><label>Заголовок</label><input id="bcTitle" placeholder="Технические работы" /></div>
        <div class="field"><label>Текст</label><textarea id="bcBody" rows="4" placeholder="Сегодня с 02:00 до 04:00 сервис может быть недоступен"></textarea></div>
        <div class="field"><label>Тип</label>
          <select id="bcType">
            <option value="maintenance">Техработы</option>
            <option value="update">Обновление</option>
            <option value="news">Новость</option>
            <option value="alert">Важно</option>
          </select>
        </div>
        <div class="field"><label>Кому</label>
          <select id="bcAudience">
            <option value="all">Всем</option>
            <option value="clients">Клиентам</option>
            <option value="drivers">Водителям</option>
          </select>
        </div>
        <div class="field"><label>Действует до (необязательно)</label><input id="bcEnds" type="datetime-local" /></div>
      `, `<button class="btn btn-gold" type="button" id="bcSend">Отправить в приложения</button>`);

      $('#bcSend').onclick = async () => {
        const title = $('#bcTitle').value.trim();
        const body = $('#bcBody').value.trim();
        if (!title || !body) return toast('Заполните заголовок и текст', 'error');
        const endsRaw = $('#bcEnds').value;
        try {
          await AdminApi.createBroadcast({
            title,
            body,
            type: $('#bcType').value,
            audience: $('#bcAudience').value,
            endsAt: endsRaw ? new Date(endsRaw).toISOString() : null,
            pushLive: true,
            active: true,
          });
          toast('Уведомление отправлено в приложения');
          closeModal();
          go('broadcasts');
        } catch (e) { toast(e.message, 'error'); }
      };
    };
  }

  async function loadVerify() {
    const data = await AdminApi.getDrivers('verify');
    let drivers = data.drivers || [];
    const pending = drivers.filter(needsVerify);
    const list = pending;

    if (!list.length) {
      content.innerHTML = `<div class="page-head"><div><h1>Проверка</h1><p>KYC документов водителей</p></div>
        <button class="btn btn-ghost btn-sm" type="button" data-retry>Обновить</button></div>
        <div class="empty">Нет водителей на проверке</div>`;
      verifyCount = 0;
      renderNav();
      return;
    }

    verifyCount = pending.length;
    renderNav();

    content.innerHTML = `
      <div class="page-head">
        <div>
          <h1>Проверка</h1>
          <p>${pending.length ? `${pending.length} заявок ожидают решения` : `Показаны все водители (${list.length})`}</p>
        </div>
        <button class="btn btn-ghost btn-sm" type="button" data-retry>Обновить</button>
      </div>
      <div class="verify-grid" id="verifyGrid"></div>`;

    const grid = $('#verifyGrid');
    for (const d of list) {
      const p = d.profile || {};
      const status = p.registrationStatus || d.registrationStatus || 'incomplete';
      const card = document.createElement('div');
      card.className = 'v-card';
      card.innerHTML = `
        <div class="v-head">
          <h3>${esc(p.fullName || 'Без имени')}</h3>
          <div class="sub">${phone(d.phone)}</div>
          <div style="margin-top:8px">${badge(status)}</div>
        </div>
        <div class="v-meta">
          <div>ИНН: ${esc(p.inn || '—')}</div>
          <div>Паспорт: ${esc(p.passport || '—')}</div>
          <div>Авто: ${esc(p.carModel || '—')} · ${esc(p.carColor || '—')}</div>
          <div>Госномер: ${esc(p.carPlate || '—')}</div>
          <div>Тарифы: ${esc((p.servedClasses || []).join(', ') || '—')}</div>
          <div>Документы: ${p.docsSigned ? 'подписаны' : 'не подписаны'}</div>
          <div>Фото: ${p.hasVerificationPhotos ? 'есть' : 'нет'}</div>
        </div>
        <div class="photos" data-photos="${esc(d.phone)}">
          <div class="photo"><div class="ph">Загрузка…</div></div>
        </div>
        <div class="v-actions">
          <button class="btn btn-ok btn-sm" type="button" data-approve="${esc(d.phone)}">Одобрить</button>
          <button class="btn btn-danger btn-sm" type="button" data-reject="${esc(d.phone)}">Отклонить</button>
          ${status !== 'pending'
            ? `<button class="btn btn-ghost btn-sm" type="button" data-force-pending="${esc(d.phone)}">В pending</button>`
            : ''}
        </div>`;
      grid.appendChild(card);
      fillPhotos(d.phone, card.querySelector('[data-photos]'));
    }
  }

  function openPhotoViewer(items, startIdx = 0) {
    photoLightbox = items.filter((x) => x.src);
    photoLightboxIdx = Math.max(0, Math.min(startIdx, photoLightbox.length - 1));
    if (!photoLightbox.length) return;

    const paint = () => {
      const cur = photoLightbox[photoLightboxIdx];
      $('#modalTitle').textContent = `${cur.label} (${photoLightboxIdx + 1}/${photoLightbox.length})`;
      $('#modalBody').innerHTML = `
        <div class="lightbox">
          <img src="${cur.src}" alt="${esc(cur.label)}" />
        </div>`;
      $('#modalFooter').innerHTML = `
        <button class="btn btn-ghost btn-sm" type="button" id="lbPrev" ${photoLightboxIdx <= 0 ? 'disabled' : ''}>Назад</button>
        <button class="btn btn-ghost btn-sm" type="button" id="lbNext" ${photoLightboxIdx >= photoLightbox.length - 1 ? 'disabled' : ''}>Далее</button>`;
      const prev = $('#lbPrev');
      const next = $('#lbNext');
      if (prev) prev.onclick = () => { if (photoLightboxIdx > 0) { photoLightboxIdx -= 1; paint(); } };
      if (next) next.onclick = () => { if (photoLightboxIdx < photoLightbox.length - 1) { photoLightboxIdx += 1; paint(); } };
    };
    $('#modalBg').classList.remove('hidden');
    $('#modalBg .modal').classList.add('wide');
    paint();
  }

  async function fillPhotos(phoneNum, box) {
    if (!box) return;
    try {
      const data = await AdminApi.getDriverPhotos(phoneNum);
      const photos = data.photos || {};
      const items = [
        ['passportFrontBase64', 'Паспорт'],
        ['passportRegBase64', 'ВУ спереди'],
        ['driverLicenseBackBase64', 'ВУ сзади'],
        ['selfieBase64', 'Селфи'],
        ['carPhotoBase64', 'Автомобиль'],
        ['stsBase64', 'СТС'],
        ['osagoBase64', 'ОСАГО'],
        ['signatureBase64', 'Подпись'],
      ];
      const gallery = [];
      box.innerHTML = items.map(([key, label], idx) => {
        const raw = photos[key];
        if (raw && String(raw).length > 40) {
          const src = String(raw).startsWith('data:') ? raw : `data:image/jpeg;base64,${raw}`;
          gallery.push({ label, src });
          return `<div class="photo" data-lightbox="${gallery.length - 1}" data-phone-photos="${esc(phoneNum)}">
            <img src="${src}" alt="${esc(label)}" loading="lazy" />
            <div class="cap">${esc(label)}</div>
          </div>`;
        }
        return `<div class="photo"><div class="ph">${esc(label)}<br>нет фото</div></div>`;
      }).join('');
      box._gallery = gallery;
    } catch {
      box.innerHTML = '<div class="photo"><div class="ph">Ошибка загрузки фото</div></div>';
    }
  }

  async function loadDrivers() {
    const data = await AdminApi.getDrivers('manage');
    const drivers = data.drivers || [];
    content.innerHTML = `
      <div class="page-head"><div><h1>Водители</h1><p>Всего: ${drivers.length}</p></div></div>
      <div class="toolbar"><div class="field grow"><input id="driverQ" placeholder="Поиск по имени или телефону" /></div></div>
      <div class="card desk"><div class="table-wrap">
        <table class="tbl"><thead><tr>
          <th>Имя</th><th>Телефон</th><th>Онлайн</th><th>Регистрация</th><th></th>
        </tr></thead><tbody id="driversBody"></tbody></table>
      </div></div>
      <div class="cards" id="driversCards"></div>`;

    const paint = (list) => {
      $('#driversBody').innerHTML = list.map((d) => {
        const p = d.profile || {};
        return `<tr>
          <td>${esc(p.fullName || '—')}</td>
          <td>${phone(d.phone)}</td>
          <td>${badge(d.blocked ? 'rejected' : (d.status || 'offline'))}</td>
          <td>${badge(p.registrationStatus || 'incomplete')}</td>
          <td class="actions">
            ${d.blocked
              ? `<button class="btn btn-ok btn-sm" data-unblock="${esc(d.phone)}">Разблок.</button>`
              : `<button class="btn btn-danger btn-sm" data-block="${esc(d.phone)}">Блок</button>`}
            <button class="btn btn-ghost btn-sm" data-docs="${esc(d.phone)}">Документы</button>
          </td>
        </tr>`;
      }).join('') || '<tr><td colspan="5">Нет водителей</td></tr>';

      $('#driversCards').innerHTML = list.map((d) => {
        const p = d.profile || {};
        return `<div class="m-card">
          <div class="m-row"><span class="k">Имя</span><span class="v">${esc(p.fullName || '—')}</span></div>
          <div class="m-row"><span class="k">Телефон</span><span class="v">${phone(d.phone)}</span></div>
          <div class="m-row"><span class="k">Регистрация</span><span class="v">${badge(p.registrationStatus || 'incomplete')}</span></div>
          <div class="m-actions">
            ${d.blocked
              ? `<button class="btn btn-ok btn-sm" data-unblock="${esc(d.phone)}">Разблокировать</button>`
              : `<button class="btn btn-danger btn-sm" data-block="${esc(d.phone)}">Заблокировать</button>`}
            <button class="btn btn-ghost btn-sm" data-docs="${esc(d.phone)}">Документы</button>
          </div>
        </div>`;
      }).join('') || '<div class="empty">Нет водителей</div>';
    };

    paint(drivers);
    $('#driverQ').addEventListener('input', (e) => {
      const q = e.target.value.toLowerCase();
      paint(drivers.filter((d) => {
        const p = d.profile || {};
        return String(p.fullName || '').toLowerCase().includes(q) || String(d.phone || '').includes(q);
      }));
    });
  }

  async function loadClients() {
    const data = await AdminApi.getClients();
    const clients = data.clients || [];
    clientsCache = clients;
    const avatarSrc = (client) => {
      const raw = client.avatarBase64 || client.profile?.avatarBase64 || '';
      if (!raw) return '';
      return String(raw).startsWith('data:')
        ? String(raw)
        : `data:image/jpeg;base64,${String(raw)}`;
    };
    const avatarHtml = (client) => {
      const src = avatarSrc(client);
      return src
        ? `<img class="client-avatar" src="${esc(src)}" alt="" loading="lazy" />`
        : `<span class="client-avatar client-avatar-empty">${esc(String(client.fullName || client.name || '?').slice(0, 1))}</span>`;
    };
    content.innerHTML = `
      <div class="page-head"><div><h1>Клиенты</h1><p>${clients.length} клиентов</p></div></div>
      <div class="toolbar"><div class="field grow"><input id="clientQ" placeholder="Поиск по имени или телефону" /></div></div>
      <div class="card desk"><div class="table-wrap">
        <table class="tbl"><thead><tr><th>Фото</th><th>ID</th><th>Имя</th><th>Телефон</th><th>Заказов</th><th>Статус</th><th></th></tr></thead>
        <tbody id="clientsBody"></tbody></table>
      </div></div>
      <div class="cards" id="clientsCards"></div>`;

    const paint = (list) => {
      $('#clientsBody').innerHTML = list.map((c) => `<tr>
        <td>${avatarHtml(c)}</td>
        <td class="mono">${esc(c.id)}</td>
        <td>${esc(c.fullName || c.name || '—')}</td>
        <td>${phone(c.phone || c.id)}</td>
        <td>${c.ordersCount ?? c.orderCount ?? '—'}</td>
        <td>${c.blocked ? badge('rejected').replace('Отклонён', 'Блок') : badge('online').replace('Онлайн', 'Активен')}</td>
        <td class="actions">
          <button class="btn btn-ghost btn-sm" data-client="${esc(c.id)}">Профиль</button>
          ${c.blocked
            ? `<button class="btn btn-ok btn-sm" data-cunblock="${esc(c.id)}">Разблок.</button>`
            : `<button class="btn btn-danger btn-sm" data-cblock="${esc(c.id)}">Блок</button>`}
        </td>
      </tr>`).join('') || '<tr><td colspan="7">Нет клиентов</td></tr>';

      $('#clientsCards').innerHTML = list.map((c) => `<div class="m-card">
        <div class="m-row"><span class="k">Профиль</span><span class="v">${avatarHtml(c)} ${esc(c.fullName || '—')}</span></div>
        <div class="m-row"><span class="k">Телефон</span><span class="v">${phone(c.phone || c.id)}</span></div>
        <div class="m-row"><span class="k">Заказов</span><span class="v">${c.ordersCount ?? c.orderCount ?? '—'}</span></div>
        <div class="m-actions">
          <button class="btn btn-ghost btn-sm" data-client="${esc(c.id)}">Профиль</button>
          ${c.blocked
            ? `<button class="btn btn-ok btn-sm" data-cunblock="${esc(c.id)}">Разблокировать</button>`
            : `<button class="btn btn-danger btn-sm" data-cblock="${esc(c.id)}">Заблокировать</button>`}
        </div>
      </div>`).join('') || '<div class="empty">Нет клиентов</div>';
    };
    paint(clients);
    $('#clientQ').addEventListener('input', (e) => {
      const q = e.target.value.toLowerCase();
      paint(clients.filter((c) =>
        String(c.fullName || '').toLowerCase().includes(q) || String(c.phone || c.id).includes(q)));
    });
  }

  async function openClientProfile(clientId) {
    const cached = clientsCache.find((c) => c.id === clientId) || { id: clientId };
    openModal(`Клиент · ${phone(cached.phone || clientId)}`, '<div class="loading"><div class="spinner"></div>Загрузка…</div>', '', true);
    try {
      const [ordersData, commentData] = await Promise.all([
        AdminApi.getClientOrders(clientId, 50),
        AdminApi.getClientComment(clientId).catch(() => ({ comment: cached.adminComment || '' })),
      ]);
      const trips = ordersData.orders || [];
      const comment = commentData.comment || cached.adminComment || '';
      $('#modalBody').innerHTML = `
        <div class="order-detail-grid">
          <div class="m-card">
            <div class="m-row"><span class="k">Профиль</span><span class="v">${avatarHtml(cached)} ${esc(cached.fullName || cached.name || '—')}</span></div>
            <div class="m-row"><span class="k">Телефон</span><span class="v">${phone(cached.phone || cached.id)}</span></div>
            <div class="m-row"><span class="k">ID</span><span class="v mono">${esc(cached.id)}</span></div>
            <div class="m-row"><span class="k">Заказов</span><span class="v">${cached.ordersCount ?? cached.orderCount ?? trips.length}</span></div>
            <div class="m-row"><span class="k">Статус</span><span class="v">${cached.blocked ? badge('rejected').replace('Отклонён', 'Заблокирован') : badge('online').replace('Онлайн', 'Активен')}</span></div>
            ${cached.blockReason ? `<div class="m-row"><span class="k">Причина блока</span><span class="v">${esc(cached.blockReason)}</span></div>` : ''}
            <div class="field" style="margin-top:12px">
              <label>Комментарий админа</label>
              <textarea id="clientComment" rows="2">${esc(comment)}</textarea>
            </div>
          </div>
          <div>
            <div class="card-h" style="padding:0 0 8px">Поездки (${trips.length})</div>
            ${trips.length ? `<div class="timeline">${trips.map((o) => `
              <div class="timeline-item">
                <div class="timeline-dot"></div>
                <div class="timeline-body">
                  <div class="timeline-top">
                    <strong>${esc(o.fromAddress || '—')} → ${esc(o.toAddress || '—')}</strong>
                    <span class="dim">${date(o.createdAt)}</span>
                  </div>
                  <div class="dim">${badge(o.status)} · ${money(o.priceFinal || o.priceFrom)}</div>
                  <div class="m-actions" style="border:0;padding-top:6px;margin-top:4px">
                    <button class="btn btn-ghost btn-sm" type="button" data-order="${esc(o.id)}">Детали</button>
                  </div>
                </div>
              </div>`).join('')}</div>` : '<div class="empty">Поездок пока нет</div>'}
          </div>
        </div>`;
      $('#modalFooter').innerHTML = `
        <button class="btn btn-primary btn-sm" type="button" id="saveClientComment">Сохранить комментарий</button>
        ${cached.blocked
          ? `<button class="btn btn-ok btn-sm" type="button" data-cunblock="${esc(clientId)}" data-client-close="1">Разблокировать</button>`
          : `<button class="btn btn-danger btn-sm" type="button" data-cblock="${esc(clientId)}" data-client-close="1">Заблокировать</button>`}
        <button class="btn btn-ghost btn-sm" type="button" id="modalCloseBtn">Закрыть</button>`;
      const saveBtn = $('#saveClientComment');
      if (saveBtn) {
        saveBtn.onclick = async () => {
          try {
            await AdminApi.saveClientComment(clientId, ($('#clientComment')?.value || '').trim());
            pushLocalAudit('client.comment', clientId);
            toast('Комментарий сохранён');
          } catch (e) { toast(e.message, 'error'); }
        };
      }
      const closeBtn = $('#modalCloseBtn');
      if (closeBtn) closeBtn.onclick = closeModal;
    } catch (e) {
      $('#modalBody').innerHTML = `<div class="error-box">${esc(e.message)}</div>`;
      $('#modalFooter').innerHTML = '';
    }
  }

  async function loadOrders() {
    content.innerHTML = `
      <div class="page-head"><div><h1>Заказы</h1><p>Фильтры, детали, назначение, отмена / возврат</p></div></div>
      <div class="toolbar">
        <div class="field"><select id="orderStatus">
          <option value="">Все статусы</option>
          <option value="searching">Поиск</option>
          <option value="accepted">Принят</option>
          <option value="enroute">В пути</option>
          <option value="arrived">Прибыл</option>
          <option value="started">Поездка</option>
          <option value="completed">Завершён</option>
          <option value="canceled">Отменён</option>
        </select></div>
        <div class="field"><select id="orderPay">
          <option value="">Оплата: все</option>
          <option value="unpaid">Не оплачен</option>
          <option value="paid">Оплачен</option>
          <option value="failed">Ошибка оплаты</option>
        </select></div>
        <div class="field"><label class="chk"><input type="checkbox" id="orderActive" /> Только активные</label></div>
        <div class="field grow"><input id="orderDriver" placeholder="Телефон водителя" /></div>
        <div class="field grow"><input id="orderClient" placeholder="Телефон / ID клиента" /></div>
        <button class="btn btn-primary btn-sm" type="button" id="orderLoad">Применить</button>
      </div>
      <div class="card desk"><div class="table-wrap">
        <table class="tbl"><thead><tr>
          <th>Маршрут</th><th>Клиент</th><th>Водитель</th><th>Цена</th><th>Оплата</th><th>Статус</th><th>Дата</th><th></th>
        </tr></thead><tbody id="ordersBody"></tbody></table>
      </div></div>
      <div class="cards" id="ordersCards"></div>`;

    async function fetchAndPaint() {
      const params = {};
      const st = $('#orderStatus').value;
      const pay = $('#orderPay').value;
      const dr = $('#orderDriver').value.replace(/\D/g, '');
      const cl = ($('#orderClient').value || '').trim();
      if (st) params.status = st;
      if (pay) params.paymentStatus = pay;
      if (dr) params.driverPhone = dr;
      if (cl) params.clientId = cl.replace(/\D/g, '') || cl;
      if ($('#orderActive').checked) params.active = '1';
      const data = await AdminApi.getOrders(params);
      const orders = data.orders || [];
      $('#ordersBody').innerHTML = orders.map((o) => `<tr>
        <td>${esc(o.fromAddress || '—')} → ${esc(o.toAddress || '—')}</td>
        <td>${esc(o.clientName || o.clientPhone || o.clientId || '—')}</td>
        <td>${phone(o.driverPhone)}</td>
        <td>${money(o.priceFinal || o.priceFrom)}</td>
        <td>${esc(o.paymentStatus || '—')}</td>
        <td>${badge(o.status)}</td>
        <td>${date(o.createdAt)}</td>
        <td class="actions">
          <button class="btn btn-ghost btn-sm" type="button" data-order="${esc(o.id)}">Детали</button>
          ${(o.status === 'searching' || (o.status === 'accepted' && !o.driverPhone))
            ? `<button class="btn btn-primary btn-sm" type="button" data-assign="${esc(o.id)}">Назначить</button>` : ''}
          ${o.status !== 'canceled' && o.status !== 'completed'
            ? `<button class="btn btn-danger btn-sm" data-cancel="${esc(o.id)}">Отмена</button>` : ''}
          ${o.status === 'completed' && o.paymentStatus === 'paid'
            ? `<button class="btn btn-ghost btn-sm" data-refund="${esc(o.id)}">Возврат</button>` : ''}
          ${o.status === 'completed' && o.paymentStatus !== 'paid'
            ? `<button class="btn btn-ok btn-sm" data-pay="${esc(o.id)}">Оплачен</button>` : ''}
        </td>
      </tr>`).join('') || '<tr><td colspan="8">Нет заказов</td></tr>';

      $('#ordersCards').innerHTML = orders.map((o) => `<div class="m-card">
        <div class="m-row"><span class="k">Маршрут</span><span class="v">${esc(o.fromAddress)} → ${esc(o.toAddress)}</span></div>
        <div class="m-row"><span class="k">Цена</span><span class="v">${money(o.priceFinal || o.priceFrom)}</span></div>
        <div class="m-row"><span class="k">Статус</span><span class="v">${badge(o.status)}</span></div>
        <div class="m-actions">
          <button class="btn btn-ghost btn-sm" type="button" data-order="${esc(o.id)}">Детали</button>
          ${o.status !== 'canceled' && o.status !== 'completed'
            ? `<button class="btn btn-danger btn-sm" data-cancel="${esc(o.id)}">Отменить</button>` : ''}
          ${o.status === 'completed' && o.paymentStatus === 'paid'
            ? `<button class="btn btn-ghost btn-sm" data-refund="${esc(o.id)}">Возврат</button>` : ''}
        </div>
      </div>`).join('') || '<div class="empty">Нет заказов</div>';
    }

    $('#orderLoad').onclick = async () => {
      try { await fetchAndPaint(); } catch (e) { toast(e.message, 'error'); }
    };
    await fetchAndPaint();
  }

  async function loadFinance() {
    const [payoutsData, paidOrders, unpaidOrders] = await Promise.all([
      AdminApi.getPayouts(100).catch(() => ({ payouts: [] })),
      AdminApi.getOrders({ status: 'completed', paymentStatus: 'paid', limit: '80' }).catch(() => ({ orders: [] })),
      AdminApi.getOrders({ status: 'completed', paymentStatus: 'unpaid', limit: '80' }).catch(() => ({ orders: [] })),
    ]);
    const payouts = payoutsData.payouts || [];
    const payments = paidOrders.orders || [];
    const unpaid = unpaidOrders.orders || [];
    const gmvPaid = payments.reduce((s, o) => s + Number(o.priceFinal || o.priceFrom || 0), 0);
    const payoutSum = payouts.reduce((s, p) => s + Number(p.amount || 0), 0);

    content.innerHTML = `
      <div class="page-head">
        <div>
          <h1>Финансы</h1>
          <p>Оплаты заказов и выплаты водителям</p>
        </div>
        <button class="btn btn-ghost btn-sm" type="button" data-retry>Обновить</button>
      </div>
      <div class="stats">
        <div class="stat"><div class="k">Оплачено (выборка)</div><div class="v">${money(gmvPaid)}</div></div>
        <div class="stat"><div class="k">Оплаченных заказов</div><div class="v">${payments.length}</div></div>
        <div class="stat"><div class="k">Не оплачено</div><div class="v">${unpaid.length}</div></div>
        <div class="stat"><div class="k">Выплаты водителям</div><div class="v">${money(payoutSum)}</div></div>
      </div>
      <div class="card">
        <div class="card-h">Возвраты
          <span class="badge b-muted">stub</span>
        </div>
        <div class="card-b">
          <p class="dim" style="margin:0 0 10px">API возврата платежей на бэкенде нет. Кнопка «Возврат» в заказах пишет аудит-заметку локально и в серверный журнал (если доступен), без изменения платёжного провайдера.</p>
        </div>
      </div>
      <div class="card desk"><div class="card-h">Оплаты (completed · paid)</div><div class="table-wrap">
        <table class="tbl"><thead><tr>
          <th>Заказ</th><th>Маршрут</th><th>Сумма</th><th>Метод</th><th>Дата</th><th></th>
        </tr></thead><tbody>
          ${payments.map((o) => `<tr>
            <td class="mono">${esc(String(o.id || '').slice(0, 8))}…</td>
            <td>${esc(o.fromAddress || '—')} → ${esc(o.toAddress || '—')}</td>
            <td>${money(o.priceFinal || o.priceFrom)}</td>
            <td>${esc(o.paymentMethod || '—')}</td>
            <td>${date(o.completedAt || o.createdAt)}</td>
            <td class="actions">
              <button class="btn btn-ghost btn-sm" data-order="${esc(o.id)}">Детали</button>
              <button class="btn btn-ghost btn-sm" data-refund="${esc(o.id)}">Возврат</button>
            </td>
          </tr>`).join('') || '<tr><td colspan="6">Нет оплаченных заказов в выборке</td></tr>'}
        </tbody></table>
      </div></div>
      <div class="card desk"><div class="card-h">Выплаты водителям (payouts)</div><div class="table-wrap">
        <table class="tbl"><thead><tr>
          <th>ID</th><th>Водитель</th><th>Сумма</th><th>Заказ</th><th>Статус</th><th>Дата</th>
        </tr></thead><tbody>
          ${payouts.map((p) => `<tr>
            <td class="mono">${esc(String(p.id || '').slice(0, 8))}…</td>
            <td>${phone(p.driverPhone)}</td>
            <td>${money(p.amount)}</td>
            <td>${p.orderId ? `<button class="btn btn-ghost btn-sm" data-order="${esc(p.orderId)}">${esc(String(p.orderId).slice(0, 8))}…</button>` : '—'}</td>
            <td>${esc(p.status || '—')}</td>
            <td>${date(p.createdAt)}</td>
          </tr>`).join('') || '<tr><td colspan="6">Выплат пока нет</td></tr>'}
        </tbody></table>
      </div></div>
      <div class="cards">
        ${payments.slice(0, 10).map((o) => `<div class="m-card">
          <div class="m-row"><span class="k">Сумма</span><span class="v">${money(o.priceFinal || o.priceFrom)}</span></div>
          <div class="m-row"><span class="k">Маршрут</span><span class="v">${esc(o.fromAddress)} → ${esc(o.toAddress)}</span></div>
          <div class="m-actions">
            <button class="btn btn-ghost btn-sm" data-order="${esc(o.id)}">Детали</button>
            <button class="btn btn-ghost btn-sm" data-refund="${esc(o.id)}">Возврат</button>
          </div>
        </div>`).join('') || '<div class="empty">Нет оплат</div>'}
      </div>`;
  }

  async function loadTariffs() {
    const [svcData, taxiData] = await Promise.all([
      AdminApi.getTariffs(),
      AdminApi.getTaxiTariffs().catch(() => ({ tariffs: [] })),
    ]);
    const tariffs = svcData.tariffs || [];
    const taxiTariffs = taxiData.tariffs || [];
    content.innerHTML = `
      <div class="page-head">
        <div><h1>Тарифы</h1><p>Услуги КОРОЛИ ДОРОГ и такси для приложений</p></div>
      </div>
      <div class="tabs" id="tariffTabs">
        <button class="tab active" data-tariff-tab="services">Услуги</button>
        <button class="tab" data-tariff-tab="taxi">Такси (приложения)</button>
      </div>
      <div class="card" id="tariffServicesCard">
        <div class="card-h">Тарифы услуг <button class="btn btn-gold btn-sm" type="button" id="saveTariffs">Сохранить</button></div>
        <div class="card-b" id="tariffList"></div>
      </div>
      <div class="card hidden" id="tariffTaxiCard">
        <div class="card-h">Тарифы такси · GET /api/taxi/tariffs
          <button class="btn btn-gold btn-sm" type="button" id="saveTaxiTariffs">Сохранить</button>
        </div>
        <div class="card-b">
          <p class="dim" style="margin:0 0 12px">Подача = ₽/км × 3, путь = ₽/км × расстояние. После «Сохранить» — сразу в приложениях и при расчёте заказа на сервере.</p>
          <div class="toolbar" style="margin-bottom:8px;padding:8px 12px;font-size:0.75rem;color:var(--muted)">
            <div style="min-width:120px">Тариф</div>
            <div style="min-width:100px">Клиент ₽/км</div>
            <div style="min-width:100px">Водитель ₽/км</div>
            <div style="flex:1">Пример (12 км)</div>
          </div>
          <div id="taxiTariffList"></div>
          <p class="dim" id="taxiTariffStatus" style="margin:12px 0 0"></p>
        </div>
      </div>`;

    const box = $('#tariffList');
    box.innerHTML = tariffs.map((t, i) => `
      <div class="toolbar" data-idx="${i}" style="margin-bottom:10px;padding:12px;background:var(--surface-2);border-radius:12px;border:1px solid var(--border)">
        <div style="min-width:140px;font-weight:650">${esc(t.name || t.title || `Тариф ${i + 1}`)}</div>
        <div class="field"><input type="number" data-f="base" value="${t.base ?? ''}" placeholder="База" /></div>
        <div class="field"><input type="number" data-f="perKm" step="0.1" value="${t.perKm ?? ''}" placeholder="₽/км" /></div>
        <div class="field"><input type="number" data-f="perMin" step="0.1" value="${t.perMin ?? ''}" placeholder="₽/мин" /></div>
      </div>`).join('') || '<div class="empty">Нет тарифов</div>';

    const taxiBox = $('#taxiTariffList');
    const sampleKm = 12;
    taxiBox.innerHTML = taxiTariffs.map((t, i) => {
      const client = t.clientRatePerKm ?? t.perKm ?? 0;
      const driver = t.driverRatePerKm ?? Math.round(client * 33 / 43);
      const sample = Math.round(client * 3 + client * sampleKm);
      return `
      <div class="toolbar" data-taxi-idx="${i}" style="margin-bottom:10px;padding:12px;background:var(--surface-2);border-radius:12px;border:1px solid var(--border)">
        <div style="min-width:120px;font-weight:650">${esc(t.name || t.id)}</div>
        <div class="field"><input type="number" min="0" data-tf="clientRatePerKm" value="${client}" placeholder="Клиент" aria-label="Клиент ₽/км ${esc(t.name || t.id)}" /></div>
        <div class="field"><input type="number" min="0" data-tf="driverRatePerKm" value="${driver}" placeholder="Водитель" aria-label="Водитель ₽/км ${esc(t.name || t.id)}" /></div>
        <div class="dim" data-tf-preview style="align-self:center">≈ ${sample} ₽</div>
      </div>`;
    }).join('') || '<div class="empty">Нет тарифов такси</div>';

    taxiBox.querySelectorAll('[data-tf="clientRatePerKm"]').forEach((inp) => {
      inp.addEventListener('input', () => {
        const row = inp.closest('[data-taxi-idx]');
        const rate = Number(inp.value) || 0;
        const preview = row?.querySelector('[data-tf-preview]');
        if (preview) preview.textContent = `≈ ${Math.round(rate * 3 + rate * sampleKm)} ₽`;
      });
    });

    $$('#tariffTabs .tab').forEach((tab) => {
      tab.onclick = () => {
        $$('#tariffTabs .tab').forEach((x) => x.classList.remove('active'));
        tab.classList.add('active');
        const mode = tab.dataset.tariffTab;
        $('#tariffServicesCard').classList.toggle('hidden', mode !== 'services');
        $('#tariffTaxiCard').classList.toggle('hidden', mode !== 'taxi');
      };
    });

    $('#saveTariffs').onclick = async () => {
      const updated = tariffs.map((t, i) => {
        const row = box.querySelector(`[data-idx="${i}"]`);
        if (!row) return t;
        $$('[data-f]', row).forEach((inp) => { t[inp.dataset.f] = Number(inp.value) || 0; });
        return t;
      });
      try {
        await AdminApi.saveTariffs(updated);
        toast('Тарифы услуг сохранены');
      } catch (e) { toast(e.message, 'error'); }
    };

    $('#saveTaxiTariffs').onclick = async () => {
      const updated = taxiTariffs.map((t, i) => {
        const row = taxiBox.querySelector(`[data-taxi-idx="${i}"]`);
        if (!row) return t;
        const next = { ...t };
        $$('[data-tf]', row).forEach((inp) => { next[inp.dataset.tf] = Number(inp.value) || 0; });
        next.clientRatePerKm = Number(next.clientRatePerKm) || 0;
        next.perKm = next.clientRatePerKm;
        if (!next.driverRatePerKm) next.driverRatePerKm = Math.round(next.clientRatePerKm * 33 / 43);
        return next;
      });
      try {
        const res = await AdminApi.saveTaxiTariffs(updated);
        const saved = res.tariffs || updated;
        toast(`Тарифы такси сохранены (${saved.length}) — приложения подхватят при следующей загрузке`);
        const status = $('#taxiTariffStatus');
        if (status && saved[0]) {
          status.textContent = `Сохранено в Redis · Эконом = ${saved.find((x) => x.id === 'economy')?.clientRatePerKm ?? saved[0].clientRatePerKm} ₽/км · проверка: GET /api/taxi/tariffs`;
        }
      } catch (e) { toast(e.message, 'error'); }
    };
  }

  async function loadAudit() {
    let entries = [];
    let apiOk = false;
    let apiError = '';
    try {
      const data = await AdminApi.getAudit(200);
      entries = data.entries || [];
      apiOk = true;
    } catch (e) {
      apiError = e.message || 'API недоступен';
    }
    const localEntries = readLocalAudit(100);
    const actionLabels = {
      'order.cancel': 'Отмена заказа',
      'order.assign': 'Назначение водителя',
      'order.refund_stub': 'Возврат (stub)',
      'driver.block': 'Блокировка водителя',
      'driver.approve': 'Одобрение водителя',
      'driver.reject': 'Отклонение водителя',
      'client.block': 'Блокировка клиента',
      'client.comment': 'Комментарий клиента',
      'support.reply': 'Ответ в поддержке',
      'support.close': 'Закрытие тикета',
      'tariffs.save_services': 'Тарифы услуг',
      'tariffs.save_taxi': 'Тарифы такси',
    };

    const rows = (list) => list.map((e) => `<tr>
      <td>${date(e.createdAt)}</td>
      <td>${esc(actionLabels[e.action] || e.action)}</td>
      <td class="mono">${esc(e.target || '—')}</td>
      <td>${esc(e.details || '—')}</td>
      <td>${esc(e.admin || '—')}</td>
    </tr>`).join('') || '<tr><td colspan="5">Записей нет</td></tr>';

    content.innerHTML = `
      <div class="page-head">
        <div><h1>Журнал действий</h1><p>${apiOk ? `${entries.length} серверных` : 'серверный журнал недоступен'} · ${localEntries.length} локальных</p></div>
        <button class="btn btn-ghost btn-sm" type="button" data-retry>Обновить</button>
      </div>
      ${apiOk ? '' : `<div class="empty-soft">Серверный audit API: ${esc(apiError)}. Ниже — ${LOCAL_AUDIT_LABEL}.</div>`}
      <div class="card desk">
        <div class="card-h">Серверный журнал${apiOk ? '' : ' (пусто / ошибка)'}</div>
        <div class="table-wrap">
        <table class="tbl"><thead><tr>
          <th>Время</th><th>Действие</th><th>Объект</th><th>Детали</th><th>Админ</th>
        </tr></thead><tbody>${rows(entries)}</tbody></table>
      </div></div>
      <div class="card desk">
        <div class="card-h">${LOCAL_AUDIT_LABEL} <span class="badge b-muted">client-side stub</span></div>
        <div class="table-wrap">
        <table class="tbl"><thead><tr>
          <th>Время</th><th>Действие</th><th>Объект</th><th>Детали</th><th>Админ</th>
        </tr></thead><tbody>${rows(localEntries)}</tbody></table>
      </div></div>
      <div class="cards">${(apiOk ? entries : localEntries).slice(0, 30).map((e) => `<div class="m-card">
        <div class="m-row"><span class="k">Действие</span><span class="v">${esc(actionLabels[e.action] || e.action)}</span></div>
        <div class="m-row"><span class="k">Время</span><span class="v">${date(e.createdAt)}</span></div>
        <div class="m-row"><span class="k">Объект</span><span class="v">${esc(e.target || '—')}</span></div>
      </div>`).join('') || '<div class="empty">Журнал пуст</div>'}</div>`;
  }

  async function requestRefundStub(orderId) {
    const note = prompt('Причина возврата (запишется в аудит):', 'Возврат по обращению клиента') || '';
    if (!confirm(`Зафиксировать возврат (stub) по заказу ${orderId.slice(0, 8)}…?\n\nПлатёжный провайдер не вызывается — только аудит.`)) return;
    pushLocalAudit('order.refund_stub', orderId, note || 'refund stub');
    toast('Возврат зафиксирован в локальном журнале (API возврата нет)');
    if (page === 'finance' || page === 'orders') go(page);
  }

  async function openOrderDetail(orderId) {
    openModal('Заказ', '<div class="loading"><div class="spinner"></div>Загрузка…</div>', '', true);
    try {
      const data = await AdminApi.getOrder(orderId);
      const o = data.order || {};
      const timeline = data.timeline || [];
      const chat = data.chat || [];
      const canAssign = o.status === 'searching' || (o.status === 'accepted' && !o.driverPhone);
      $('#modalTitle').textContent = `Заказ ${String(o.id || orderId).slice(0, 8)}…`;
      $('#modalBody').innerHTML = `
        <div class="order-detail-grid">
          <div class="m-card">
            <div class="m-row"><span class="k">Маршрут</span><span class="v">${esc(o.fromAddress)} → ${esc(o.toAddress)}</span></div>
            <div class="m-row"><span class="k">Статус</span><span class="v">${badge(o.status)}</span></div>
            <div class="m-row"><span class="k">Цена</span><span class="v">${money(o.priceFinal || o.priceFrom)}</span></div>
            <div class="m-row"><span class="k">Оплата</span><span class="v">${esc(o.paymentStatus || '—')} · ${esc(o.paymentMethod || '—')}</span></div>
            <div class="m-row"><span class="k">Клиент</span><span class="v">${esc(o.clientName || o.clientPhone || o.clientId || '—')}</span></div>
            <div class="m-row"><span class="k">Водитель</span><span class="v">${phone(o.driverPhone)} ${o.driverName ? `· ${esc(o.driverName)}` : ''}</span></div>
            <div class="m-row"><span class="k">Создан</span><span class="v">${date(o.createdAt)}</span></div>
            ${o.cancelReason ? `<div class="m-row"><span class="k">Причина отмены</span><span class="v">${esc(o.cancelReason)}</span></div>` : ''}
            ${o.canceledBy ? `<div class="m-row"><span class="k">Отменил</span><span class="v">${esc(actorLabel(o.canceledBy))}</span></div>` : ''}
            ${o.comment ? `<div class="m-row"><span class="k">Комментарий</span><span class="v">${esc(o.comment)}</span></div>` : ''}
          </div>
          <div>
            <div class="card-h" style="padding:0 0 8px">История статусов</div>
            ${renderTimeline(timeline)}
          </div>
        </div>
        <div style="margin-top:16px">
          <div class="card-h" style="padding:0 0 8px">Чат поездки (только чтение)</div>
          ${renderChat(chat)}
        </div>`;
      $('#modalFooter').innerHTML = `
        ${canAssign ? `<button class="btn btn-primary btn-sm" type="button" data-assign="${esc(o.id)}" data-assign-close="1">Назначить водителя</button>` : ''}
        ${o.status !== 'canceled' && o.status !== 'completed'
          ? `<button class="btn btn-danger btn-sm" type="button" data-cancel="${esc(o.id)}" data-cancel-close="1">Отменить заказ</button>` : ''}
        ${o.status === 'completed' && o.paymentStatus === 'paid'
          ? `<button class="btn btn-ghost btn-sm" type="button" data-refund="${esc(o.id)}" data-refund-close="1">Возврат (stub)</button>` : ''}
        ${o.status === 'completed' && o.paymentStatus !== 'paid'
          ? `<button class="btn btn-ok btn-sm" type="button" data-pay="${esc(o.id)}" data-pay-close="1">Отметить оплаченным</button>` : ''}
        <button class="btn btn-ghost btn-sm" type="button" id="modalCloseBtn">Закрыть</button>`;
      const closeBtn = $('#modalCloseBtn');
      if (closeBtn) closeBtn.onclick = closeModal;
    } catch (e) {
      $('#modalBody').innerHTML = `<div class="error-box">${esc(e.message)}</div>`;
      $('#modalFooter').innerHTML = '';
    }
  }

  async function openAssignModal(orderId) {
    let candidates = dispatchDriversCache.filter((d) => d.status === 'online');
    if (!candidates.length) {
      try {
        const data = await AdminApi.getDrivers('dispatch', { includeLocation: true });
        dispatchDriversCache = (data.drivers || []).filter((d) => !d.blocked);
        candidates = dispatchDriversCache.filter((d) => d.status === 'online');
      } catch (_) { /* use manual input */ }
    }
    const rows = candidates.length ? candidates.map((d) => {
      const p = d.profile || {};
      const loc = d.location;
      return `<button type="button" class="assign-driver-row" data-pick-driver="${esc(d.phone)}">
        <div>
          <strong>${esc(p.fullName || '—')}</strong>
          <div class="dim">${phone(d.phone)}</div>
          ${loc?.lat != null ? `<div class="mono dim">${Number(loc.lat).toFixed(4)}, ${Number(loc.lng).toFixed(4)}</div>` : ''}
        </div>
        ${badge(d.status)}
      </button>`;
    }).join('') : '<div class="empty">Нет водителей онлайн — введите телефон вручную</div>';

    openModal('Назначить водителя', `
      <p class="dim" style="margin-bottom:12px">Заказ: <span class="mono">${esc(orderId)}</span></p>
      <div class="assign-driver-list">${rows}</div>
      <div class="field" style="margin-top:14px">
        <label>Или телефон вручную</label>
        <input id="assignPhoneManual" placeholder="7XXXXXXXXXX" />
      </div>
    `, `<button class="btn btn-primary btn-sm" type="button" id="assignManualBtn">Назначить</button>`);

    $$('[data-pick-driver]').forEach((btn) => {
      btn.onclick = async () => {
        try {
          await AdminApi.assignOrder(orderId, btn.dataset.pickDriver);
          pushLocalAudit('order.assign', orderId, btn.dataset.pickDriver);
          toast('Водитель назначен');
          closeModal();
          go(page);
        } catch (e) { toast(e.message, 'error'); }
      };
    });

    $('#assignManualBtn').onclick = async () => {
      const raw = ($('#assignPhoneManual')?.value || '').replace(/\D/g, '');
      if (raw.length < 10) return toast('Введите корректный телефон', 'error');
      try {
        await AdminApi.assignOrder(orderId, raw);
        pushLocalAudit('order.assign', orderId, raw);
        toast('Водитель назначен');
        closeModal();
        go(page);
      } catch (e) { toast(e.message, 'error'); }
    };
  }

  async function loadPromos() {
    const data = await AdminApi.getPromos();
    const promos = data.promos || [];
    content.innerHTML = `
      <div class="page-head">
        <div><h1>Промокоды</h1><p>${promos.length} шт.</p></div>
        <button class="btn btn-gold btn-sm" type="button" id="addPromo">Создать</button>
      </div>
      <div class="card desk"><div class="table-wrap">
        <table class="tbl"><thead><tr><th>Код</th><th>Скидка</th><th>Активен</th><th></th></tr></thead>
        <tbody>${promos.map((p) => `<tr>
          <td><b>${esc(p.code)}</b></td>
          <td>${p.discountPercent ?? p.discount ?? '—'}%</td>
          <td>${p.active !== false ? 'да' : 'нет'}</td>
          <td>${p.active !== false ? `<button class="btn btn-danger btn-sm" data-disable-promo="${esc(p.code)}">Отключить</button>` : ''}</td>
        </tr>`).join('') || '<tr><td colspan="4">Нет промокодов</td></tr>'}</tbody>
      </table></div></div>
      <div class="cards">${promos.map((p) => `<div class="m-card">
        <div class="m-row"><span class="k">Код</span><span class="v"><b>${esc(p.code)}</b></span></div>
        <div class="m-row"><span class="k">Скидка</span><span class="v">${p.discountPercent ?? p.discount ?? '—'}%</span></div>
        ${p.active !== false ? `<div class="m-actions"><button class="btn btn-danger btn-sm" data-disable-promo="${esc(p.code)}">Отключить</button></div>` : ''}
      </div>`).join('') || '<div class="empty">Нет промокодов</div>'}</div>`;

    $('#addPromo').onclick = () => {
      openModal('Новый промокод', `
        <div class="field"><label>Код</label><input id="newCode" placeholder="KOROLI" /></div>
        <div class="field"><label>Скидка %</label><input id="newDisc" type="number" value="10" min="1" max="100" /></div>
      `, `<button class="btn btn-gold" type="button" id="createPromo">Создать</button>`);
      $('#createPromo').onclick = async () => {
        try {
          await AdminApi.createPromo({
            code: $('#newCode').value.trim().toLowerCase(),
            discount: Number($('#newDisc').value) || 10,
          });
          pushLocalAudit('promo.create', $('#newCode').value.trim().toUpperCase());
          toast('Создано');
          closeModal();
          go('promos');
        } catch (e) { toast(e.message, 'error'); }
      };
    };
  }

  async function loadSettings() {
    let sub = {};
    let timeout = {};
    let antifraud = {};
    try { sub = await AdminApi.getSubscriptionSettings(); } catch (_) {}
    try { timeout = await AdminApi.getOrderTimeoutSettings(); } catch (_) {}
    try { antifraud = await AdminApi.getAntifraudSettings(); } catch (_) {}
    const mapKey = yandexKeyPresent() ? '••••••••' + String(window.ADMIN_CONFIG.yandexMapsApiKey).slice(-4) : '(не задан → OSM)';
    content.innerHTML = `
      <div class="page-head"><div><h1>Настройки</h1><p>Сервис, карта и антифрод</p></div></div>
      <div class="card"><div class="card-h">Карта</div><div class="card-b">
        <p class="field-hint" style="margin-bottom:12px">Ключ Яндекс JavaScript API хранится только в браузере (localStorage). Без ключа диспетчерская использует OpenStreetMap/Leaflet.</p>
        <div class="field"><label>Текущий ключ</label><input value="${esc(mapKey)}" disabled /></div>
        <div class="field"><label>Новый ключ Яндекс Maps</label><input id="mapKeyInput" type="password" autocomplete="off" placeholder="UUID ключа JS API" /></div>
        <div class="field"><label>Провайдер</label>
          <select id="mapProvider">
            <option value="auto" ${(window.ADMIN_CONFIG?.mapProvider || 'auto') === 'auto' ? 'selected' : ''}>Авто (Яндекс → OSM)</option>
            <option value="yandex" ${window.ADMIN_CONFIG?.mapProvider === 'yandex' ? 'selected' : ''}>Только Яндекс</option>
            <option value="leaflet" ${window.ADMIN_CONFIG?.mapProvider === 'leaflet' ? 'selected' : ''}>Только OpenStreetMap</option>
          </select>
        </div>
        <button class="btn btn-gold btn-sm" type="button" id="saveMapCfg">Сохранить карту</button>
        <button class="btn btn-ghost btn-sm" type="button" id="clearMapKey">Очистить ключ</button>
      </div></div>
      <div class="card"><div class="card-h">Подписка водителей</div><div class="card-b">
        <div class="field"><label>Сумма, ₽</label><input id="subAmount" type="number" value="${sub.amount ?? sub.subscriptionAmount ?? 1500}" /></div>
        <div class="field"><label>День месяца</label><input id="subDay" type="number" min="1" max="28" value="${sub.dayOfMonth ?? sub.subscriptionDayOfMonth ?? 5}" /></div>
        <button class="btn btn-primary btn-sm" type="button" id="saveSub">Сохранить</button>
      </div></div>
      <div class="card"><div class="card-h">Таймаут принятия заказа</div><div class="card-b">
        <div class="field"><label>Секунды</label>
          <select id="timeoutSec">${[5, 10, 15, 25, 30].map((s) =>
            `<option value="${s}" ${(timeout.orderAcceptTimeoutSec ?? 10) === s ? 'selected' : ''}>${s}</option>`).join('')}
          </select>
        </div>
        <button class="btn btn-primary btn-sm" type="button" id="saveTimeout">Сохранить</button>
      </div></div>
      <div class="card"><div class="card-h">Антифрод</div><div class="card-b">
        <p class="field-hint" style="margin-bottom:12px">Лимиты отказов от заказов. При превышении водитель временно блокируется.</p>
        <div class="field"><label>Макс. отказов в сутки</label>
          <input id="afMaxDay" type="number" min="1" max="500" value="${antifraud.maxDeclinesPerDay ?? 20}" />
        </div>
        <div class="field"><label>Автоблок после N пропусков подряд</label>
          <input id="afSkips" type="number" min="1" max="50" value="${antifraud.autoBlockAfterSkips ?? 3}" />
        </div>
        <div class="field"><label>Длительность блока, часов</label>
          <input id="afHours" type="number" min="1" max="168" value="${antifraud.blockHours ?? 48}" />
        </div>
        <button class="btn btn-gold btn-sm" type="button" id="saveAntifraud">Сохранить антифрод</button>
      </div></div>
      <div class="card"><div class="card-h">API</div><div class="card-b">
        <div class="field"><label>URL</label><input id="setApi" value="${esc(AdminApi.getBaseUrl())}" /></div>
        <button class="btn btn-ghost btn-sm" type="button" id="saveApi">Обновить URL</button>
      </div></div>`;

    $('#saveMapCfg').onclick = () => {
      const key = ($('#mapKeyInput').value || '').trim();
      const provider = $('#mapProvider').value || 'auto';
      if (key) {
        try { localStorage.setItem('koroli_yandex_maps_key', key); } catch (_) {}
        window.ADMIN_CONFIG = window.ADMIN_CONFIG || {};
        window.ADMIN_CONFIG.yandexMapsApiKey = key;
      }
      window.ADMIN_CONFIG.mapProvider = provider;
      try { localStorage.setItem('koroli_map_provider', provider); } catch (_) {}
      toast('Настройки карты сохранены');
    };
    $('#clearMapKey').onclick = () => {
      try { localStorage.removeItem('koroli_yandex_maps_key'); } catch (_) {}
      if (window.ADMIN_CONFIG) window.ADMIN_CONFIG.yandexMapsApiKey = '';
      toast('Ключ очищен — будет OSM');
      go('settings');
    };
    $('#saveSub').onclick = async () => {
      try {
        await AdminApi.saveSubscriptionSettings({
          amount: Number($('#subAmount').value),
          dayOfMonth: Number($('#subDay').value),
        });
        toast('Сохранено');
      } catch (e) { toast(e.message, 'error'); }
    };
    $('#saveTimeout').onclick = async () => {
      try {
        await AdminApi.saveOrderTimeoutSettings(Number($('#timeoutSec').value));
        toast('Сохранено');
      } catch (e) { toast(e.message, 'error'); }
    };
    $('#saveAntifraud').onclick = async () => {
      try {
        await AdminApi.saveAntifraudSettings({
          maxDeclinesPerDay: Number($('#afMaxDay').value),
          autoBlockAfterSkips: Number($('#afSkips').value),
          blockHours: Number($('#afHours').value),
        });
        toast('Антифрод сохранён');
      } catch (e) { toast(e.message, 'error'); }
    };
    $('#saveApi').onclick = () => {
      AdminApi.setBaseUrl($('#setApi').value.trim());
      toast('URL обновлён');
    };
  }

  async function openDocs(phoneNum) {
    openModal(`Документы — ${phone(phoneNum)}`, '<div class="loading"><div class="spinner"></div></div>');
    try {
      const data = await AdminApi.getDriverPhotos(phoneNum);
      const photos = data.photos || {};
      const profile = data.profile || {};
      const items = [
        ['passportFrontBase64', 'Паспорт'],
        ['passportRegBase64', 'ВУ спереди'],
        ['driverLicenseBackBase64', 'ВУ сзади'],
        ['selfieBase64', 'Селфи'],
        ['carPhotoBase64', 'Автомобиль'],
        ['stsBase64', 'СТС'],
        ['osagoBase64', 'ОСАГО'],
        ['signatureBase64', 'Подпись'],
      ];
      const gallery = [];
      const photosHtml = items.map(([key, label]) => {
        const raw = photos[key];
        if (raw && String(raw).length > 40) {
          const src = String(raw).startsWith('data:') ? raw : `data:image/jpeg;base64,${raw}`;
          gallery.push({ label, src });
          return `<div class="photo" data-docs-lightbox="${gallery.length - 1}">
            <img src="${src}" alt="${esc(label)}" /><div class="cap">${esc(label)}</div></div>`;
        }
        return `<div class="photo"><div class="ph">${esc(label)}</div></div>`;
      }).join('');
      $('#modalBody').innerHTML = `
        <div class="v-meta" style="padding:0 0 12px">
          <div><b>${esc(profile.fullName || '—')}</b></div>
          <div>ИНН: ${esc(profile.inn || '—')} · Паспорт: ${esc(profile.passport || '—')}</div>
          <div>Авто: ${esc(profile.carModel || '—')} · ${esc(profile.carColor || '—')} · ${esc(profile.carPlate || '—')}</div>
          <div>Статус: ${esc(profile.registrationStatus || '—')}</div>
        </div>
        <div class="photos" id="docsGallery">${photosHtml}</div>`;
      const gal = $('#docsGallery');
      if (gal) gal._gallery = gallery;
      $('#modalFooter').innerHTML = `
        <button class="btn btn-ok btn-sm" type="button" data-approve="${esc(phoneNum)}">Одобрить</button>
        <button class="btn btn-danger btn-sm" type="button" data-reject="${esc(phoneNum)}">Отклонить</button>
        <button class="btn btn-ghost btn-sm" type="button" data-force-pending="${esc(phoneNum)}">В pending</button>`;
    } catch (e) {
      $('#modalBody').innerHTML = `<div class="error-box">${esc(e.message)}</div>`;
    }
  }

  function bindOnce() {
    if (bound) return;
    bound = true;

    $('#apiUrlInput').value = AdminApi.getBaseUrl();

    $('#loginForm').addEventListener('submit', async (e) => {
      e.preventDefault();
      const err = $('#loginError');
      err.classList.add('hidden');
      const apiUrl = $('#apiUrlInput').value.trim();
      $('#loginBtn').disabled = true;
      try {
        if (apiUrl) AdminApi.setBaseUrl(apiUrl);
        await AdminApi.login($('#loginInput').value.trim(), $('#passwordInput').value);
        showApp();
      } catch (ex) {
        err.textContent = ex.message === 'AUTH_EXPIRED' ? 'Неверный логин или пароль' : ex.message;
        err.classList.remove('hidden');
      } finally {
        $('#loginBtn').disabled = false;
      }
    });

    $('#logoutBtn').onclick = showLogin;
    $('#menuBtn').onclick = () => (sidebar.classList.contains('open') ? closeMenu() : openMenu());
    window.matchMedia('(max-width: 980px)').addEventListener('change', closeMenu);
    backdrop.onclick = closeMenu;
    $('#modalClose').onclick = closeModal;
    $('#modalBg').addEventListener('click', (e) => { if (e.target.id === 'modalBg') closeModal(); });
    window.addEventListener('admin:connection', event => {
      const online = event.detail.state === 'online';
      const status = $('#apiStatus');
      status.textContent = online ? 'Сервер на связи' : 'Нет связи';
      status.className = `badge ${online ? 'b-ok' : 'b-danger'}`;
    });
    document.addEventListener('keydown', event => {
      if (event.key === 'Escape') { closeModal(); closeMenu(); }
      const dialog = $('#modalBg');
      if (event.key !== 'Tab' || dialog.classList.contains('hidden')) return;
      const controls = [...dialog.querySelectorAll('button, input, select, textarea, a[href], [tabindex="0"]')]
        .filter(element => !element.disabled && element.getClientRects().length);
      const first = controls[0];
      const last = controls[controls.length - 1];
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault(); last?.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault(); first?.focus();
      }
    });

    nav.addEventListener('click', (e) => {
      const btn = e.target.closest('[data-nav]');
      if (btn) go(btn.dataset.nav);
    });

    document.addEventListener('click', async (e) => {
      const t = e.target.closest(
        '[data-retry],[data-approve],[data-reject],[data-force-pending],[data-block],[data-unblock],[data-docs],[data-cblock],[data-cunblock],[data-cancel],[data-pay],[data-refund],[data-client],[data-disable-promo],[data-p],[data-view-label],[data-lightbox],[data-docs-lightbox],[data-bc-off],[data-bc-del],[data-assign],[data-ticket],[data-order],[data-pick-driver]'
      );
      if (!t) return;

      try {
        if (t.hasAttribute('data-retry')) return go(page);
        if (t.dataset.p) {
          $$('#dashTabs .tab').forEach((x) => x.classList.remove('active'));
          t.classList.add('active');
          const d = await AdminApi.getStats(t.dataset.p, t.dataset.m);
          const list = d.list || [];
          const primary = $('#dashPrimary');
          if (primary && list.length) {
            // Keep GMV/conversion cards when switching company/orders tabs when possible
            if (t.dataset.m === 'company' || t.dataset.m === 'orders') {
              const metricByKey = (arr, ...keys) => {
                for (const k of keys) {
                  const found = (arr || []).find((x) => String(x.k || '').toLowerCase().includes(k));
                  if (found) return found.v;
                }
                return null;
              };
              const cards = primary.querySelectorAll('.stat');
              if (cards[0] && metricByKey(list, 'доход')) cards[0].querySelector('.v').textContent = metricByKey(list, 'доход');
              if (cards[1] && (metricByKey(list, 'заказ') || metricByKey(list, 'заверш'))) {
                cards[1].querySelector('.v').textContent = metricByKey(list, 'заказ') || metricByKey(list, 'заверш');
              }
              if (cards[2] && metricByKey(list, 'отмен')) cards[2].querySelector('.v').textContent = metricByKey(list, 'отмен');
              if (cards[3] && metricByKey(list, 'конверс')) cards[3].querySelector('.v').textContent = metricByKey(list, 'конверс');
            }
          }
          const titleEl = $('#dashTitle');
          if (titleEl) titleEl.textContent = d.title || 'График';
          $('#dashChart').innerHTML = chart(d.labels || [], d.series || []);
          return;
        }
        if (t.dataset.bcOff) {
          await AdminApi.deactivateBroadcast(t.dataset.bcOff);
          toast('Уведомление выключено');
          return go('broadcasts');
        }
        if (t.dataset.bcDel) {
          if (!confirm('Удалить уведомление?')) return;
          await AdminApi.deleteBroadcast(t.dataset.bcDel);
          toast('Удалено');
          return go('broadcasts');
        }
        if (t.dataset.ticket) {
          const ticket = supportCache.find((x) => x.id === t.dataset.ticket);
          if (!ticket) return toast('Тикет не найден', 'error');
          return openTicket(ticket);
        }
        if (t.dataset.client) return openClientProfile(t.dataset.client);
        if (t.dataset.assign) {
          if (t.dataset.assignClose) closeModal();
          return openAssignModal(t.dataset.assign);
        }
        if (t.dataset.order) return openOrderDetail(t.dataset.order);
        if (t.dataset.refund) {
          if (t.dataset.refundClose) closeModal();
          return requestRefundStub(t.dataset.refund);
        }
        if (t.dataset.approve) {
          await AdminApi.approveDriver(t.dataset.approve);
          pushLocalAudit('driver.approve', t.dataset.approve);
          toast('Водитель одобрен');
          closeModal();
          await refreshBadge();
          return go(page === 'verify' || page === 'drivers' ? page : 'verify');
        }
        if (t.dataset.reject) {
          await AdminApi.rejectDriver(t.dataset.reject);
          pushLocalAudit('driver.reject', t.dataset.reject);
          toast('Заявка отклонена', 'error');
          closeModal();
          await refreshBadge();
          return go(page === 'verify' || page === 'drivers' ? page : 'verify');
        }
        if (t.dataset.forcePending) {
          await AdminApi.forcePendingDriver(t.dataset.forcePending);
          pushLocalAudit('driver.force_pending', t.dataset.forcePending);
          toast('Статус: pending');
          closeModal();
          await refreshBadge();
          return go(page === 'verify' || page === 'drivers' ? page : 'verify');
        }
        if (t.dataset.block) {
          const reason = prompt('Причина блокировки (необязательно):') || '';
          await AdminApi.blockDriver(t.dataset.block, reason);
          pushLocalAudit('driver.block', t.dataset.block, reason);
          toast('Заблокирован');
          return go('drivers');
        }
        if (t.dataset.unblock) {
          await AdminApi.unblockDriver(t.dataset.unblock);
          pushLocalAudit('driver.unblock', t.dataset.unblock);
          toast('Разблокирован');
          return go('drivers');
        }
        if (t.dataset.docs) return openDocs(t.dataset.docs);
        if (t.dataset.cblock) {
          const reason = prompt('Причина блокировки клиента (необязательно):') || '';
          await AdminApi.blockClient(t.dataset.cblock, reason);
          pushLocalAudit('client.block', t.dataset.cblock, reason);
          toast('Клиент заблокирован');
          if (t.dataset.clientClose) closeModal();
          return go('clients');
        }
        if (t.dataset.cunblock) {
          await AdminApi.unblockClient(t.dataset.cunblock);
          pushLocalAudit('client.unblock', t.dataset.cunblock);
          toast('Клиент разблокирован');
          if (t.dataset.clientClose) closeModal();
          return go('clients');
        }
        if (t.dataset.cancel) {
          const reason = prompt('Причина отмены (необязательно):') || '';
          if (!confirm('Отменить заказ?')) return;
          await AdminApi.cancelOrder(t.dataset.cancel, reason);
          pushLocalAudit('order.cancel', t.dataset.cancel, reason);
          toast('Заказ отменён');
          if (t.dataset.cancelClose) closeModal();
          return go(t.dataset.cancelGoto || 'orders');
        }
        if (t.dataset.pay) {
          await AdminApi.payOrder(t.dataset.pay);
          pushLocalAudit('order.pay', t.dataset.pay);
          toast('Отмечен как оплаченный');
          if (t.dataset.payClose) closeModal();
          return go(page === 'finance' ? 'finance' : 'orders');
        }
        if (t.dataset.disablePromo) {
          await AdminApi.disablePromo(t.dataset.disablePromo);
          pushLocalAudit('promo.disable', t.dataset.disablePromo);
          toast('Промокод отключён');
          return go('promos');
        }
        if (t.hasAttribute('data-lightbox')) {
          const box = t.closest('[data-photos]');
          const gallery = box?._gallery || [];
          const idx = Number(t.dataset.lightbox) || 0;
          return openPhotoViewer(gallery, idx);
        }
        if (t.hasAttribute('data-docs-lightbox')) {
          const box = $('#docsGallery');
          const gallery = box?._gallery || [];
          const idx = Number(t.dataset.docsLightbox) || 0;
          return openPhotoViewer(gallery, idx);
        }
        if (t.hasAttribute('data-view-label')) {
          const img = t.querySelector('img');
          if (img) openModal(t.dataset.viewLabel || 'Фото', `<div class="lightbox"><img src="${img.src}" alt="" /></div>`);
        }
      } catch (err) {
        if (err.message === 'AUTH_EXPIRED') showLogin();
        else toast(err.message, 'error');
      }
    });
  }

  bindOnce();
  if (AdminApi.isLoggedIn()) showApp();
  else showLogin();
})();
