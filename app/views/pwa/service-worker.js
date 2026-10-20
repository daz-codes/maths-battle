// Personalized pages belong to the player identified by the server. Identity updates and cache writes
// are serialized so a late response cannot restore the previous player's pages after sign out.
const CACHE = "matheminute-v6"
const PAGES = "matheminute-pages-v4-"
const STATE = "matheminute-player-v1"
const OFFLINE_URL = "/offline.html"
const PLAYER_URL = "/offline-player"
let updates = Promise.resolve()
// A phone can stall a download or a cache write indefinitely: on a connection that's there but not working,
// or when the app is closed part way through. Nothing waits on either for longer than this, or the app opens to
// nothing. A page with a copy kept for offline (home, games, stats) gives way to it quickly, so the app opens
// even then; one without waits longer before the offline page. A copy that's slow to keep is given up on
const TIMEOUTS = { withCopy: 3_000, network: 10_000, keeping: 3_000 }
const TIMED_OUT = Symbol("timed out")

function within(promise, ms) {
  let timer
  const timeout = new Promise(resolve => { timer = setTimeout(() => resolve(TIMED_OUT), ms) })
  return Promise.race([ promise, timeout ]).finally(() => clearTimeout(timer))
}

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

// A daily reminder from the server (User::Remindable). A push always shows something, as browsers expect
self.addEventListener("push", event => {
  const { title = "MatheMinute", body = "Your daily challenge is ready.", url = "/" } = event.data?.json() ?? {}
  event.waitUntil(self.registration.showNotification(title, { body, icon: "/icon-192.png", tag: "daily-reminder", data: { url } }))
})

// Tapping it opens the app, or brings it forward if it's already open
self.addEventListener("notificationclick", event => {
  event.notification.close()
  const url = new URL(event.notification.data?.url || "/", self.location.origin).href
  event.waitUntil(self.clients.matchAll({ type: "window", includeUncontrolled: true }).then(windows => {
    const open = windows.find(client => new URL(client.url).origin === self.location.origin)
    return open ? open.focus() : self.clients.openWindow(url)
  }))
})

function isPage(request) {
  return request.mode === "navigate" || (request.headers.get("Accept") || "").includes("text/html")
}

function keptForOffline(path) {
  return path === "/" || path.startsWith("/play/") || path === "/stats" || path.startsWith("/stats/") || path === "/awards"
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
      await within((await caches.open(PAGES + key)).put(url.pathname + url.search, response.clone()), TIMEOUTS.keeping)
    }
  })
  await updates
}

// This player's copy of the page, unless their session has run out
async function keptCopy(url) {
  const player = await playerState()
  if (!player || Date.parse(player.expires) <= Date.now()) return null

  return caches.match(url.pathname + url.search, { cacheName: PAGES + player.key })
}

async function fromNetwork(request, url) {
  const page = request.method === "GET" && isPage(request)
  let response
  try {
    if (page) {
      const waitFor = await keptCopy(url) ? TIMEOUTS.withCopy : TIMEOUTS.network
      response = await within(fetch(request), waitFor)
      if (response === TIMED_OUT) throw new Error("The page took too long")
    } else {
      response = await fetch(request)
    }
  } catch (error) {
    if (!page) throw error
    await within(updates.catch(() => {}), TIMEOUTS.keeping)
    return await keptCopy(url) || caches.match(OFFLINE_URL, { cacheName: CACHE })
  }
  // Cache failures must not turn a successful POST into an apparent network failure.
  await within(rememberPlayer(response, request, url).catch(() => {}), TIMEOUTS.keeping)
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
