import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"
import { chooseQuestionSet, playerKey, preparePlayer, postGame, saveForLater, watchPlayer } from "lib/offline_games"
import { finished, shown, typedWith } from "lib/answer_input"
import * as feedback from "lib/feedback"

const DURATION = 60_000
const STARS = { right: 10, quick: 20, lightning: 30 }
const WRONG_PAUSE = 400
// A review has no clock, so there's time to take in the right answer
const REVIEW_WRONG_PAUSE = 1_500
// Each quarter of the clock ring is a full 25 of 100 units; the clock's cut makes the gaps between them
const QUARTER_LENGTH = 25
const COUNTDOWN = [ [ "Ready", 900 ], [ "Set", 900 ], [ "GO!", 600 ] ]
// The clock ticks out loud for the last seconds
const TICKING_FROM = 5
const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)")

// Runs the whole one-minute test in the browser: nothing touches the network until it ends.
// Offline, the finished game is kept on the device and uploaded later. It can be stopped part way,
// after a warning, and then nothing is saved. A review has no clock or stars: it asks each of its
// questions once and ends after the last
export default class extends Controller {
  static targets = [ "question", "answer", "score", "quarter", "hand", "seconds", "status", "keypad", "stopDialog", "offlineResult", "offlineScore", "unavailable", "stage", "progress" ]
  static values = { questionSets: Array, topic: String, level: Number, mode: String, round: String, submitUrl: String, keys: Array, starTimes: Object }

  connect() {
    preparePlayer()
    this.state = "countdown"
    this.unwatch = watchPlayer(() => { this.state = "stopped" })
    if (this.state === "stopped") return
    this.questionSet = chooseQuestionSet(this.questionSetsValue, this.sparesKey)
    if (!this.questionSet) {
      this.state = "stopped"
      this.questionTarget.hidden = true
      this.answerTarget.hidden = true
      this.unavailableTarget.hidden = false
      this.keypadTarget.hidden = true
      return
    }
    this.questions = this.questionSet.questions
    this.player = playerKey()
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

    this.review ? this.startReview() : this.countdown(COUNTDOWN)
  }

  // A daily challenge's or review's spares are its own, as its questions are mixed from every level, and a group
  // challenge's are its round's
  get sparesKey() {
    const kind = { practice: this.levelValue, group: `group-${this.roundValue}` }[this.modeValue] ?? this.modeValue
    return `${this.topicValue}:${kind}`
  }

  get review() {
    return this.modeValue === "review"
  }

  disconnect() {
    this.unwatch?.()
    document.removeEventListener("keydown", this.keydown)
    window.removeEventListener("beforeunload", this.beforeUnload)
    cancelAnimationFrame(this.frame)
    clearTimeout(this.countdownTimer)
    clearTimeout(this.correctionTimer)
    clearTimeout(this.endTimer)
  }

  // Ready, set, go! so the first second of the test isn't spent getting ready
  countdown(steps) {
    if (steps.length === 0) return this.start()

    const [ [ word, ms ], ...rest ] = steps
    this.questionTarget.textContent = word
    feedback.countdown(rest.length === 0)
    this.countdownTimer = setTimeout(() => this.countdown(rest), ms)
  }

  start() {
    this.endsAt = performance.now() + DURATION
    this.show()
    this.run()
  }

  startReview() {
    this.state = "running"
    this.show()
  }

  run() {
    this.state = "running"
    if (this.review) return

    this.element.classList.add("test--running")
    // A backup in case animation frames stop, e.g. while the tab is hidden
    this.endTimer = setTimeout(() => this.finish(), this.endsAt - performance.now() + 50)
    this.frame = requestAnimationFrame(this.tick)
  }

