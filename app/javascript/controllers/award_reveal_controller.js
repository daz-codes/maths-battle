import { Controller } from "@hotwired/stimulus"

const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)")
const FIRST_AFTER = 400
const EACH_AFTER = 1800
const SPIN_IN = 900
const HOLD = 500
const FLY_BACK = 700
const CENTRE = "translate(-50%, -50%) perspective(800px)"

// Each award a game earned spins in big in the middle of the screen, like a coin, then flies back to where it
// sits in the list, one after another. A copy does the spinning, fixed to the middle of the screen, so the page
// settling around it doesn't matter; where the award sits is measured just before the copy flies back to it
export default class extends Controller {
  static targets = [ "award" ]

  connect() {
    if (reducedMotion.matches || !this.element.animate) return

    this.timers = this.awardTargets.map((award, i) => {
      award.style.visibility = "hidden"
      return setTimeout(() => this.reveal(award), FIRST_AFTER + i * EACH_AFTER)
    })
  }

  disconnect() {
    this.timers?.forEach(clearTimeout)
    this.copies?.forEach(copy => copy.remove())
    this.awardTargets.forEach(award => { award.style.visibility = "" })
  }

  async reveal(award) {
    const copy = this.copyOf(award)
    await copy.animate([
      { transform: `${CENTRE} rotateY(0deg) scale(0.2)`, opacity: 0 },
      { transform: `${CENTRE} rotateY(720deg) scale(2.2)`, opacity: 1 }
    ], { duration: SPIN_IN, easing: "cubic-bezier(0.2, 0.8, 0.3, 1)", fill: "forwards" }).finished

    await new Promise(resolve => setTimeout(resolve, HOLD))
    const home = award.getBoundingClientRect()
    const x = home.left + home.width / 2 - window.innerWidth / 2
    const y = home.top + home.height / 2 - window.innerHeight / 2
    await copy.animate([
      { transform: `${CENTRE} rotateY(720deg) scale(2.2)`, opacity: 1 },
      { transform: `translate(calc(-50% + ${x}px), calc(-50% + ${y}px)) perspective(800px) rotateY(720deg) scale(1)`, opacity: 0.6 }
    ], { duration: FLY_BACK, easing: "cubic-bezier(0.5, 0, 0.3, 1)", fill: "forwards" }).finished

    award.style.visibility = ""
    copy.remove()
  }

  copyOf(award) {
    const copy = award.cloneNode(true)
    copy.removeAttribute("data-award-reveal-target")
    copy.classList.add("badge--flying")
    copy.style.width = `${award.offsetWidth}px`
    copy.style.visibility = "visible"
    document.body.append(copy)
    ;(this.copies ||= []).push(copy)
    return copy
  }
}
