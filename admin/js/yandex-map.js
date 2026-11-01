/**
 * Yandex Maps JavaScript API 2.1 — диспетчерская карта.
 */
const AdminYandexMap = (() => {
  'use strict';

  const DEFAULT_CENTER = [55.751244, 37.618423];
  const DEFAULT_ZOOM = 11;

  let map = null;
  let collection = null;
  let loadPromise = null;
  let lastError = null;

  function apiKey() {
    return (window.ADMIN_CONFIG && window.ADMIN_CONFIG.yandexMapsApiKey) || '';
  }

  function showMapError(containerEl, message, details) {
    if (!containerEl) return;
    containerEl.innerHTML = `
      <div class="map-error-panel">
        <strong>Карта Яндекса недоступна</strong>
        <p>${message}</p>
        ${details ? `<pre class="map-error-hint">${details}</pre>` : ''}
        <p class="dim">Ключ: JavaScript API (не MapKit). После правок в кабинете подождите ~15 мин и обновите страницу.</p>
      </div>`;
  }

  function loadScript() {
    if (typeof ymaps !== 'undefined') {
      return new Promise((resolve, reject) => {
        try {
          ymaps.ready(() => resolve());
        } catch (e) {
          reject(e);
        }
      });
    }
    if (loadPromise) return loadPromise;

    const key = apiKey();
    if (!key) return Promise.reject(new Error('Yandex Maps API key missing'));

    loadPromise = new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = `https://api-maps.yandex.ru/2.1/?apikey=${encodeURIComponent(key)}&lang=ru_RU`;
      script.async = true;

      const failTimer = setTimeout(() => {
        reject(new Error('Yandex Maps load timeout'));
      }, 20000);

      script.onload = () => {
        if (typeof ymaps === 'undefined') {
          clearTimeout(failTimer);
          reject(new Error('ymaps not defined after script load'));
          return;
        }
        ymaps.ready(() => {
          clearTimeout(failTimer);
          // Invalid key often surfaces only when creating map; probe with minimal map
          resolve();
        });
      };

      script.onerror = () => {
        clearTimeout(failTimer);
        reject(new Error('Failed to load api-maps.yandex.ru'));
      };

      // Capture global ymaps init errors (Invalid API key)
      const prevError = window.onerror;
      window.onerror = (msg, url) => {
        if (String(msg || '').includes('Invalid API key') || String(url || '').includes('api-maps.yandex.ru')) {
          lastError = 'Invalid API key — проверьте ограничения Referer в кабинете Яндекса';
        }
        if (typeof prevError === 'function') return prevError.apply(window, arguments);
        return false;
      };

      document.head.appendChild(script);
    });

    return loadPromise;
  }

  function buildPlacemarks(drivers, orders) {
    const marks = [];

    (drivers || []).forEach((d) => {
      const loc = d.location;
      if (loc?.lat == null || loc?.lng == null) return;
      const name = (d.profile || {}).fullName || d.phone || 'Водитель';
      const st = d.status || 'offline';
      const preset = st === 'online'
        ? 'islands#greenAutoIcon'
        : st === 'busy'
          ? 'islands#orangeAutoIcon'
          : 'islands#grayAutoIcon';

      marks.push({
        coords: [Number(loc.lat), Number(loc.lng)],
        properties: {
          balloonContentHeader: name,
          balloonContentBody: `Статус: ${st}<br/>${d.phone || ''}`,
          iconCaption: String(name).slice(0, 22),
        },
        options: { preset },
      });
    });

    (orders || []).forEach((o) => {
      const from = o.from;
      if (from?.lat == null || from?.lng == null) return;
      marks.push({
        coords: [Number(from.lat), Number(from.lng)],
        properties: {
          balloonContentHeader: `Заказ ${o.id || ''}`,
          balloonContentBody: `${o.fromAddress || '—'} → ${o.toAddress || '—'}<br/>${o.status || ''}`,
          iconCaption: 'Подача',
        },
        options: { preset: 'islands#violetDotIcon' },
      });
    });

    return marks;
  }

  function fitMap(marks) {
    if (!map) return;
    if (!marks.length) {
      map.setCenter(DEFAULT_CENTER, DEFAULT_ZOOM);
      return;
    }
    if (marks.length === 1) {
      map.setCenter(marks[0].coords, 14);
      return;
    }
    const lats = marks.map((m) => m.coords[0]);
    const lngs = marks.map((m) => m.coords[1]);
    map.setBounds(
      [
        [Math.min(...lats), Math.min(...lngs)],
        [Math.max(...lats), Math.max(...lngs)],
      ],
      { checkZoomRange: true, zoomMargin: 48 },
    );
  }

  async function render(containerEl, drivers, orders) {
    if (!containerEl) return false;

    if (lastError) {
      showMapError(
        containerEl,
        lastError,
        'Кабинет → ключ JavaScript API → Ограничения → Домены:\n161.104.19.23\n(одна строка, без http:// и без /admin)',
      );
      return false;
    }

    try {
      await loadScript();
    } catch (err) {
      console.warn('[AdminYandexMap]', err);
      showMapError(
        containerEl,
        err.message || 'Не удалось загрузить API карт',
        'Кабинет → ключ JavaScript API → Ограничения → Домены:\n161.104.19.23',
      );
      return false;
    }

    try {
      if (!map) {
        containerEl.innerHTML = '';
        const mapDiv = document.createElement('div');
        mapDiv.className = 'yandex-map-container';
        mapDiv.setAttribute('role', 'application');
        mapDiv.setAttribute('aria-label', 'Карта водителей и заказов');
        containerEl.appendChild(mapDiv);

        map = new ymaps.Map(mapDiv, {
          center: DEFAULT_CENTER,
          zoom: DEFAULT_ZOOM,
          controls: ['zoomControl', 'fullscreenControl', 'geolocationControl'],
        }, {
          suppressMapOpenBlock: true,
        });

        collection = new ymaps.GeoObjectCollection();
        map.geoObjects.add(collection);
      }

      collection.removeAll();
      const marks = buildPlacemarks(drivers, orders);
      marks.forEach((m) => {
        collection.add(new ymaps.Placemark(m.coords, m.properties, m.options));
      });
      fitMap(marks);
      return true;
    } catch (err) {
      console.warn('[AdminYandexMap] map init', err);
      showMapError(
        containerEl,
        'Invalid API key или ограничения ключа',
        'developer.tech.yandex.ru → JavaScript API → Key #5 →\n'
          + 'Ограничения: в поле «Домены» добавьте\n161.104.19.23\n'
          + 'Либо временно снимите все ограничения для теста.',
      );
      return false;
    }
  }

  function destroy() {
    if (map) {
      map.destroy();
      map = null;
      collection = null;
    }
    loadPromise = null;
    lastError = null;
  }

  return { render, destroy, loadScript };
})();
