import { Controller } from "@hotwired/stimulus"
import { celebrating } from "lib/celebrations"

const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)")
const FIRST_AFTER = 300
const EACH_AFTER = 650
const POP = 550

// The results page's news, one after another: a new best, level up or stars, then each new award. Each pops up where
// it sits: it fades in from a little below, growing just past its size and settling. Its place is kept while it
// waits, so nothing around it moves. Nothing moves for anyone whose device asks for less motion, or once the result
// has been shown before (lib/celebrations)
export default class extends Controller {
  static targets = [ "item" ]

  connect() {
    if (reducedMotion.matches || !this.element.animate || !celebrating(this.element)) return

    this.timers = this.itemTargets.map((item, i) => {
      item.style.visibility = "hidden"
      return setTimeout(() => this.pop(item), FIRST_AFTER + i * EACH_AFTER)
    })
  }

  disconnect() {
    this.timers?.forEach(clearTimeout)
    this.itemTargets.forEach(item => { item.style.visibility = "" })
  }

  pop(item) {
    item.style.visibility = ""
    item.animate([
      { transform: "translateY(18px) scale(0.6)", opacity: 0 },
      { transform: "translateY(0) scale(1.06)", opacity: 1, offset: 0.65 },
      { transform: "translateY(0) scale(1)", opacity: 1 }
    ], { duration: POP, easing: "cubic-bezier(0.2, 0.8, 0.3, 1)" })
  }
}
