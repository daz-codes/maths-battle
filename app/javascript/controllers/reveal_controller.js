import { Controller } from "@hotwired/stimulus"

const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)")
const FIRST_AFTER = 400
const EACH_AFTER = 1800
const SPIN_IN = 900
const HOLD = 500
const FLY_BACK = 700
const BIGGEST = 2.2
const CENTRE = "translate(-50%, -50%) perspective(800px)"

// The results page's news, one after another: a new best, level up or stars, then each new award. Each spins in
// big in the middle of the screen, like a coin, then flies back to where it sits. A copy does the spinning, fixed
// to the middle of the screen, so the page settling around it doesn't matter; where the real one sits is
// measured just before the copy flies back to it. Nothing moves for anyone whose device asks for less motion
export default class extends Controller {
  static targets = [ "item" ]

  connect() {
    if (reducedMotion.matches || !this.element.animate) return

    this.timers = this.itemTargets.map((item, i) => {
      item.style.visibility = "hidden"
      return setTimeout(() => this.reveal(item), FIRST_AFTER + i * EACH_AFTER)
    })
  }

  disconnect() {
    this.timers?.forEach(clearTimeout)
    this.copies?.forEach(copy => copy.remove())
    this.itemTargets.forEach(item => { item.style.visibility = "" })
  }

  async reveal(item) {
    const copy = this.copyOf(item)
    // As big as it can be while still fitting across the screen
    const scale = Math.min(BIGGEST, (window.innerWidth * 0.92) / item.offsetWidth)
    await copy.animate([
      { transform: `${CENTRE} rotateY(0deg) scale(0.2)`, opacity: 0 },
      { transform: `${CENTRE} rotateY(720deg) scale(${scale})`, opacity: 1 }
    ], { duration: SPIN_IN, easing: "cubic-bezier(0.2, 0.8, 0.3, 1)", fill: "forwards" }).finished

    await new Promise(resolve => setTimeout(resolve, HOLD))
    const home = item.getBoundingClientRect()
    const x = home.left + home.width / 2 - window.innerWidth / 2
    const y = home.top + home.height / 2 - window.innerHeight / 2
    await copy.animate([
      { transform: `${CENTRE} rotateY(720deg) scale(${scale})`, opacity: 1 },
      { transform: `translate(calc(-50% + ${x}px), calc(-50% + ${y}px)) perspective(800px) rotateY(720deg) scale(1)`, opacity: 0.6 }
    ], { duration: FLY_BACK, easing: "cubic-bezier(0.5, 0, 0.3, 1)", fill: "forwards" }).finished

    item.style.visibility = ""
    copy.remove()
  }

  copyOf(item) {
    const copy = item.cloneNode(true)
    copy.removeAttribute("data-reveal-target")
    copy.removeAttribute("data-controller")
    copy.classList.add("revealing")
    copy.style.width = `${item.offsetWidth}px`
    copy.style.visibility = "visible"
    document.body.append(copy)
    ;(this.copies ||= []).push(copy)
    return copy
  }
}
