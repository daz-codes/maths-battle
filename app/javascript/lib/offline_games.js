// What the device keeps so games can be played offline: spare question sets, and finished games
// waiting to be uploaded. Storage can be unavailable (private browsing), so every use is guarded
// and the game still works without it, just not offline

const QUEUE_KEY = "matheminute:unsent-games"
const SPARES_KEY = "matheminute:spare-question-sets"
const USED_KEY = "matheminute:used-question-sets"
const MAX_USED = 50

function read(key, fallback) {
  try {
    return JSON.parse(localStorage.getItem(key)) ?? fallback
  } catch {
    return fallback
  }
}

function write(key, value) {
  try {
    localStorage.setItem(key, JSON.stringify(value))
  } catch {
    // Storage full or blocked: nothing more we can do
  }
}

// Question sets

// The page's own set, unless this device has already played it (the page came from the offline
// cache), in which case an unused spare saved from an earlier visit
export function chooseQuestionSet(sets) {
  const used = read(USED_KEY, [])
  const [ pageSet, ...spares ] = sets

  if (!used.includes(pageSet.id)) {
    write(SPARES_KEY, spares)
    return markUsed(pageSet, used)
  }

  const spare = read(SPARES_KEY, []).find(set => !used.includes(set.id))
  return markUsed(spare ?? pageSet, used)
}

function markUsed(set, used) {
  write(USED_KEY, [ ...used, set.id ].slice(-MAX_USED))
  return set
}

// Unsent games

export function newGameId() {
  return crypto.randomUUID?.() ?? `${Date.now()}-${Math.random().toString(16).slice(2)}`
}

export function saveForLater(game) {
  write(QUEUE_KEY, [ ...unsentGames(), game ])
}

export function unsentGames() {
  return read(QUEUE_KEY, [])
}

function forgetGame(id) {
  write(QUEUE_KEY, unsentGames().filter(game => game.client_id !== id))
}

export function forgetEverything() {
  try {
    [ QUEUE_KEY, SPARES_KEY, USED_KEY ].forEach(key => localStorage.removeItem(key))
  } catch {}
}

// Posts a game. Resolves to "saved" (with the results url), "rejected" (the server will never accept it)
// or "failed" (offline or a hiccup: try again later)
export async function postGame(url, game) {
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

    if (response.ok) return { outcome: "saved", url: body?.url }
    // Our own refusal comes as JSON with an error; anything else (like an out-of-date page) is worth retrying
    if (response.status === 422 && body?.error) return { outcome: "rejected" }
    return { outcome: "failed" }
  } catch {
    return { outcome: "failed" }
  }
}

// Uploads every game waiting on this device. Resolves to how many were saved
export async function sendUnsentGames(url) {
  let saved = 0

  for (const game of unsentGames()) {
    const { outcome } = await postGame(url, game)
    if (outcome === "failed") break

    forgetGame(game.client_id)
    if (outcome === "saved") saved++
  }
  return saved
}
