// Agro and More — minimal service worker
// Cache-first for the shell, network-falling-back-to-cache for everything else.
// Bump CACHE_VERSION when you push a new build to force clients to refresh.

const CACHE_VERSION = 'agmore-v15';
const SHELL = [
  './',
  './index.html',
  './app.html',
  './manifest.json',
  './icons/icon-192.png',
  './icons/icon-512.png',
  './brand/agmore-full.png',
  './brand/agmore-wordmark.png'
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_VERSION).then((cache) => cache.addAll(SHELL)).then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k !== CACHE_VERSION).map((k) => caches.delete(k)))
    ).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;
  event.respondWith(
    caches.match(req).then((cached) => {
      if (cached) return cached;
      return fetch(req).then((res) => {
        // Cache successful, same-origin, basic responses opportunistically.
        if (res && res.status === 200 && res.type === 'basic') {
          const copy = res.clone();
          caches.open(CACHE_VERSION).then((cache) => cache.put(req, copy));
        }
        return res;
      }).catch(() => caches.match('./index.html'));
    })
  );
});
