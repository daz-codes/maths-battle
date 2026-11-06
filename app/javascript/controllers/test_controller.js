import { Controller } from "@hotwired/stimulus"
import { Turbo, cable } from "@hotwired/turbo-rails"
import { finished, typedWith } from "lib/answer_input"
import * as feedback from "lib/feedback"
import confetti from "canvas-confetti"

const DURATION = 60_000
const NEWS_TIME = 3_000
// The server leaves this out of where a Streak breaker hit (LiveGame::Droppable), so keep them the same
const WRONG_PAUSE = 400
// How fast a spinner flicks between power-ups, and how long the one claimed shows before it goes
const SPIN_EVERY = 90
const LANDED_FOR = 1_400
// Each quarter of the clock ring is a full 25 of 100 units; the clock's cut makes the gaps between them
const QUARTER_LENGTH = 25
const COUNTDOWN = [ [ "Ready", 900 ], [ "Set", 900 ], [ "GO!", 600 ] ]
// The clock ticks out loud for the last seconds
const TICKING_FROM = 5
const KEYS = [ "." ]
const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)")

// Runs the whole one-minute game in the browser, and saves it at the end. The questions climb a ladder (Ladder on
// the server): `climb` right in a row moves up a tier, a wrong answer down one, each tier asking its own questions
// in turn. Streaks score: 10 for the first right answer, 20 for the next in a row, and on. Every ten answers a
// power-up spinner appears to tap: solo, it lands on the one the server dealt; in a battle the server drops it
// for everyone and the first to tap it claims it, hitting everyone else. The server works out the score that
// counts from the answers, with the same rules (Attempt::Scorable)
export default class extends Controller {
  static targets = [ "question", "answer", "right", "score", "quarter", "hand", "seconds", "status", "keypad", "stopDialog", "stage", "best", "streak", "tier", "rival", "spinner", "spinnerIcon", "powerNews", "powerIcon", "trophyIcon" ]
  static values = { game: Object, best: Number, live: Object, submitUrl: String, powers: Object }

  connect() {
    const { pools, climb } = this.gameValue
    this.pools = pools
    this.climb = climb
    this.tier = 0
    this.climbing = 0
    this.taken = pools.map(() => 0)
    this.typed = ""
    this.correct = 0
    this.points = 0
    this.streak = 0
    this.doubles = 0
    this.shields = 0
    this.results = []
    this.claims = []
    this.state = "countdown"

    this.keydown = this.keydown.bind(this)
    this.beforeUnload = this.beforeUnload.bind(this)
    this.tick = this.tick.bind(this)
    document.addEventListener("keydown", this.keydown)
    window.addEventListener("beforeunload", this.beforeUnload)

    this.live ? this.joinLive() : this.countdown(COUNTDOWN)
  }

  disconnect() {
    this.disconnected = true
    this.liveChannel?.unsubscribe()
    Object.values(this.effectTimers ?? {}).forEach(clearTimeout)
    this.stopSpinner()
    clearTimeout(this.landedTimer)
    clearTimeout(this.newsTimer)
    document.removeEventListener("keydown", this.keydown)
    window.removeEventListener("beforeunload", this.beforeUnload)
    cancelAnimationFrame(this.frame)
    clearTimeout(this.countdownTimer)
    clearTimeout(this.correctionTimer)
    clearTimeout(this.endTimer)
  }

  // Battles: everyone starts at the same moment, set by the server, and plays the same minute

  get live() {
    return this.hasLiveValue && Object.keys(this.liveValue).length > 0
  }

  joinLive() {
    this.liveStartAt = performance.now() + this.liveValue.startsInMs
    cable.subscribeTo({ channel: "LiveGameChannel", pass: this.liveValue.pass }, { received: (data) => this.liveMessage(data) })
      .then((subscription) => { this.disconnected ? subscription.unsubscribe() : this.liveChannel = subscription })
    this.waitForLiveStart()
  }

  // Counts down to the start, or starts at once if it's already begun (the minute is shorter, not longer)
  waitForLiveStart() {
    const lead = COUNTDOWN.reduce((total, [ , ms ]) => total + ms, 0)
    const untilCountdown = this.liveStartAt - lead - performance.now()
    if (untilCountdown > 0) {
      this.questionTarget.textContent = "Get ready…"
      this.countdownTimer = setTimeout(() => this.countdown(COUNTDOWN), untilCountdown)
    } else {
      this.countdownTimer = setTimeout(() => this.start(), Math.max(0, this.liveStartAt - performance.now()))
    }
  }

