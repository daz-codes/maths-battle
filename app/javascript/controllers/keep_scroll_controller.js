import { Controller } from "@hotwired/stimulus"

const KEY = "mathsbattle:keep-scroll"

// Picking a level loads the page again, which Turbo shows from the top. This keeps the player where they
// were: the position is noted as the form goes, and put back once the new page has loaded (and scrolled)
export default class extends Controller {
  remember() {
    try { sessionStorage.setItem(KEY, String(window.scrollY)) } catch {}
  }
}

addEventListener("turbo:load", () => {
  let kept
  try {
    kept = sessionStorage.getItem(KEY)
    sessionStorage.removeItem(KEY)
  } catch {}
  if (kept) window.scrollTo(0, Number(kept))
})
