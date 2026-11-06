import { Controller } from "@hotwired/stimulus"
import { Turbo, cable } from "@hotwired/turbo-rails"

// While the Find a match page is open its player is looking (MatchmakingChannel). Matched, they go straight to the
// battle; closing the page stops looking. It says it's still here now and then, so it keeps its place
const STILL_HERE_EVERY = 30_000

export default class extends Controller {
  static targets = [ "status", "count" ]
  static values = { playUrl: String }

  connect() {
    cable.subscribeTo({ channel: "MatchmakingChannel" }, { received: (data) => this.received(data) })
      .then((subscription) => { this.disconnected ? subscription.unsubscribe() : this.subscription = subscription })
    this.timer = setInterval(() => this.subscription?.perform("waiting"), STILL_HERE_EVERY)
  }

  disconnect() {
    this.disconnected = true
    clearInterval(this.timer)
    this.subscription?.unsubscribe()
  }

  received(data) {
    if (data.type === "matched") {
      this.statusTarget.textContent = "Matched! Get ready…"
      Turbo.visit(`${this.playUrlValue}?live=${encodeURIComponent(data.code)}`)
    } else if (data.type === "waiting") {
      this.countTarget.textContent = `${data.count} ${data.count === 1 ? "player" : "players"} looking right now`
    }
  }
}
