import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// A live game has started: everyone in its lobby goes to it at once
export default class extends Controller {
  static values = { url: String }

  connect() {
    Turbo.visit(this.urlValue)
  }
}
