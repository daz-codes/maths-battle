import { Controller } from "@hotwired/stimulus"

// Shows a picked picture straight away, before the form is saved
export default class extends Controller {
  static targets = [ "current", "preview" ]

  show(event) {
    const [ file ] = event.target.files
    if (!file) return

    URL.revokeObjectURL(this.previewTarget.src)
    this.previewTarget.src = URL.createObjectURL(file)
    this.previewTarget.hidden = false
    this.currentTarget.hidden = true
  }

  disconnect() {
    URL.revokeObjectURL(this.previewTarget.src)
  }
}
