import { Controller } from "@hotwired/stimulus"

// The settings page's app settings save as soon as one is changed, staying on the page
export default class extends Controller {
  static targets = [ "status" ]

  async save() {
    this.statusTarget.textContent = "Saving…"
    try {
      const response = await fetch(this.element.action, {
        method: "PATCH",
        headers: { "Accept": "application/json", "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content },
        body: new FormData(this.element)
      })
      this.statusTarget.textContent = response.ok ? "Saved ✓" : "That couldn't be saved. Try again."
    } catch {
      this.statusTarget.textContent = "You're offline, so that couldn't be saved."
    }
  }
}
