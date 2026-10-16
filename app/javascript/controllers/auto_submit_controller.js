import { Controller } from "@hotwired/stimulus"

// Submits its form as soon as a choice is made, like the topic dropdown
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
