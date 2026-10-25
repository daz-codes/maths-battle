import { Controller } from "@hotwired/stimulus"
import { fanfare } from "lib/feedback"
import { celebrating } from "lib/celebrations"

// A fanfare for a level up, as its banner shows, the first time it's shown (lib/celebrations)
export default class extends Controller {
  connect() {
    if (celebrating(this.element)) fanfare()
  }
}