  stopClock() {
    this.element.classList.remove("test--running")
    cancelAnimationFrame(this.frame)
    clearTimeout(this.endTimer)
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
      if (seconds <= TICKING_FROM) feedback.clockTick()
    }
    this.frame = requestAnimationFrame(this.tick)
  }

  // Fills the ring's quarters one after another, so a whole minute completes the logo,
  // and turns the hand once round with it, like a real second hand
  fillRing(elapsed) {
    this.quarterTargets.forEach((quarter, i) => {
      const filled = Math.min(1, Math.max(0, elapsed * 4 - i)) * QUARTER_LENGTH
      quarter.setAttribute("stroke-dasharray", `${filled} ${100 - filled}`)
    })
    if (this.hasHandTarget) this.handTarget.setAttribute("transform", `rotate(${elapsed * 360} 24 24)`)
  }

  // Input

  tap(event) {
    // Pointer input is handled immediately; a keyboard or assistive click has no pointer event.
    if (event.type === "click" && event.detail > 0) return
    event.preventDefault()
    const digit = event.currentTarget.dataset.digit
    digit === "back" ? this.backspace() : this.type(digit)
  }

  keydown(event) {
    if (event.metaKey || event.ctrlKey || event.altKey) return

    if (/^[0-9]$/.test(event.key) || this.keysValue.includes(event.key)) {
      event.preventDefault()
      this.type(event.key)
    } else if (event.key === "Backspace") {
      event.preventDefault()
      this.backspace()
    } else if (event.key === "Enter" && !event.target?.closest("button, a, input, textarea, select")) {
      event.preventDefault()
      this.checkAnswer()
    }
  }

  type(key) {
    const typed = typedWith(this.typed, key, this.keysValue)
    if (!this.accepting || typed === null) return

    this.typed = typed
    this.showTyped()
    // Check as soon as the answer is as long as the right one ("56", "3/4", "-2100"), so there's no Enter to press,
    // but not while it ends in −, . or /, which a finished answer never does
    if (this.typed.length >= this.correctAnswer.length && finished(this.typed)) this.check()
  }

  showTyped() {
    this.answerTarget.textContent = shown(this.typed)
  }

  checkAnswer() {
    if (this.accepting && finished(this.typed)) this.check()
  }

  backspace() {
    if (!this.accepting) return

    this.typed = this.typed.slice(0, -1)
    this.showTyped()
  }

  get accepting() {
    return this.state === "running" && !this.showingCorrection
  }

  // Questions

  get current() {
    return this.questions[this.index]
  }

  // Each question comes with its answer written the way it's typed: "56", "3/4", "11/9"
  get correctAnswer() {
    return this.current.answer
  }

  // The question text is built on the server from numbers and letters (equations use HTML for fractions)
  show() {
    this.questionTarget.innerHTML = this.current.text
    this.fitQuestion()
    this.typed = ""
    this.answerTarget.textContent = ""
    this.shownAt = performance.now()
    if (this.hasProgressTarget) this.progressTarget.textContent = `${this.index + 1}/${this.questions.length}`
  }

  // 0.7 × −3000 is longer than 7 × 8, so it's shown smaller to stay on one line
  fitQuestion() {
    const length = this.questionTarget.textContent.length
    this.questionTarget.classList.toggle("question--long", length > 8 && length <= 12)
    this.questionTarget.classList.toggle("question--longer", length > 12)
  }

  // The question's own details go back with the answer, so the server can check it for itself
  check() {
    const { text, answer, ...question } = this.current
    const ms = Math.round(performance.now() - this.shownAt)
    this.results.push({ ...question, given: this.typed, ms })

    if (this.typed === answer) {
      this.score++
      this.scoreTarget.textContent = this.score
      this.flash(this.scoreTarget, "--right")
      feedback.right()
      if (!this.review) this.popStars(ms)
      this.next()
    } else {
      this.showCorrection()
    }
  }

  // Stars for a right answer float up and fade: +10, +20 if quick, +30 if lightning fast. The server works
  // out the stars that count from the answers, with the same rules (Attempt::Starrable)
  popStars(ms) {
    const { lightning, quick } = this.starTimesValue
    const [ stars, tier ] = ms < lightning ? [ STARS.lightning, "lightning" ] : ms < quick ? [ STARS.quick, "quick" ] : [ STARS.right, "right" ]
    const pop = Object.assign(document.createElement("span"), { className: `star-pop star-pop--${tier}`, textContent: `+${stars} ⭐` })
    pop.setAttribute("aria-hidden", "true")
    // Spread out a little, so quick answers in a row don't land on top of each other
    pop.style.setProperty("--drift", `${Math.round((Math.random() - 0.5) * 180)}px`)
    pop.addEventListener("animationend", () => pop.remove())
    setTimeout(() => pop.remove(), 2_600)
    this.stageTarget.append(pop)
  }

  // Show the right answer briefly so it sticks, then carry on
  showCorrection() {
    feedback.wrong()
    this.showingCorrection = true
    this.answerTarget.textContent = shown(this.correctAnswer)
    this.answerTarget.classList.add("answer--wrong")
    this.correctionTimer = setTimeout(() => {
      this.showingCorrection = false
      this.answerTarget.classList.remove("answer--wrong")
      if (this.state === "running" || this.state === "paused") this.next()
    }, this.review ? REVIEW_WRONG_PAUSE : WRONG_PAUSE)
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

  // Stopping part way. The clock pauses while the warning is open, so keeping playing costs no time

  confirmStop() {
    if (this.state === "stopped" || this.state === "rejected") return Turbo.visit("/", { action: "replace" })
    if (this.state !== "running" && this.state !== "countdown") return

    this.pause()
    this.stopDialogTarget.showModal()
  }

  keepPlaying(event) {
    event?.preventDefault()
    this.stopDialogTarget.close()
    this.resume()
  }

  stopGame() {
    this.state = "stopped"
    this.stopDialogTarget.close()
    Turbo.visit("/", { action: "replace" })
  }

  pause() {
    this.pausedFrom = this.state
    this.pausedAt = performance.now()
    this.state = "paused"
    this.element.classList.add("test--paused")
    clearTimeout(this.countdownTimer)
    this.stopClock()
  }

  resume() {
    this.element.classList.remove("test--paused")
    if (this.pausedFrom === "countdown") return this.restartCountdown()

    const pausedFor = performance.now() - this.pausedAt
    this.endsAt += pausedFor
    // A question shown during the pause (after a correction) starts its timing now
    this.shownAt = this.shownAt < this.pausedAt ? this.shownAt + pausedFor : performance.now()
    this.run()
    // The last answer's correction can end while paused, with no question left to show
    if (!this.current) this.finish()
  }

  restartCountdown() {
    this.state = "countdown"
    this.countdown(COUNTDOWN)
  }

  // Finishing

  finish() {
    if (this.state !== "running") return

    this.state = "done"
    this.stopClock()
    this.fillRing(1)
    if (this.hasSecondsTarget) this.secondsTarget.textContent = 0
    this.questionTarget.textContent = this.review ? "All done!" : "Time's up!"
    this.questionTarget.classList.remove("question--long", "question--longer")
    this.questionTarget.classList.add("question--done")
    this.answerTarget.textContent = ""
    this.answerTarget.classList.remove("answer--wrong")
    this.keypadTarget.hidden = true
    this.submit()
  }

  async submit() {
    this.status("Saving…")
    const game = this.game ||= {
      client_id: this.questionSet.id, ticket: this.questionSet.ticket, player_key: this.player,
      played_at: new Date().toISOString(), time_zone: Intl.DateTimeFormat().resolvedOptions().timeZone,
      topic: this.topicValue, level: this.levelValue, results: this.results
    }
    const { outcome, url } = await postGame(this.submitUrlValue, game)

    if (outcome === "saved") {
      this.state = "saved"
      Turbo.visit(url, { action: "replace" })
    } else if (outcome === "failed") {
      if (saveForLater(game)) {
        this.showOfflineResult()
      } else {
        this.status("Your game couldn't be saved on this device. Keep this page open and try saving again when you're connected.")
        this.retryButton().hidden = false
      }
    } else {
      this.state = "rejected"
      this.status(this.modeValue === "challenge" && this.results.length === 0
        ? "No answers this time. Your daily challenge is still available — go home to try again."
        : "Sorry, this game couldn't be saved.")
    }
  }

  retryButton() {
    if (!this.retry) {
      this.retry = document.createElement("button")
      this.retry.type = "button"
      this.retry.className = "button"
      this.retry.textContent = "Try saving again"
      this.retry.addEventListener("click", () => { this.retry.hidden = true; this.submit() })
      this.statusTarget.after(this.retry)
    }
    return this.retry
  }

  // No connection: the game waits on this device and uploads when the app is next online
  showOfflineResult() {
    this.state = "saved"
    this.statusTarget.hidden = true
    this.questionTarget.hidden = true
    this.answerTarget.hidden = true
    this.offlineScoreTarget.textContent = this.score
    this.offlineResultTarget.hidden = false
  }

  status(message) {
    this.statusTarget.textContent = message
    this.statusTarget.hidden = false
  }

  beforeUnload(event) {
    if ([ "running", "paused", "done" ].includes(this.state)) {
      event.preventDefault()
      event.returnValue = ""
    }
  }
}
