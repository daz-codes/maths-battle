import { Controller } from "@hotwired/stimulus"
import { Turbo, cable } from "@hotwired/turbo-rails"
import { chooseQuestionSet, playerKey, preparePlayer, postGame, saveForLater, watchPlayer } from "lib/offline_games"
import { finished, shown, typedWith } from "lib/answer_input"
import * as feedback from "lib/feedback"
import confetti from "canvas-confetti"

const DURATION = 60_000
// The second pop, for the answer's speed, comes just after the first
const SPEED_POP_DELAY = 140
// A Power game's box is asked for just after it's due, so the server's clock agrees it is
const BOX_DELAY = 150
const NEWS_TIME = 3_000
const POWER_UP_VERBS = { shrink: "shrank", flip: "flipped", ink: "splatted", freeze: "froze", scramble: "scrambled", lightning: "zapped" }
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
// after a warning, and then nothing is saved. A review has no clock or score: it asks each of its
// questions once and ends after the last
export default class extends Controller {
  static targets = [ "question", "answer", "right", "score", "quarter", "hand", "seconds", "status", "keypad", "stopDialog", "offlineResult", "offlineScore", "unavailable", "stage", "progress", "best", "ghost", "rival", "combo", "powerSlot", "powerNews", "powerIcon", "speedIcon", "trophyIcon" ]
  static values = { questionSets: Array, topic: String, level: Number, mode: String, round: String, best: Number, passed: { type: String, default: "New best!" }, ghost: Object, live: Object, submitUrl: String, keys: Array, scoring: Object }

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
    this.fitQuestions()
    this.player = playerKey()
    this.state = "countdown"
    this.index = 0
    this.typed = ""
    this.correct = 0
    this.rawPoints = 0
    this.inARow = 0
    this.ghostScore = 0
    this.results = []

    this.keydown = this.keydown.bind(this)
    this.beforeUnload = this.beforeUnload.bind(this)
    this.tick = this.tick.bind(this)
    document.addEventListener("keydown", this.keydown)
    window.addEventListener("beforeunload", this.beforeUnload)