  liveMessage(data) {
    if (this.state !== "running" && this.state !== "paused") return

    if (data.type === "drop") this.dropped(data.id)
    else if (data.type === "claimed") this.claimed(data)
    else if (data.type === "score") this.rivalScored(data)
  }

  // Another player's score has gone up: shown with theirs, pink while they're ahead
  rivalScored({ player_id, score }) {
    const rival = this.rivalTargets.find((element) => element.dataset.playerId === String(player_id))
    if (!rival) return

    rival.dataset.score = score
    rival.querySelector("strong").textContent = Number(score).toLocaleString()
    this.showRivalLeads()
  }

  showRivalLeads() {
    this.rivalTargets.forEach((rival) => {
      const score = Number(rival.dataset.score || 0)
      rival.classList.toggle("test__rival--ahead", score > this.points)
      rival.classList.toggle("test__rival--behind", score < this.points)
    })
  }

  reportToRivals() {
    if (!this.live) return

    this.liveChannel?.perform("score", { score: this.points, correct: this.correct, answered: this.results.length })
    this.showRivalLeads()
  }

  playerName(id) {
    return this.rivalTargets.find((rival) => rival.dataset.playerId === String(id))?.dataset.name ?? "Someone"
  }

  // Power-ups

  // Solo, every ten answers: it lands on the one dealt for it
  offerSolo() {
    const drop = this.results.length / this.powersValue.every
    if (!Number.isInteger(drop) || drop < 1) return

    this.spin({ drop }, Object.keys(this.powersValue.solo))
  }

  // In a battle, when anyone passes another ten
  dropped(id) {
    this.spin({ id }, Object.keys(this.powersValue.battle))
  }

  // The spinner flicks between what it could be until it's tapped. A new one takes the place of one not tapped
  spin(offer, kinds) {
    this.stopSpinner()
    clearTimeout(this.landedTimer)
    this.offer = offer
    let shown = 0
    this.showSpinnerIcon(kinds[0])
    this.spinTimer = setInterval(() => this.showSpinnerIcon(kinds[++shown % kinds.length]), SPIN_EVERY)
    this.spinnerTarget.disabled = false
    this.spinnerTarget.classList.remove("test__spinner--landed")
    this.spinnerTarget.hidden = false
    feedback.countdown(false)
  }

  stopSpinner() {
    clearInterval(this.spinTimer)
    this.spinTimer = null
  }

  showSpinnerIcon(kind) {
    this.spinnerIconTarget.replaceChildren(this.powerIcon(kind))
  }

  // Tapped (or Space). Solo it's claimed there and then; in a battle the server says who got there first
  claim() {
    if (!this.offer || this.state !== "running") return

    const offer = this.offer
    this.offer = null
    this.spinnerTarget.disabled = true
    if (offer.drop) {
      const kind = this.gameValue.powers[offer.drop - 1]
      this.claims.push({ drop: offer.drop, at: this.results.length })
      this.land(kind)
      this.gotSolo(kind)
    } else {
      this.claiming = offer.id
      this.liveChannel?.perform("claim", { id: offer.id })
    }
  }

  land(kind) {
    this.stopSpinner()
    this.showSpinnerIcon(kind)
    this.spinnerTarget.classList.add("test__spinner--landed")
    this.landedTimer = setTimeout(() => this.hideSpinner(), LANDED_FOR)
  }

  hideSpinner() {
    this.stopSpinner()
    this.offer = null
    this.spinnerTarget.hidden = true
  }

  gotSolo(kind) {
    if (kind === "double") this.doubles += this.powersValue.solo.double.answers
    else if (kind === "shield") this.shields++
    else if (kind === "time") {
      this.endsAt += this.powersValue.solo.time.seconds * 1000
      this.scheduleEnd()
    }
    this.element.classList.toggle("test--doubled", this.doubles > 0)
    this.element.classList.toggle("test--shielded", this.shields > 0)
    this.news(this.powersValue.solo[kind].news)
    feedback.fanfare()
  }

  // Someone got it: if it was this player, it hits everyone else; if not, it hits this one
  claimed({ id, power_up, by }) {
    const { name, news } = this.powersValue.battle[power_up]
    const mine = this.offer?.id === id || this.claiming === id
    if (this.claiming === id) this.claiming = null
    if (by === this.liveValue.me) {
      this.land(power_up)
      this.news(`${name}! You ${news} everyone else`)
      feedback.fanfare()
    } else {
      if (mine) this.hideSpinner()
      this.hitBy(power_up)
      this.news(`${this.playerName(by)} ${news} you!`)
    }
  }

