import { Controller } from "@hotwired/stimulus"

// Setting a group challenge: the level menu names the levels of the topic chosen. Every topic has its levels
// numbered from 1, then a mixed option, so changing topic keeps the choice and just renames the levels
export default class extends Controller {
  static targets = [ "level" ]
  static values = { names: Object }

  update(event) {
    const names = this.namesValue[event.target.value] ?? []
    for (const option of this.levelTarget.options) {
      const number = Number(option.value)
      if (number) option.textContent = names[number - 1] ? `Level ${number}: ${names[number - 1]}` : `Level ${number}`
    }
  }
}