    if (this.review) this.startReview()
    else if (this.live) this.joinLive()
    else this.countdown(COUNTDOWN)
  }

  // A live game: everyone starts at the same moment, set by the server, and plays the same minute
  get live() {
    return this.hasLiveValue
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
    if (data.type === "box") this.gotPowerUp(data.power_up)
    else if (data.type === "power_up") this.powerUpUsed(data)
    else this.rivalScored(data)
  }

  // A Power game's boxes come at 15, 30 and 45 seconds into everyone's minute. The server says what's inside
  askForBoxes() {
    if (!this.live || !this.liveValue.power) return

    const { boxEveryMs, boxes } = this.liveValue
    this.boxTimers = Array.from({ length: boxes }, (_, i) =>
      setTimeout(() => this.liveChannel?.perform("open_box"), this.liveStartAt + boxEveryMs * (i + 1) - performance.now() + BOX_DELAY))
  }

  // Held one at a time: a new box replaces it. A Shield isn't used, it blocks the next attack while it's held
  gotPowerUp(powerUp) {
    this.powerUp = powerUp
    const { name } = this.liveValue.powerUps[powerUp]
    const shield = powerUp === "shield"
    this.powerSlotTarget.replaceChildren(this.powerIcon(powerUp), ` ${shield ? "Shield up" : name}`)
    this.powerSlotTarget.classList.toggle("test__power--shield", shield)
    this.powerSlotTarget.disabled = shield
    this.powerSlotTarget.hidden = false
    this.powerSlotTarget.classList.remove("test__power--new")
    void this.powerSlotTarget.offsetWidth // so the pulse plays again
    this.powerSlotTarget.classList.add("test__power--new")
    this.news(shield ? "You've got a Shield: it'll block the next attack" : `You've got ${name}! Tap it, or press Space, to use it`)
  }

  usePowerUp() {
    if (!this.powerUp || this.powerUp === "shield" || this.state !== "running") return

    this.liveChannel?.perform("use_power_up")
    this.clearPowerUp()
  }

  clearPowerUp() {
    this.powerUp = null
    this.powerSlotTarget.hidden = true
  }

  // Someone used one: it hit them, or a Shield blocked it, and it's news to everyone it touched
  powerUpUsed({ power_up, from, hit, blocked }) {
    const me = this.liveValue.me
    const { name } = this.liveValue.powerUps[power_up]
    if (hit.includes(me)) {
      this.hitBy(power_up)
      this.news(`${this.playerName(from)} ${POWER_UP_VERBS[power_up]} you!`)
    } else if (blocked.includes(me)) {
      if (this.powerUp === "shield") this.clearPowerUp()
      this.news(`Your Shield blocked ${this.playerName(from)}'s ${name}!`)
    } else if (from === me) {
      if (hit.length) this.news(`You ${POWER_UP_VERBS[power_up]} ${hit.map((id) => this.playerName(id)).join(" and ")}!`)
      else if (blocked.length) this.news(`${blocked.map((id) => this.playerName(id)).join(" and ")}'s Shield blocked it!`)
      else this.news("No one was ahead to hit!")
    }
  }

  // Freeze and Lightning stop the keypad; the others change how the question looks or where the keys are.
  // The clock keeps going, as it's everyone's
  hitBy(powerUp) {
    const effect = powerUp === "lightning" ? "freeze" : powerUp
    const ms = this.liveValue.powerUps[powerUp].seconds * 1000
    if (effect === "freeze") this.frozenUntil = performance.now() + ms
    if (effect === "scramble") this.scrambleKeys()
    this.element.classList.add(`test--${effect}`)
    clearTimeout(this.effectTimers?.[effect])
    this.effectTimers = { ...this.effectTimers, [effect]: setTimeout(() => this.endEffect(effect), ms) }
    feedback.wrong()
  }

  endEffect(effect) {
    this.element.classList.remove(`test--${effect}`)
    if (effect === "scramble") this.unscrambleKeys()
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

  // Time's up: nothing left to use, and every effect wears off
  endPowerUps() {
    if (this.hasPowerSlotTarget) this.clearPowerUp()
    Object.keys(this.effectTimers ?? {}).forEach((effect) => { clearTimeout(this.effectTimers[effect]); this.endEffect(effect) })
    this.frozenUntil = 0
  }

  powerIcon(powerUp) {
    return this.powerIconTargets.find((template) => template.dataset.powerUp === powerUp).content.cloneNode(true)
  }

  playerName(id) {
    return this.rivalTargets.find((rival) => rival.dataset.playerId === String(id))?.dataset.name ?? "Someone"
  }

  news(message) {
    if (!this.hasPowerNewsTarget) return

    this.powerNewsTarget.textContent = message
    clearTimeout(this.newsTimer)
    this.newsTimer = setTimeout(() => { this.powerNewsTarget.textContent = "" }, NEWS_TIME)
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

    this.liveChannel?.perform("score", { score: this.points, correct: this.correct })
    this.showRivalLeads()
  }

  // Mixed practice's or a review's spares are its own, as its questions are mixed from every level, and a group
  // challenge's are its round's, and a head to head's its own (its id is in the round value too)
  get sparesKey() {
    const kind = { practice: this.levelValue, group: `group-${this.roundValue}`, head_to_head: `h2h-${this.roundValue}` }[this.modeValue] ?? this.modeValue
    return `${this.topicValue}:${kind}`
  }

  get review() {
    return this.modeValue === "review"
  }

  disconnect() {
    this.disconnected = true
    this.liveChannel?.unsubscribe()
    this.boxTimers?.forEach(clearTimeout)
    Object.values(this.effectTimers ?? {}).forEach(clearTimeout)
    clearTimeout(this.newsTimer)
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
    this.endsAt = (this.live ? this.liveStartAt : performance.now()) + DURATION
    this.askForBoxes()
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
    this.moveGhost(DURATION - left)
    const seconds = Math.ceil(left / 1000)
    if (seconds !== this.seconds) {
      this.seconds = seconds
      this.secondsTarget.textContent = seconds
      this.element.dataset.quarter = Math.min(3, Math.floor((60 - seconds) / 15))
      if (seconds <= TICKING_FROM) feedback.clockTick()
    }
    this.frame = requestAnimationFrame(this.tick)
  }

  // A head to head's challenger, racing alongside: their score at this point in their minute, and whether
  // they're ahead
  moveGhost(elapsed) {
    if (!this.hasGhostTarget) return

    const steps = this.ghostValue.steps || []
    const before = this.ghostScore
    this.ghostStep ??= 0
    while (this.ghostStep < steps.length && steps[this.ghostStep][0] <= elapsed) this.ghostScore = steps[this.ghostStep++][1]
    if (this.ghostScore !== before) {
      this.ghostTarget.textContent = `${this.ghostValue.name} ${this.ghostScore.toLocaleString()}`
      this.showGhostLead()
    }
  }

  showGhostLead() {
    if (!this.hasGhostTarget) return

    this.ghostTarget.classList.toggle("test__ghost--ahead", this.ghostScore > this.points)
    this.ghostTarget.classList.toggle("test__ghost--behind", this.ghostScore < this.points)
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
    } else if (event.key === " " && this.powerUp) {
      event.preventDefault()
      this.usePowerUp()
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

  // Not while frozen by a Power game's Freeze or Lightning
  get accepting() {
    return this.state === "running" && !this.showingCorrection && !(this.frozenUntil > performance.now())
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
    this.typed = ""
    this.answerTarget.textContent = ""
    this.answerTarget.classList.remove("answer--wrong")
    this.shownAt = performance.now()
    if (this.hasProgressTarget) this.progressTarget.textContent = `${this.index + 1}/${this.questions.length}`
    if (this.index > 0) this.moveOn()
  }

  // The next question comes down into place. Whether the last was right shows in what floats up (popPoints)
  moveOn() {
    if (reducedMotion.matches) return

    this.questionTarget.animate([ { transform: "translateY(-25%)", opacity: 0 }, { transform: "none", opacity: 1 } ], { duration: 200, easing: "ease-out" })
  }

  // One size for the whole game, so the questions don't jump about: small enough for the longest in the set, as
  // 0.7 × −3000 needs more room than 7 × 8
  fitQuestions() {
    const length = Math.max(...this.questions.map((question) => question.text.replace(/<[^>]+>/g, "").length))
    this.questionTarget.classList.toggle("question--long", length > 8 && length <= 12)
    this.questionTarget.classList.toggle("question--longer", length > 12)
  }

  // The question's own details go back with the answer, so the server can check it for itself
  check() {
    // A question kept on a device from when they had a worked answer still sends just its own details
    const { text, answer, solution, ...question } = this.current
    const ms = Math.round(performance.now() - this.shownAt)
    this.results.push({ ...question, given: this.typed, ms })

    if (this.typed === answer) {
      this.correct++
      if (this.hasRightTarget) this.rightTarget.textContent = this.correct
      if (this.review) this.scoreTarget.textContent = this.correct
      else this.earnPoints(ms)
      this.flash(this.scoreTarget, "--right")
      feedback.right()
      if (this.bestValue && !this.passedBest && this.points > this.bestValue) this.passBest()
      this.showGhostLead()
      this.reportToRivals()
      this.next()
    } else {
      if (!this.review) this.losePoints()
      this.reportToRivals()
      this.showCorrection()
    }
  }

  // The score floats up as it goes: +10 for a right answer, then its speed's own pop (+10 quick, +20 lightning),
  // each multiplied by the combo of right answers in a row. A wrong answer loses some and ends the combo. The server
  // works out the score that counts from the answers, with the same rules (Attempt::Scorable)
  earnPoints(ms) {
    const { right, speed, times } = this.scoringValue
    this.inARow++
    const multiplier = this.multiplier
    if (multiplier > (this.shownMultiplier || 1)) this.showCombo(multiplier)

    this.popPoints(right * multiplier, "right")
    const tier = ms < times.lightning ? "lightning" : ms < times.quick ? "quick" : null
    if (tier) setTimeout(() => this.popPoints(speed[tier] * multiplier, tier, this.speedIconTarget), SPEED_POP_DELAY)
    this.addPoints((right + (tier ? speed[tier] : 0)) * multiplier)
  }

  losePoints() {
    this.inARow = 0
    if (this.shownMultiplier > 1) this.showCombo(1)
    this.popPoints(this.scoringValue.wrong, "wrong")
    this.addPoints(this.scoringValue.wrong)
  }

  // A game never scores less than nothing, though wrong answers can take the running count below it
  addPoints(points) {
    this.rawPoints += points
    this.scoreTarget.textContent = this.points.toLocaleString()
  }

  // The score so far; a review's is how many are right, as it has no clock
  get points() {
    return this.review ? this.correct : Math.max(0, this.rawPoints)
  }

  // ×2 from 5 in a row, ×3 from 10, ×4 from 20
  get multiplier() {
    return Object.entries(this.scoringValue.combos).reduce((multiplier, [ from, times ]) => this.inARow >= Number(from) ? times : multiplier, 1)
  }

  showCombo(multiplier) {
    this.shownMultiplier = multiplier
    if (!this.hasComboTarget) return

    this.comboTarget.hidden = multiplier === 1
    this.comboTarget.textContent = `×${multiplier}`
    if (multiplier > 1) {
      this.comboTarget.classList.remove("test__combo--new")
      void this.comboTarget.offsetWidth // so the pulse plays again
      this.comboTarget.classList.add("test__combo--new")
      this.popText(`×${multiplier}!`, "combo")
    }
  }

  // A speed pop has the lightning bolt after it
  popPoints(points, tier, extraIcon) {
    const pop = this.popText(`${points < 0 ? "−" : "+"}${Math.abs(points)}`, tier)
    if (extraIcon) pop.append(" ", extraIcon.content.cloneNode(true))
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

  // The moment the score passes the level's best, or a rival's: it turns pink, says so, bursts with confetti from the score
  // and plays the fanfare
  passBest() {
    this.passedBest = true
    const score = this.scoreTarget.getBoundingClientRect()
    const origin = { x: (score.left + score.width / 2) / window.innerWidth, y: (score.top + score.height / 2) / window.innerHeight }
    confetti({ particleCount: 140, spread: 100, startVelocity: 40, origin, colors: [ "#efff2e", "#ff5cc6", "#2be4ff", "#5dff7a" ], disableForReducedMotion: true })
    this.element.classList.add("test--beating")
    if (this.hasBestTarget) this.bestTarget.textContent = this.passedValue
    const pop = Object.assign(document.createElement("span"), { className: "score-pop score-pop--best" })
    pop.append(this.trophyIconTarget.content.cloneNode(true), ` ${this.passedValue}`)
    pop.setAttribute("aria-hidden", "true")
    pop.style.setProperty("--drift", "0px")
    pop.addEventListener("animationend", () => pop.remove())
    setTimeout(() => pop.remove(), 2_600)
    this.stageTarget.append(pop)
    feedback.fanfare()
  }

  // The wrong answer stays, in red, for a moment, then the question moves below, marked
  showCorrection() {
    feedback.wrong()
    this.showingCorrection = true
    this.answerTarget.classList.add("answer--wrong")
    this.correctionTimer = setTimeout(() => {
      this.showingCorrection = false
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

  // A live game's clock is everyone's, so it keeps going while paused
  resume() {
    this.element.classList.remove("test--paused")
    if (this.pausedFrom === "countdown") return this.live ? this.waitForLiveStart() : this.restartCountdown()

    const pausedFor = performance.now() - this.pausedAt
    if (!this.live) this.endsAt += pausedFor
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
    this.endPowerUps()
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
      this.status("Sorry, this game couldn't be saved.")
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
    this.offlineScoreTarget.textContent = this.points.toLocaleString()
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
