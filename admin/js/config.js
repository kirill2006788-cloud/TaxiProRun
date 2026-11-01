/**
 * Конфиг админ-панели. Секреты не храните в git — задайте ключ локально:
 *   localStorage.setItem('koroli_yandex_maps_key', 'YOUR_KEY')
 * или скопируйте config.example.js → config.local.js и подключите его в index.html.
 */
(() => {
  const fromStorage = (() => {
    try { return localStorage.getItem('koroli_yandex_maps_key') || ''; } catch { return ''; }
  })();
  const fromWindow = (window.ADMIN_CONFIG_OVERRIDE && window.ADMIN_CONFIG_OVERRIDE.yandexMapsApiKey) || '';
  const provider = (() => {
    try { return localStorage.getItem('koroli_map_provider') || 'auto'; } catch { return 'auto'; }
  })();

  window.ADMIN_CONFIG = {
    /** Yandex JavaScript API key (не MapKit). Пусто → карта через OpenStreetMap/Leaflet. */
    yandexMapsApiKey: fromWindow || fromStorage || '',
    mapProvider: provider, // auto | yandex | leaflet
  };
})();
