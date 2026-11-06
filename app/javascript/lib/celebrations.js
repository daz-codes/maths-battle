// Celebrations (confetti, the fanfare, spinning banners) play once for each result on a device: the first time it's
// shown, not again when the app reopens on the page or it's visited later. A page marks what it celebrates with
// data-celebration-id; with nothing marked, or no storage, it celebrates
const KEY = "mathsbattle:celebrated"
const KEPT = 300

export function celebrating(element) {
  const page = element.closest("[data-celebration-id]")
  if (!page) return true

  page.dataset.celebration ??= firstTime(page.dataset.celebrationId) ? "new" : "seen"
  return page.dataset.celebration === "new"
}

function firstTime(id) {
  try {
    const seen = JSON.parse(localStorage.getItem(KEY) || "[]")
    if (seen.includes(id)) return false

    localStorage.setItem(KEY, JSON.stringify([ ...seen, id ].slice(-KEPT)))
    return true
  } catch {
    return true
  }
}
