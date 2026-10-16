// Lets MatheMinute open and be played offline.
// Pages always come from the network when there is one, so they're never stale online. The home page,
// each topic's game and stats pages are kept each time they load, so they open offline, and the game page carries spare
// question sets for offline games. Assets are fingerprinted, so they're kept and served from here.
const CACHE = "matheminute-v5"
const PAGES = "matheminute-pages-v2"
const OFFLINE_URL = "/offline.html"

self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.add(OFFLINE_URL)).then(() => self.skipWaiting()))
})

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((key) => ![ CACHE, PAGES ].includes(key)).map((key) => caches.delete(key))))
      .then(() => self.clients.claim())
  )
})

// Signing out: drop the kept pages, which show that player's streak and stats
self.addEventListener("message", (event) => {
  if (event.data === "forget-pages") event.waitUntil(caches.delete(PAGES))
})

self.addEventListener("fetch", (event) => {
  const { request } = event
  const url = new URL(request.url)
  if (request.method !== "GET" || url.origin !== self.location.origin) return

  if (isPage(request)) {
    event.respondWith(pageFromNetwork(request, url))
  } else if (url.pathname.startsWith("/assets/")) {
    event.respondWith(assetFromCache(request))
  }
})

function keptForOffline(path) {
  return path === "/" || path.startsWith("/play/") || path === "/stats" || path.startsWith("/stats/")
}

// Full page loads, and Turbo's page fetches when moving between pages
function isPage(request) {
  return request.mode === "navigate" || (request.headers.get("Accept") || "").includes("text/html")
}

async function pageFromNetwork(request, url) {
  try {
    const response = await fetch(request)
    if (response.ok && keptForOffline(url.pathname)) {
      const copy = response.clone()
      caches.open(PAGES).then((cache) => cache.put(url.pathname, copy))
    }
    return response
  } catch {
    return (await caches.match(url.pathname, { cacheName: PAGES })) || caches.match(OFFLINE_URL)
  }
}

async function assetFromCache(request) {
  const cached = await caches.match(request)
  if (cached) return cached

  const response = await fetch(request)
  if (response.ok) {
    const copy = response.clone()
    caches.open(CACHE).then((cache) => cache.put(request, copy))
  }
  return response
}
