import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

const DURATION = 60_000
const WRONG_PAUSE = 400
// Each quarter of the clock ring is 23 of 100 units long, leaving small gaps between them
const QUARTER_LENGTH = 23
const COUNTDOWN = [ [ "Ready", 900 ], [ "Set", 900 ], [ "GO!", 600 ] ]
const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)")

// Runs the whole one-minute test in the browser: nothing touches the network until it ends
export default class extends Controller {
  static targets = [ "question", "answer", "score", "quarter", "seconds", "status", "retry", "keypad" ]
  static values = { questions: Array, topic: String, submitUrl: String }

  connect() {
    this.state = "countdown"
    this.index = 0
    this.typed = ""
    this.score = 0
    this.results = []

    this.keydown = this.keydown.bind(this)
    this.beforeUnload = this.beforeUnload.bind(this)
    this.tick = this.tick.bind(this)
    document.addEventListener("keydown", this.keydown)
    window.addEventListener("beforeunload", this.beforeUnload)

    this.countdown(COUNTDOWN)
  }

  disconnect() {
    document.removeEventListener("keydown", this.keydown)
    window.removeEventListener("beforeunload", this.beforeUnload)
    cancelAnimationFrame(this.frame)
    clearTimeout(this.timer)
    clearTimeout(this.endTimer)
  }

  // Ready, set, go! so the first second of the test isn't spent getting ready
  countdown(steps) {
    if (steps.length === 0) return this.start()

    const [ [ word, ms ], ...rest ] = steps
    this.questionTarget.textContent = word
    this.timer = setTimeout(() => this.countdown(rest), ms)
  }

  start() {
    this.state = "running"
    this.element.classList.add("test--running")
    this.endsAt = performance.now() + DURATION
    // A backup in case animation frames stop, e.g. while the tab is hidden
    this.endTimer = setTimeout(() => this.finish(), DURATION + 50)
    this.show()
    this.frame = requestAnimationFrame(this.tick)
  }

  tick() {
    const left = this.endsAt - performance.now()
    if (left <= 0) return this.finish()

    this.fillRing(1 - left / DURATION)
    const seconds = Math.ceil(left / 1000)
    if (seconds !== this.seconds) {
      this.seconds = seconds
      this.secondsTarget.textContent = seconds
      this.element.dataset.quarter = Math.min(3, Math.floor((60 - seconds) / 15))
    }
    this.frame = requestAnimationFrame(this.tick)
  }

  // Fills the ring's quarters one after another, so a whole minute completes the logo
  fillRing(elapsed) {
    this.quarterTargets.forEach((quarter, i) => {
      const filled = Math.min(1, Math.max(0, elapsed * 4 - i)) * QUARTER_LENGTH
      quarter.setAttribute("stroke-dasharray", `${filled} ${100 - filled}`)
    })
  }

  // Input

  tap(event) {
    event.preventDefault()
    const digit = event.currentTarget.dataset.digit
    digit === "back" ? this.backspace() : this.type(digit)
  }

  keydown(event) {
    if (event.metaKey || event.ctrlKey || event.altKey) return

    if (/^[0-9]$/.test(event.key)) {
      event.preventDefault()
      this.type(event.key)
    } else if (event.key === "Backspace") {
      event.preventDefault()
      this.backspace()
    }
  }

  type(digit) {
    if (!this.accepting) return

    this.typed += digit
    this.answerTarget.textContent = this.typed
    // Check as soon as there are as many digits as the right answer, so there's no Enter to press
    if (this.typed.length >= String(this.correctAnswer).length) this.check()
  }

  backspace() {
    if (!this.accepting) return

    this.typed = this.typed.slice(0, -1)
    this.answerTarget.textContent = this.typed
  }

  get accepting() {
    return this.state === "running" && !this.paused
  }

  // Questions

  get current() {
    return this.questionsValue[this.index]
  }

  get correctAnswer() {
    return this.current.a * this.current.b
  }

  show() {
    const { a, b } = this.current
    this.questionTarget.textContent = `${a} × ${b}`
    this.typed = ""
    this.answerTarget.textContent = ""
    this.shownAt = performance.now()
  }

  check() {
    const given = parseInt(this.typed, 10)
    const correct = given === this.correctAnswer
    const { a, b } = this.current
    this.results.push({ a, b, given, ms: Math.round(performance.now() - this.shownAt) })

    if (correct) {
      this.score++
      this.scoreTarget.textContent = this.score
      this.flash(this.scoreTarget, "--right")
      this.next()
    } else {
      // Show the right answer briefly so it sticks, then carry on
      this.paused = true
      this.answerTarget.textContent = this.correctAnswer
      this.answerTarget.classList.add("answer--wrong")
      this.timer = setTimeout(() => {
        this.paused = false
        this.answerTarget.classList.remove("answer--wrong")
        if (this.state === "running") this.next()
      }, WRONG_PAUSE)
    }
  }

  next() {
    this.index++
    this.current ? this.show() : this.finish()
  }

  flash(element, colourVariable) {
    if (reducedMotion.matches) return

    const colour = getComputedStyle(document.documentElement).getPropertyValue(colourVariable)
    element.animate([ { backgroundColor: colour }, { backgroundColor: "transparent" } ], { duration: 300, easing: "ease-out" })
  }

  // Finishing

  finish() {
    if (this.state !== "running") return

    this.state = "done"
    this.element.classList.remove("test--running")
    cancelAnimationFrame(this.frame)
    clearTimeout(this.endTimer)
    this.fillRing(1)
    this.secondsTarget.textContent = 0
    this.questionTarget.textContent = "Time's up!"
    this.questionTarget.classList.add("question--done")
    this.answerTarget.textContent = ""
    this.answerTarget.classList.remove("answer--wrong")
    this.keypadTarget.hidden = true
    this.submit()
  }

  async submit() {
    this.retryTarget.hidden = true
    this.status("Saving…")

    try {
      const response = await fetch(this.submitUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content
        },
        body: JSON.stringify({ attempt: { topic: this.topicValue, results: this.results } })
      })
      if (!response.ok) throw new Error(`Saving failed (${response.status})`)

      const { url } = await response.json()
      this.state = "saved"
      Turbo.visit(url, { action: "replace" })
    } catch (error) {
      console.error(error)
      this.status("Couldn't save your score. Check your internet and try again.")
      this.retryTarget.hidden = false
    }
  }

  status(message) {
    this.statusTarget.textContent = message
    this.statusTarget.hidden = false
  }

  beforeUnload(event) {
    if (this.state === "running" || this.state === "done") {
      event.preventDefault()
      event.returnValue = ""
    }
  }
}
