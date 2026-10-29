import { Controller } from "@hotwired/stimulus"

// The host is playing again: everyone still on the podium or their result joins the next lobby
export default class extends Controller {
  connect() {
    this.element.querySelector("form")?.requestSubmit()
  }
}
