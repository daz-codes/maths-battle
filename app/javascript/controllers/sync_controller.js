import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import { forgetEverything, sendUnsentGames } from "lib/offline_games"

// Coming back to the app after this long reloads the page
const STALE_AFTER = 60_000

// On every page but the game: uploads games played offline, and reloads the page when the app comes back
// after a while, since a home screen app can sit in the background for hours still showing yesterday's streak
export default class extends Controller {
  static values = { uploadUrl: String, autoRefresh: { type: Boolean, default: true } }

  connect() {
    this.visibilityChanged = this.visibilityChanged.bind(this)
    this.upload = this.upload.bind(this)
    document.addEventListener("visibilitychange", this.visibilityChanged)
    window.addEventListener("online", this.upload)
    this.upload()
  }

  disconnect() {
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
    const saved = await sendUnsentGames(this.uploadUrlValue)
    this.uploading = false
    if (saved > 0) this.reload()
  }

  reload() {
    Turbo.visit(window.location.href, { action: "replace" })
  }

  // Signing out: nothing of this player's should stay on the device for the next one
  forget() {
    forgetEverything()
    navigator.serviceWorker?.controller?.postMessage("forget-pages")
  }
}
