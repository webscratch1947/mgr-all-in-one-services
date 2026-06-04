const CACHE_NAME = 'mgr-app-v2';
const APP_SHELL = [
  '/',
  '/index.html',
  '/app.html',
  '/manifest.webmanifest',
  '/favicon.png'
];

// These files must NEVER be cached — they contain live keys injected at deploy time
const NEVER_CACHE = ['/_config.js', '_config.js'];

function shouldSkipCache(url) {
  try {
    const path = new URL(url).pathname;
    return NEVER_CACHE.some(nc => path === nc || path.endsWith('/_config.js'));
  } catch(e) { return false; }
}

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(APP_SHELL)).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key)))
    ).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;

  // Always fetch _config.js fresh from network — never serve from cache
  if (shouldSkipCache(event.request.url)) {
    event.respondWith(
      fetch(event.request, { cache: 'no-store' }).catch(() => new Response('window.__MGR_CFG__={};', { headers: { 'Content-Type': 'application/javascript' } }))
    );
    return;
  }

  event.respondWith(
    caches.match(event.request).then((cached) => {
      if (cached) return cached;
      return fetch(event.request).then((response) => {
        const copy = response.clone();
        caches.open(CACHE_NAME).then((cache) => cache.put(event.request, copy));
        return response;
      }).catch(() => caches.match('/app.html'));
    })
  );
});