  // Freeze stops the keypad and Scramble moves its keys; the Streak breaker ends the streak. The clock keeps going,
  // as it's everyone's
  hitBy(kind) {
    feedback.wrong()
    if (kind === "reset") {
      if (this.streak > 0) this.popText("Streak broken!", "wrong")
      this.streak = 0
      this.showStreak()
      return
    }

    const ms = this.powersValue.battle[kind].seconds * 1000
    if (kind === "freeze") this.frozenUntil = performance.now() + ms
    if (kind === "scramble") this.scrambleKeys()
    this.element.classList.add(`test--${kind}`)
    clearTimeout(this.effectTimers?.[kind])
    this.effectTimers = { ...this.effectTimers, [kind]: setTimeout(() => this.endEffect(kind), ms) }
  }

  endEffect(kind) {
    this.element.classList.remove(`test--${kind}`)
    if (kind === "scramble") this.unscrambleKeys()
  }

  // The digits swap places on the keypad (typing on a keyboard still works)
  scrambleKeys() {
    const keys = this.digitKeys
    this.unscrambleKeys()
    const digits = keys.map((key) => key.dataset.digit)
    for (let i = digits.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [ digits[i], digits[j] ] = [ digits[j], digits[i] ]
    }
    keys.forEach((key, i) => { key.dataset.digit = digits[i]; key.textContent = digits[i] })
  }

  unscrambleKeys() {
    this.digitKeys.forEach((key) => { key.dataset.digit = key.dataset.homeDigit; key.textContent = key.dataset.homeDigit })
  }

  get digitKeys() {
    return [ ...this.keypadTarget.querySelectorAll("[data-digit]") ].filter((key) => {
      key.dataset.homeDigit ??= key.dataset.digit
      return /^[0-9]$/.test(key.dataset.homeDigit)
    })
  }

  // Time's up: nothing left to claim, and every effect wears off
  endPowerUps() {
    this.hideSpinner()
    Object.keys(this.effectTimers ?? {}).forEach((kind) => { clearTimeout(this.effectTimers[kind]); this.endEffect(kind) })
    this.frozenUntil = 0
  }

  powerIcon(kind) {
    return this.powerIconTargets.find((template) => template.dataset.powerUp === kind).content.cloneNode(true)
  }

  news(message) {
    this.powerNewsTarget.textContent = message
    clearTimeout(this.newsTimer)
    this.newsTimer = setTimeout(() => { this.powerNewsTarget.textContent = "" }, NEWS_TIME)
  }

  // The clock

  // Ready, set, go! so the first second of the game isn't spent getting ready
  countdown(steps) {
    if (steps.length === 0) return this.start()

    const [ [ word, ms ], ...rest ] = steps
    this.questionTarget.textContent = word
    feedback.countdown(rest.length === 0)
    this.countdownTimer = setTimeout(() => this.countdown(rest), ms)
  }

  start() {
    this.endsAt = (this.live ? this.liveStartAt : performance.now()) + DURATION
    this.show()
    this.run()
  }

  run() {
    this.state = "running"
    this.element.classList.add("test--running")
    this.frame = requestAnimationFrame(this.tick)
    this.scheduleEnd()
  }

  // A backup in case animation frames stop, e.g. while the tab is hidden. Extra time moves it
  scheduleEnd() {
    clearTimeout(this.endTimer)
    this.endTimer = setTimeout(() => this.finish(), this.endsAt - performance.now() + 50)
  }

  stopClock() {
    this.element.classList.remove("test--running")
    cancelAnimationFrame(this.frame)
    clearTimeout(this.endTimer)
  }

