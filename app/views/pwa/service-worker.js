// Maths Battle needs a connection, for its leagues and battles, so pages come from the network every time. With
// none, the offline page shows. Assets are fingerprinted, so they're kept once fetched
const CACHE = "mathsbattle-v1"
const OFFLINE_URL = "/offline.html"

self.addEventListener("install", event => {
  event.waitUntil(caches.open(CACHE).then(cache => cache.add(new Request(OFFLINE_URL, { cache: "reload" }))).then(() => self.skipWaiting()))
})

self.addEventListener("activate", event => {
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(key => key !== CACHE).map(key => caches.delete(key))))
      .then(() => self.clients.claim())
  )
})

self.addEventListener("fetch", event => {
  const { request } = event
  const url = new URL(request.url)
  if (url.origin !== self.location.origin) return

  if (request.method === "GET" && url.pathname.startsWith("/assets/")) {
    event.respondWith(assetFromCache(request))
  } else if (request.method === "GET" && request.mode === "navigate") {
    event.respondWith(fetch(request).catch(() => caches.match(OFFLINE_URL, { cacheName: CACHE })))
  }
})

async function assetFromCache(request) {
  const cache = await caches.open(CACHE)
  const cached = await cache.match(request)
  if (cached) return cached
  const response = await fetch(request)
  if (response.ok) await cache.put(request, response.clone()).catch(() => {})
  return response
}
