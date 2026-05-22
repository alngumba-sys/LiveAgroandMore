// Agro and More — minimal service worker
// Strategy:
//   - HTML navigations & app.html / index.html → network-first (always pick up
//     new deploys without users having to bump anything). Falls back to cache
//     when offline.
//   - Everything else (images, fonts, JSON, brand assets) → cache-first.
//   - On every new-SW activation: claim all open clients AND force them to
//     reload, so updates land without users needing to hard-refresh.
// Bump CACHE_VERSION when you change the SHELL list or want to force-clear
// every cached entry (e.g., after a bad deploy).

const CACHE_VERSION = 'agmore-v39';
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
  event.waitUntil((async () => {
    /* 1) Delete stale caches from prior versions. */
    const keys = await caches.keys();
    await Promise.all(keys.filter(k => k !== CACHE_VERSION).map(k => caches.delete(k)));

    /* 2) Take control of every open page right away. */
    await self.clients.claim();

    /* 3) Reload every visible window so they pick up the fresh JS.
       This is what makes "ship a new version" feel instant — the user
       doesn't have to know about hard-refresh. We only do this if at
       least one prior cache existed (i.e., this isn't the user's first
       ever install — that's already on the new version). */
    const hadOldCache = keys.some(k => k !== CACHE_VERSION);
    if (hadOldCache) {
      const clients = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
      for (const client of clients) {
        try { await client.navigate(client.url); } catch (_) { /* navigate may fail on iframes */ }
      }
    }
  })());
});

/* Allow the app to ask the SW to update + activate immediately on user demand
   (used by the "An update is available — tap to refresh" toast in app.html). */
self.addEventListener('message', (event) => {
  if (event.data === 'SKIP_WAITING') self.skipWaiting();
});

/* Treat HTML navigations and the two app shell files as network-first so a
   new deploy reaches users on next page load — no need to bump CACHE_VERSION
   for every code change. */
function isHtmlRequest(req) {
  if (req.mode === 'navigate') return true;
  const url = new URL(req.url);
  if (url.pathname.endsWith('.html')) return true;
  if (url.pathname === '/' || url.pathname.endsWith('/')) return true;
  return false;
}

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;

  if (isHtmlRequest(req)) {
    /* Network-first for HTML: try the network, update the cache on success,
       fall back to cache only if offline / network errors. */
    event.respondWith(
      fetch(req).then((res) => {
        if (res && res.status === 200 && res.type === 'basic') {
          const copy = res.clone();
          caches.open(CACHE_VERSION).then((cache) => cache.put(req, copy));
        }
        return res;
      }).catch(() =>
        caches.match(req).then((cached) => cached || caches.match('./index.html'))
      )
    );
    return;
  }

  /* Cache-first for static assets (images, fonts, manifest, icons). */
  event.respondWith(
    caches.match(req).then((cached) => {
      if (cached) return cached;
      return fetch(req).then((res) => {
        if (res && res.status === 200 && res.type === 'basic') {
          const copy = res.clone();
          caches.open(CACHE_VERSION).then((cache) => cache.put(req, copy));
        }
        return res;
      }).catch(() => caches.match('./index.html'));
    })
  );
});
