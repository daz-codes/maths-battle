import { Controller } from "@hotwired/stimulus"
import { right } from "lib/feedback"

// The settings page's sounds switch takes effect straight away, with a tick to show they're on
export default class extends Controller {
  preview(event) {
    document.documentElement.dataset.sounds = event.target.value === "true" ? "on" : "off"
    right()
  }
}