  tick() {
    const left = this.endsAt - performance.now()
    if (left <= 0) return this.finish()

    this.fillRing(1 - Math.min(left, DURATION) / DURATION)
    const seconds = Math.ceil(left / 1000)
    if (seconds !== this.seconds) {
      this.seconds = seconds
      this.secondsTarget.textContent = seconds
      this.element.dataset.quarter = Math.max(0, Math.min(3, Math.floor((60 - seconds) / 15)))
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

    if (/^[0-9.]$/.test(event.key)) {
      event.preventDefault()
      this.type(event.key)
    } else if (event.key === "Backspace") {
      event.preventDefault()
      this.backspace()
    } else if (event.key === "Enter" && !event.target?.closest("button, a, input, textarea, select")) {
      event.preventDefault()
      this.checkAnswer()
    } else if (event.key === " " && this.offer) {
      event.preventDefault()
      this.claim()
    }
  }

  type(key) {
    const typed = typedWith(this.typed, key, KEYS)
    if (!this.accepting || typed === null) return

    this.typed = typed
    this.answerTarget.textContent = this.typed
    // Check as soon as the answer is as long as the right one, so there's no Enter to press, but not while it ends
    // in a decimal point, which a finished answer never does
    if (this.typed.length >= this.current.answer.length && finished(this.typed)) this.check()
  }

  checkAnswer() {
    if (this.accepting && finished(this.typed)) this.check()
  }

  backspace() {
    if (!this.accepting) return

    this.typed = this.typed.slice(0, -1)
    this.answerTarget.textContent = this.typed
  }

  // Not while frozen by someone's Freeze
  get accepting() {
    return this.state === "running" && !this.showingCorrection && !(this.frozenUntil > performance.now())
  }

  // The ladder

  // This tier's next question, round again if they've had them all
  get current() {
    const pool = this.pools[this.tier]
    return pool[this.taken[this.tier] % pool.length]
  }

  show() {
    const text = this.current.text
    this.questionTarget.textContent = text
    this.questionTarget.classList.toggle("question--long", text.length > 8 && text.length <= 12)
    this.questionTarget.classList.toggle("question--longer", text.length > 12)
    this.typed = ""
    this.answerTarget.textContent = ""
    this.answerTarget.classList.remove("answer--wrong")
    this.shownAt = performance.now()
    if (this.results.length > 0) this.moveOn()
  }

  // The next question comes down into place
  moveOn() {
    if (reducedMotion.matches) return

    this.questionTarget.animate([ { transform: "translateY(-25%)", opacity: 0 }, { transform: "none", opacity: 1 } ], { duration: 200, easing: "ease-out" })
  }

  // The same rule as Ladder.walk on the server
  climbLadder(right) {
    this.taken[this.tier]++
    const before = this.tier
    if (right) {
      if (++this.climbing >= this.climb && this.tier < this.pools.length - 1) {
        this.tier++
        this.climbing = 0
      }
    } else {
      this.tier = Math.max(0, this.tier - 1)
      this.climbing = 0
    }
    if (this.tier !== before) this.showTier(this.tier > before)
  }

  showTier(up) {
    if (!this.hasTierTarget) return

    this.tierTarget.textContent = `Level ${this.tier + 1}`
    if (up) this.popText(`Level ${this.tier + 1}!`, "level")
  }

  // The question's own numbers go back with the answer, so the server can check it for itself
  check() {
    const { op, a, b, answer } = this.current
    const ms = Math.round(performance.now() - this.shownAt)
    const right = this.typed === answer
    this.results.push({ op, a, b, given: this.typed, ms })
    this.climbLadder(right)

    if (right) {
      this.correct++
      this.rightTarget.textContent = this.correct
      this.earnPoints()
      this.flash(this.scoreTarget, "--right")
      feedback.right()
      if (this.bestValue && !this.passedBest && this.points > this.bestValue) this.passBest()
      this.reportToRivals()
      this.next()
    } else {
      this.breakStreak()
      this.reportToRivals()
      this.showCorrection()
    }
    if (!this.live) this.offerSolo()
  }

  // 10 for the first in a row, 20 for the next, and on, doubled while Double points lasts
  earnPoints() {
    this.streak++
    let points = 10 * this.streak
    if (this.doubles > 0) {
      points *= 2
      this.doubles--
      this.element.classList.toggle("test--doubled", this.doubles > 0)
    }
    this.points += points
    this.scoreTarget.textContent = this.points.toLocaleString()
    this.popText(`+${points}`, points >= 100 ? "lightning" : "right")
    this.showStreak()
  }

  // A Streak shield takes the hit instead
  breakStreak() {
    if (this.shields > 0) {
      this.shields--
      this.element.classList.toggle("test--shielded", this.shields > 0)
      this.news("Your Streak shield saved your streak!")
      return
    }
    if (this.streak > 1) this.popText("Streak over", "wrong")
    this.streak = 0
    this.showStreak()
  }

  showStreak() {
    this.streakTarget.hidden = this.streak < 2
    this.streakTarget.textContent = `${this.streak} in a row`
    if (this.streak >= 2) {
      this.streakTarget.classList.remove("test__combo--new")
      void this.streakTarget.offsetWidth // so the pulse plays again
      this.streakTarget.classList.add("test__combo--new")
    }
  }

  // Spread out a little, so quick answers in a row don't land on top of each other
  popText(text, tier) {
    const pop = Object.assign(document.createElement("span"), { className: `score-pop score-pop--${tier}`, textContent: text })
    pop.setAttribute("aria-hidden", "true")
    pop.style.setProperty("--drift", `${Math.round((Math.random() - 0.5) * 180)}px`)
    pop.addEventListener("animationend", () => pop.remove())
    setTimeout(() => pop.remove(), 2_600)
    this.stageTarget.append(pop)
    return pop
  }

  // The moment the score passes their best: it turns pink, says so, bursts with confetti and plays the fanfare
  passBest() {
    this.passedBest = true
    const score = this.scoreTarget.getBoundingClientRect()
    const origin = { x: (score.left + score.width / 2) / window.innerWidth, y: (score.top + score.height / 2) / window.innerHeight }
    confetti({ particleCount: 140, spread: 100, startVelocity: 40, origin, colors: [ "#efff2e", "#ff5cc6", "#2be4ff", "#5dff7a" ], disableForReducedMotion: true })
    this.element.classList.add("test--beating")
    if (this.hasBestTarget) this.bestTarget.textContent = "New best!"
    const pop = this.popText(" New best!", "best")
    pop.style.setProperty("--drift", "0px")
    pop.prepend(this.trophyIconTarget.content.cloneNode(true))
    feedback.fanfare()
  }

  // The wrong answer stays, in red, for a moment, then the next question
  showCorrection() {
    feedback.wrong()
    this.showingCorrection = true
    this.answerTarget.classList.add("answer--wrong")
    this.correctionTimer = setTimeout(() => {
      this.showingCorrection = false
      if (this.state === "running" || this.state === "paused") this.next()
    }, WRONG_PAUSE)
  }

  next() {
    this.results.length >= this.gameValue.most ? this.finish() : this.show()
  }

  flash(element, colourVariable) {
    if (reducedMotion.matches) return

    const colour = getComputedStyle(document.documentElement).getPropertyValue(colourVariable)
    element.animate([ { backgroundColor: colour }, { backgroundColor: "transparent" } ], { duration: 300, easing: "ease-out" })
  }

  // Stopping part way. Solo, the clock pauses while the warning is open, so keeping playing costs no time

  confirmStop() {
    if (this.state === "rejected") return Turbo.visit("/", { action: "replace" })
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

  // A battle's clock is everyone's, so it keeps going while paused
  resume() {
    this.element.classList.remove("test--paused")
    if (this.pausedFrom === "countdown") {
      this.state = "countdown"
      return this.live ? this.waitForLiveStart() : this.countdown(COUNTDOWN)
    }

    const pausedFor = performance.now() - this.pausedAt
    if (!this.live) this.endsAt += pausedFor
    // A question shown during the pause (after a correction) starts its timing now
    this.shownAt = this.shownAt < this.pausedAt ? this.shownAt + pausedFor : performance.now()
    this.run()
  }

  // Finishing

  finish() {
    if (this.state !== "running") return

    this.state = "done"
    this.stopClock()
    this.endPowerUps()
    this.fillRing(1)
    this.secondsTarget.textContent = 0
    this.questionTarget.textContent = "Time's up!"
    this.questionTarget.classList.remove("question--long", "question--longer")
    this.questionTarget.classList.add("question--done")
    this.answerTarget.textContent = ""
    this.answerTarget.classList.remove("answer--wrong")
    this.keypadTarget.hidden = true
    this.submit()
  }

  async submit() {
    this.status("Saving…")
    const body = JSON.stringify({ attempt: { client_id: this.gameValue.id, ticket: this.gameValue.ticket, results: this.results, claims: this.claims } })
    try {
      const response = await fetch(this.submitUrlValue, {
        method: "POST",
        headers: { "Content-Type": "application/json", Accept: "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content },
        body
      })
      const data = await response.json().catch(() => ({}))
      if (response.ok) {
        this.state = "saved"
        return Turbo.visit(data.url, { action: "replace" })
      }
      if (response.status >= 400 && response.status < 500) {
        this.state = "rejected"
        return this.status(data.error || "Sorry, this game couldn't be saved.")
      }
    } catch {
      // Offline: try again below
    }
    this.status("Your game couldn't be saved. Check your connection and try again.")
    this.retryButton().hidden = false
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
