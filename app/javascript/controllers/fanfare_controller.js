import { Controller } from "@hotwired/stimulus"
import { fanfare } from "lib/feedback"

// A fanfare for a level up, as its banner shows
export default class extends Controller {
  connect() {
    fanfare()
  }
}
