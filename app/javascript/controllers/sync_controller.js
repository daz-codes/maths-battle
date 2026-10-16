import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import { preparePlayer, sendUnsentGames, takeRefusedGames, watchPlayer } from "lib/offline_games"

// Coming back to the app after this long reloads the page
const STALE_AFTER = 60_000

// On every page but the game: uploads games played offline, and reloads the page when the app comes back
// after a while, since a home screen app can sit in the background for hours still showing yesterday's streak.
// If the server refused any of those games, it says so, rather than letting them vanish
export default class extends Controller {
  static targets = [ "refused" ]
  static values = { uploadUrl: String, autoRefresh: { type: Boolean, default: true } }

  connect() {
    preparePlayer()
    this.unwatch = watchPlayer()

    this.visibilityChanged = this.visibilityChanged.bind(this)
    this.upload = this.upload.bind(this)
    document.addEventListener("visibilitychange", this.visibilityChanged)
    window.addEventListener("online", this.upload)
    this.showRefused()
    this.upload()
  }

  disconnect() {
    this.unwatch?.()
    document.removeEventListener("visibilitychange", this.visibilityChanged)
    window.removeEventListener("online", this.upload)
  }

  visibilityChanged() {
    if (document.hidden) {
      this.hiddenAt = Date.now()
    } else if (this.hiddenAt && Date.now() - this.hiddenAt >= STALE_AFTER) {
      this.refresh()
    }
  }

  refresh() {
    if (navigator.onLine && this.autoRefreshValue) this.reload()
  }

  // Once games from offline are saved, the streak and stats on this page are out of date
  async upload() {
    if (!navigator.onLine || this.uploading) return

    this.uploading = true
    let saved
    try {
      saved = await sendUnsentGames(this.uploadUrlValue)
    } finally {
      this.uploading = false
    }
    // Reloading shows any refusals on the new page
    saved > 0 && this.autoRefreshValue ? this.reload() : this.showRefused()
  }

  showRefused() {
    const count = takeRefusedGames()
    if (count === 0 || !this.hasRefusedTarget) return

    this.refusedTarget.textContent = count === 1
      ? "Sorry, a game played offline couldn't be saved."
      : `Sorry, ${count} games played offline couldn't be saved.`
    this.refusedTarget.hidden = false
  }

  reload() {
    Turbo.visit(window.location.href, { action: "replace" })
  }

}
