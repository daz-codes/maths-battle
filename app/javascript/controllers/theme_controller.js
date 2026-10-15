import { Controller } from "@hotwired/stimulus"

// Shows a theme as soon as it's picked, before it's saved
export default class extends Controller {
  preview(event) {
    document.documentElement.dataset.theme = event.target.value
  }
}
