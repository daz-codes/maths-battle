import { Controller } from "@hotwired/stimulus"

// Shares a result with the phone's share sheet, or copies it where there isn't one
export default class extends Controller {
  static values = { text: String }

  async share() {
    if (navigator.share) {
      try {
        await navigator.share({ text: this.textValue })
        return
      } catch (error) {
        if (error.name === "AbortError") return
      }
    }

    await this.copy()
    this.confirm("Copied!")
  }

  async copy() {
    try {
      await navigator.clipboard.writeText(this.textValue)
    } catch {
      // The clipboard API needs a secure context, so fall back to the old way
      const textarea = Object.assign(document.createElement("textarea"), { value: this.textValue })
      textarea.style.position = "fixed"
      textarea.style.opacity = "0"
      document.body.append(textarea)
      textarea.select()
      document.execCommand("copy")
      textarea.remove()
    }
  }

  confirm(message) {
    this.label ??= this.element.textContent
    this.element.textContent = message
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.element.textContent = this.label, 2000)
  }

  disconnect() {
    clearTimeout(this.timer)
  }
}
