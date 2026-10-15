import { Controller } from "@hotwired/stimulus"
import confetti from "canvas-confetti"

// Celebrates a new high score with bursts from both sides
export default class extends Controller {
  connect() {
    const colors = [ "#efff2e", "#ff5cc6", "#2be4ff", "#5dff7a" ]
    const burst = (x, angle) => confetti({ particleCount: 80, spread: 70, angle, origin: { x, y: 0.7 }, colors, disableForReducedMotion: true })

    burst(0, 60)
    burst(1, 120)
    this.timer = setTimeout(() => confetti({ particleCount: 120, spread: 100, origin: { y: 0.4 }, colors, disableForReducedMotion: true }), 350)
  }

  disconnect() {
    clearTimeout(this.timer)
    confetti.reset()
  }
}
