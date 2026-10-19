// Personalized pages belong to the player identified by the server. Identity updates and cache writes
// are serialized so a late response cannot restore the previous player's pages after sign out.
const CACHE = "matheminute-v6"
const PAGES = "matheminute-pages-v4-"
const STATE = "matheminute-player-v1"
const OFFLINE_URL = "/offline.html"
const PLAYER_URL = "/offline-player"
let updates = Promise.resolve()

self.addEventListener("install", event => {
  event.waitUntil(caches.open(CACHE).then(cache => cache.add(OFFLINE_URL)).then(() => self.skipWaiting()))
})

self.addEventListener("activate", event => {
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(key => key !== CACHE && key !== STATE && !key.startsWith(PAGES)).map(key => caches.delete(key))))
      .then(() => self.clients.claim())
  )
})

self.addEventListener("fetch", event => {
  const { request } = event
  const url = new URL(request.url)
  if (url.origin !== self.location.origin) return

  if (request.method === "GET" && url.pathname.startsWith("/assets/")) {
    event.respondWith(assetFromCache(request))
  } else {
    event.respondWith(fromNetwork(request, url))
  }
})

function isPage(request) {
  return request.mode === "navigate" || (request.headers.get("Accept") || "").includes("text/html")
}

function keptForOffline(path) {
  return path === "/" || path.startsWith("/play/") || path === "/stats" || path.startsWith("/stats/") || path === "/achievements"
}

async function playerState() {
  return (await (await caches.open(STATE)).match(PLAYER_URL))?.json()
}

async function rememberPlayer(response, request, url) {
  const key = response.headers.get("X-Player-Key")
  const version = Number(response.headers.get("X-Player-Version"))
  if (!key || !version) return

  updates = updates.catch(() => {}).then(async () => {
    const previous = await playerState()
    if (previous && version < previous.version) return
    if (previous?.key !== key) {
      await Promise.all((await caches.keys()).filter(name => name.startsWith(PAGES)).map(name => caches.delete(name)))
    }
    const state = { key, version, expires: response.headers.get("X-Player-Expires") }
    await (await caches.open(STATE)).put(PLAYER_URL, new Response(JSON.stringify(state)))
    // A redirect's page isn't the one asked for: a new player's home goes to the topics page
    if (request.method === "GET" && isPage(request) && response.ok && !response.redirected && keptForOffline(url.pathname)) {
      await (await caches.open(PAGES + key)).put(url.pathname + url.search, response.clone())
    }
  })
  await updates
}

async function fromNetwork(request, url) {
  let response
  try {
    response = await fetch(request)
  } catch (error) {
    if (request.method !== "GET" || !isPage(request)) throw error
    await updates.catch(() => {})
    const player = await playerState()
    if (player && Date.parse(player.expires) > Date.now()) {
      const kept = await caches.match(url.pathname + url.search, { cacheName: PAGES + player.key })
      if (kept) return kept
    }
    return caches.match(OFFLINE_URL, { cacheName: CACHE })
  }
  // Cache failures must not turn a successful POST into an apparent network failure.
  await rememberPlayer(response, request, url).catch(() => {})
  return response
}

async function assetFromCache(request) {
  const cache = await caches.open(CACHE)
  const cached = await cache.match(request)
  if (cached) return cached
  const response = await fetch(request)
  if (response.ok) await cache.put(request, response.clone()).catch(() => {})
  return response
}
