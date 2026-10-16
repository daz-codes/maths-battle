// What the device keeps so games can be played offline: spare question sets, and finished games
// waiting to be uploaded. Storage can be unavailable (private browsing), so every use is guarded
// and the game still works without it, just not offline

const QUEUE_KEY = "matheminute:unsent-games"
const SPARES_KEY = "matheminute:spare-question-sets"
const USED_KEY = "matheminute:used-question-sets"
// How many unsent games the server refused, kept until the player has been told
const REFUSED_KEY = "matheminute:refused-games"
// Spares are kept for this many topic and level pairs, the ones visited most recently
const MAX_SPARE_GAMES = 4
const ACTIVE_PLAYER_KEY = "matheminute:active-player"
const ACTIVE_VERSION_KEY = "matheminute:player-version"

export function playerKey() {
  return document.querySelector('meta[name="player-key"]')?.content
}

function keyFor(key, player = playerKey()) {
  return `${key}:${player}`
}

// Old unowned data cannot safely be assigned to whoever signs in next. Every new queue is owned,
// and other tabs check the active player before sending anything.
export function preparePlayer() {
  const player = playerKey()
  try {
    const version = Number(document.querySelector('meta[name="player-version"]')?.content || 0)
    if (version < Number(localStorage.getItem(ACTIVE_VERSION_KEY) || 0)) return
    localStorage.setItem(ACTIVE_PLAYER_KEY, player)
    localStorage.setItem(ACTIVE_VERSION_KEY, String(version))
    for (const key of Object.keys(localStorage)) {
      if ([QUEUE_KEY, SPARES_KEY, USED_KEY, REFUSED_KEY].some(prefix => key === prefix || (key.startsWith(`${prefix}:`) && key !== keyFor(prefix, player)))) {
        localStorage.removeItem(key)
      }
    }
  } catch {}
}

function currentPlayer(player) {
  try {
    const active = localStorage.getItem(ACTIVE_PLAYER_KEY)
    const storedVersion = Number(localStorage.getItem(ACTIVE_VERSION_KEY) || 0)
    const version = Number(document.querySelector('meta[name="player-version"]')?.content || 0)
    return player === playerKey() && version >= storedVersion && (!active || active === player || version > storedVersion)
  } catch {
    return player === playerKey()
  }
}

// Another tab can sign out or change accounts while this page is still open. Hide its old private
// content immediately and navigate with the current cookies; a game must stop before navigating.
export function watchPlayer(onChange = () => {}) {
  const player = playerKey()
  let changed = false
  const check = () => {
    if (changed || currentPlayer(player)) return
    changed = true
    onChange()
    document.body.hidden = true
    window.location.replace("/")
  }
  window.addEventListener("storage", check)
  document.addEventListener("visibilitychange", check)
  check()
  return () => {
    window.removeEventListener("storage", check)
    document.removeEventListener("visibilitychange", check)
  }
}

function read(key, fallback) {
  try {
    return JSON.parse(localStorage.getItem(keyFor(key))) ?? fallback
  } catch {
    return fallback
  }
}

function write(key, value) {
  try {
    localStorage.setItem(keyFor(key), JSON.stringify(value))
    return true
  } catch {
    return false
  }
}

// Question sets

// The page's own set, unless this device has already played it (the page came from the offline
// cache), in which case an unused spare saved from an earlier visit to the same game. Spares are kept
// for each topic and level, as the server only accepts a game's questions from its own topic and level
export function chooseQuestionSet(sets, game) {
  const used = read(USED_KEY, [])
  const spares = keptSpares()
  const [ pageSet, ...pageSpares ] = sets

  if (!used.includes(pageSet.id)) {
    keepSpares(spares, game, pageSpares)
    return markUsed(pageSet, used)
  }

  const spare = (spares[game] ?? []).find(set => !used.includes(set.id))
  return spare ? markUsed(spare, used) : null
}

// Devices that played before spares were kept per game have a plain list, which is dropped
function keptSpares() {
  const spares = read(SPARES_KEY, {})
  return Array.isArray(spares) ? {} : spares
}

function keepSpares(spares, game, sets) {
  const { [game]: _replaced, ...others } = spares
  write(SPARES_KEY, Object.fromEntries([ ...Object.entries(others), [ game, sets ] ].slice(-MAX_SPARE_GAMES)))
}

function markUsed(set, used) {
  write(USED_KEY, [ ...used, set.id ])
  return set
}

// Unsent games

export function saveForLater(game) {
  if (!currentPlayer(game.player_key)) return false
  return write(QUEUE_KEY, [ ...unsentGames(), game ])
}

export function unsentGames() {
  const games = read(QUEUE_KEY, [])
  return Array.isArray(games) ? games : []
}

function forgetGame(id) {
  write(QUEUE_KEY, unsentGames().filter(game => game.client_id !== id))
}

export function forgetEverything() {
  try {
    for (const key of Object.keys(localStorage)) {
      if (key.startsWith("matheminute:")) localStorage.removeItem(key)
    }
  } catch {}
}

// Posts a game. Resolves to "saved" (with the results url), "rejected" (the server will never accept it)
// or "failed" (offline or a hiccup: try again later)
export async function postGame(url, game) {
  if (!currentPlayer(game.player_key)) return { outcome: "rejected" }
  try {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content
      },
      body: JSON.stringify({ attempt: game })
    })
    const body = await response.json().catch(() => null)

    if (response.ok && body?.url) return { outcome: "saved", url: body.url }
    // Our own refusal comes as JSON with an error; anything else (like an out-of-date page) is worth retrying
    if (response.status === 422 && body?.error) return { outcome: "rejected" }
    return { outcome: "failed" }
  } catch {
    return { outcome: "failed" }
  }
}

// Uploads every game waiting on this device. Resolves to how many were saved. A game the server refuses
// will never be accepted, so it's dropped, and counted so the player can be told
export async function sendUnsentGames(url) {
  let saved = 0

  for (const game of unsentGames()) {
    if (!currentPlayer(game.player_key)) break
    const { outcome } = await postGame(url, game)
    if (!currentPlayer(game.player_key)) break
    if (outcome === "failed") break

    forgetGame(game.client_id)
    if (outcome === "saved") saved++
    if (outcome === "rejected") write(REFUSED_KEY, refusedGames() + 1)
  }
  return saved
}

// How many games were refused since the player was last told, forgetting them now they're being told
export function takeRefusedGames() {
  const count = refusedGames()
  try {
    localStorage.removeItem(keyFor(REFUSED_KEY))
  } catch {}
  return count
}

function refusedGames() {
  return read(REFUSED_KEY, 0)
}
