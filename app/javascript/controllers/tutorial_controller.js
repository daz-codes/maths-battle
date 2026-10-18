import { Controller } from "@hotwired/stimulus"
import { finished, shown, typedWith } from "lib/answer_input"

const WRONG_PAUSE = 900

// A level's tutorial: tap Next through the worked example, then type an answer to the one to try, with the
// game's keypad. Nothing is saved; it's just for learning
export default class extends Controller {
  static targets = [ "step", "try", "done", "dot", "next", "hint", "hintButton", "answer", "feedback", "keypadArea" ]
  static values = { answer: String, keys: Array }

  connect() {
    this.index = 0
    this.typed = ""
    this.keydown = this.keydown.bind(this)
    document.addEventListener("keydown", this.keydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.keydown)
    clearTimeout(this.wrongTimer)
  }

  next() {
    this.stepTargets[this.index].hidden = true
    this.index++
    this.markDot(this.index)

    if (this.index < this.stepTargets.length) {
      this.stepTargets[this.index].hidden = false
    } else {
      this.startTrying()
    }
  }

  startTrying() {
    this.trying = true
    this.tryTarget.hidden = false
    this.nextTarget.hidden = true
    this.hintButtonTarget.hidden = false
    this.keypadAreaTarget.hidden = false
  }

  showHint() {
    this.hintTarget.hidden = false
    this.hintButtonTarget.hidden = true
  }

  // Typing, with the keypad or a keyboard

  tap(event) {
    event.preventDefault()
    const digit = event.currentTarget.dataset.digit
    digit === "back" ? this.backspace() : this.type(digit)
  }

  keydown(event) {
    if (!this.trying || event.metaKey || event.ctrlKey || event.altKey) return

    if (/^[0-9]$/.test(event.key) || this.keysValue.includes(event.key)) {
      event.preventDefault()
      this.type(event.key)
    } else if (event.key === "Backspace") {
      event.preventDefault()
      this.backspace()
    }
  }

  type(key) {
    const typed = typedWith(this.typed, key, this.keysValue)
    if (!this.trying || this.waiting || typed === null) return

    this.typed = typed
    this.answerTarget.textContent = shown(this.typed)
    if (this.typed.length >= this.answerValue.length && finished(this.typed)) this.check()
  }

  backspace() {
    if (!this.trying || this.waiting) return

    this.typed = this.typed.slice(0, -1)
    this.answerTarget.textContent = shown(this.typed)
  }

  // Right finishes the lesson. Wrong says so, shows the hint, and lets them have another go
  check() {
    if (this.typed === this.answerValue) return this.finish()

    this.waiting = true
    this.feedbackTarget.textContent = "Not quite. Have another go!"
    this.answerTarget.classList.add("answer--wrong")
    this.showHint()
    this.wrongTimer = setTimeout(() => {
      this.waiting = false
      this.typed = ""
      this.answerTarget.textContent = ""
      this.answerTarget.classList.remove("answer--wrong")
    }, WRONG_PAUSE)
  }

  finish() {
    this.trying = false
    this.tryTarget.hidden = true
    this.hintButtonTarget.hidden = true
    this.keypadAreaTarget.hidden = true
    this.doneTarget.hidden = false
    this.markDot(this.dotTargets.length - 1)
  }

  markDot(index) {
    this.dotTargets[index]?.classList.add("lesson__dot--done")
  }
}
