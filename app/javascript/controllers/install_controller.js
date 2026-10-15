import { Controller } from "@hotwired/stimulus"

// The browser fires beforeinstallprompt once per page load, so keep it for whenever the home page connects
let deferredPrompt = null
window.addEventListener("beforeinstallprompt", (event) => {
  event.preventDefault()
  deferredPrompt = event
  document.dispatchEvent(new CustomEvent("install:available"))
})

const installed = () => window.matchMedia("(display-mode: standalone)").matches || navigator.standalone
const iOS = () => /iPad|iPhone|iPod/.test(navigator.userAgent) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1)

export default class extends Controller {
  static targets = [ "button", "ios" ]

  connect() {
    if (installed()) return

    this.available = this.available.bind(this)
    document.addEventListener("install:available", this.available)
    if (deferredPrompt) this.available()
    else if (iOS()) this.show(this.iosTarget)
  }

  disconnect() {
    document.removeEventListener("install:available", this.available)
  }

  available() {
    this.show(this.buttonTarget)
  }

  async install() {
    if (!deferredPrompt) return

    deferredPrompt.prompt()
    await deferredPrompt.userChoice
    deferredPrompt = null
    this.element.hidden = true
  }

  show(target) {
    target.hidden = false
    this.element.hidden = false
  }
}
