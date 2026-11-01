/**
 * OpenStreetMap / Leaflet fallback when Yandex Maps key is missing or invalid.
 */
const AdminLeafletMap = (() => {
  'use strict';

  const DEFAULT_CENTER = [55.751244, 37.618423];
  const DEFAULT_ZOOM = 11;

  let map = null;
  let layerGroup = null;
  let loadPromise = null;

  function loadLeaflet() {
    if (typeof L !== 'undefined') return Promise.resolve();
    if (loadPromise) return loadPromise;

    loadPromise = new Promise((resolve, reject) => {
      const cssId = 'leaflet-css-cdn';
      if (!document.getElementById(cssId)) {
        const link = document.createElement('link');
        link.id = cssId;
        link.rel = 'stylesheet';
        link.href = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css';
        document.head.appendChild(link);
      }

      const script = document.createElement('script');
      script.src = 'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js';
      script.async = true;
      const timer = setTimeout(() => reject(new Error('Leaflet load timeout')), 20000);
      script.onload = () => {
        clearTimeout(timer);
        if (typeof L === 'undefined') reject(new Error('Leaflet failed to load'));
        else resolve();
      };
      script.onerror = () => {
        clearTimeout(timer);
        reject(new Error('Failed to load Leaflet CDN'));
      };
      document.head.appendChild(script);
    });

    return loadPromise;
  }

  function statusColor(st) {
    if (st === 'online') return '#3dd68c';
    if (st === 'busy') return '#ffb020';
    return '#9a9aaa';
  }

  function driverIcon(st) {
    const color = statusColor(st);
    return L.divIcon({
      className: 'leaflet-koroli-marker',
      html: `<span class="leaflet-koroli-dot" style="background:${color}"></span>`,
      iconSize: [18, 18],
      iconAnchor: [9, 9],
    });
  }

  function orderIcon() {
    return L.divIcon({
      className: 'leaflet-koroli-marker',
      html: '<span class="leaflet-koroli-dot order"></span>',
      iconSize: [14, 14],
      iconAnchor: [7, 7],
    });
  }

  function collectPoints(drivers, orders) {
    const points = [];

    (drivers || []).forEach((d) => {
      const loc = d.location;
      if (loc?.lat == null || loc?.lng == null) return;
      const name = (d.profile || {}).fullName || d.phone || 'Водитель';
      const st = d.status || 'offline';
      points.push({
        lat: Number(loc.lat),
        lng: Number(loc.lng),
        kind: 'driver',
        status: st,
        popup: `<strong>${escapeHtml(name)}</strong><br/>Статус: ${escapeHtml(st)}<br/>${escapeHtml(d.phone || '')}`,
      });
    });

    (orders || []).forEach((o) => {
      const from = o.from;
      if (from?.lat == null || from?.lng == null) return;
      points.push({
        lat: Number(from.lat),
        lng: Number(from.lng),
        kind: 'order',
        popup: `<strong>Заказ</strong><br/>${escapeHtml(o.fromAddress || '—')} → ${escapeHtml(o.toAddress || '—')}<br/>${escapeHtml(o.status || '')}`,
      });
    });

    return points;
  }

  function escapeHtml(v) {
    return String(v ?? '')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;');
  }

  function fitBounds(points) {
    if (!map) return;
    if (!points.length) {
      map.setView(DEFAULT_CENTER, DEFAULT_ZOOM);
      return;
    }
    if (points.length === 1) {
      map.setView([points[0].lat, points[0].lng], 14);
      return;
    }
    const bounds = L.latLngBounds(points.map((p) => [p.lat, p.lng]));
    map.fitBounds(bounds.pad(0.18));
  }

  async function render(containerEl, drivers, orders) {
    if (!containerEl) return false;
    try {
      await loadLeaflet();
    } catch (err) {
      console.warn('[AdminLeafletMap]', err);
      return false;
    }

    try {
      if (!map) {
        containerEl.innerHTML = '';
        const mapDiv = document.createElement('div');
        mapDiv.className = 'leaflet-map-container';
        mapDiv.setAttribute('role', 'application');
        mapDiv.setAttribute('aria-label', 'Карта водителей и заказов (OSM)');
        containerEl.appendChild(mapDiv);

        map = L.map(mapDiv, {
          zoomControl: true,
          attributionControl: true,
        }).setView(DEFAULT_CENTER, DEFAULT_ZOOM);

        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
          maxZoom: 19,
          attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
        }).addTo(map);

        layerGroup = L.layerGroup().addTo(map);
      } else {
        // Ensure container still hosts the map after DOM rebuilds
        const existing = containerEl.querySelector('.leaflet-map-container');
        if (!existing) {
          destroy();
          return render(containerEl, drivers, orders);
        }
      }

      layerGroup.clearLayers();
      const points = collectPoints(drivers, orders);
      points.forEach((p) => {
        const marker = L.marker([p.lat, p.lng], {
          icon: p.kind === 'order' ? orderIcon() : driverIcon(p.status),
        });
        marker.bindPopup(p.popup);
        layerGroup.addLayer(marker);
      });
      fitBounds(points);
      setTimeout(() => { try { map.invalidateSize(); } catch (_) { /* ignore */ } }, 80);
      return true;
    } catch (err) {
      console.warn('[AdminLeafletMap] init', err);
      return false;
    }
  }

  function destroy() {
    if (map) {
      try { map.remove(); } catch (_) { /* ignore */ }
      map = null;
      layerGroup = null;
    }
  }

  return { render, destroy };
})();
