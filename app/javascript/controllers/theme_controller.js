import { Controller } from "@hotwired/stimulus"

// Apply saved preferences after Turbo navigation and preview changes before autosave completes.
// Keeping each meta tag's media query lets system mode follow device changes without a reload.
export default class extends Controller {
  static values = { preference: String }

  connect() {
    if (this.hasPreferenceValue) this.apply(this.preferenceValue)
  }

  preview(event) {
    this.apply(event.target.value)
  }

  apply(preference) {
    document.documentElement.dataset.theme = preference
    const colours = [...document.querySelectorAll("meta[data-theme-color]")]
    for (const meta of colours) {
      const scheme = preference === "system" ? meta.dataset.themeColor : preference
      meta.content = colours.find(colour => colour.dataset.themeColor === scheme)?.dataset.color || meta.dataset.color
    }
  }
}
