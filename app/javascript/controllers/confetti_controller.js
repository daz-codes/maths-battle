import { Controller } from "@hotwired/stimulus"
import confetti from "canvas-confetti"
import { celebrating } from "lib/celebrations"

const COLOURS = [ "#efff2e", "#ff5cc6", "#2be4ff", "#5dff7a" ]

// Celebrates a new high score with bursts from both sides. A big one (beating a best) keeps going: wave after
// wave from the sides, then a shower from the top. Only the first time the result's shown (lib/celebrations)
export default class extends Controller {
  static values = { big: Boolean }

  connect() {
    this.timers = []
    if (!celebrating(this.element)) return

    const burst = (options) => confetti({ colors: COLOURS, disableForReducedMotion: true, ...options })
    const sides = (count) => {
      burst({ particleCount: count, spread: 70, angle: 60, origin: { x: 0, y: 0.7 } })
      burst({ particleCount: count, spread: 70, angle: 120, origin: { x: 1, y: 0.7 } })
    }

    sides(80)
    this.timers = [ setTimeout(() => burst({ particleCount: 120, spread: 100, origin: { y: 0.4 } }), 350) ]
    if (!this.bigValue) return

    this.timers.push(
      setTimeout(() => sides(100), 800),
      setTimeout(() => burst({ particleCount: 200, spread: 160, startVelocity: 35, origin: { y: 0 } }), 1300),
      setTimeout(() => sides(80), 1900)
    )
  }

  disconnect() {
    this.timers.forEach(clearTimeout)
    confetti.reset()
  }
}
