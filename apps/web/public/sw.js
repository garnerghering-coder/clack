// Offline app shell (docs/RELIABILITY_PLAN.md §4). Network first, always: with a connection you get the current app;
// without one, the copy kept from last time, so Clack still opens in a tunnel. Trip data isn't handled here — the app
// keeps it itself (src/offline.ts) and decides what counts as live. Service workers only run on https or localhost.
const CACHE = 'clack-shell-v1';

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (e) => e.waitUntil(self.clients.claim()));

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;
  // Live data, streams and map tiles read in pieces go straight to the network.
  if (url.pathname.startsWith('/api/') || req.headers.get('range') || (req.headers.get('accept') ?? '').includes('text/event-stream')) return;
  e.respondWith(networkFirst(req));
});

async function networkFirst(req) {
  const cache = await caches.open(CACHE);
  try {
    const res = await fetch(req);
    if (res.ok && res.type === 'basic') {
      void cache.put(req, res.clone());
      // Any page of the app is the same page; keep it under "/" too, for opening a different one offline.
      if (req.mode === 'navigate') void cache.put('/', res.clone());
    }
    return res;
  } catch (err) {
    const hit = (await cache.match(req)) ?? (req.mode === 'navigate' ? await cache.match('/') : undefined);
    if (hit) return hit;
    throw err;
  }
}
