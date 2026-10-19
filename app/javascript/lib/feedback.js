// Sounds and haptics: a tick for a right answer, a soft buzz for a wrong one, a fanfare for a level up, beeps
// for the countdown and a clock ticking through a game's last seconds.
// Made with the Web Audio API, so there are no files to load or keep for offline. Players turn them off in
// settings, which the page says on <html data-sounds="off">. Vibration is only where the browser allows it
// (not iPhones). Browsers only let sound start from a tap or key press, so the first one wakes the audio up.
// An iPhone on silent plays no web sounds
let context

const sounding = () => document.documentElement.dataset.sounds !== "off"

function audio() {
  const AudioContext = window.AudioContext || window.webkitAudioContext
  if (!AudioContext) return null

  context ||= new AudioContext()
  if (context.state === "suspended") context.resume().catch(() => {})
  return context
}

export function wakeAudio() {
  if (sounding()) audio()
}

for (const event of [ "pointerdown", "pointerup", "keydown" ]) {
  globalThis.document?.addEventListener(event, wakeAudio, { capture: true, passive: true })
}

// One note, faded in and out so it doesn't click
function note(audio, { frequency, at = 0, length, wave = "sine", volume = 0.2, slideTo }) {
  const start = audio.currentTime + at
  const oscillator = audio.createOscillator()
  const gain = audio.createGain()
  oscillator.type = wave
  oscillator.frequency.setValueAtTime(frequency, start)
  if (slideTo) oscillator.frequency.exponentialRampToValueAtTime(slideTo, start + length)
  gain.gain.setValueAtTime(0.0001, start)
  gain.gain.exponentialRampToValueAtTime(volume, start + 0.01)
  gain.gain.exponentialRampToValueAtTime(0.0001, start + length)
  oscillator.connect(gain).connect(audio.destination)
  oscillator.start(start)
  oscillator.stop(start + length + 0.05)
}

function play(notes, vibration) {
  if (!sounding()) return

  const sound = audio()
  if (sound) notes.forEach(each => note(sound, each))
  if (vibration) navigator.vibrate?.(vibration)
}

export function right() {
  play([ { frequency: 1568, length: 0.06, wave: "triangle", volume: 0.15 } ], 10)
}

export function wrong() {
  play([ { frequency: 180, slideTo: 120, length: 0.22, wave: "square", volume: 0.05 } ], [ 35, 40, 35 ])
}

// Ready and Set are low beeps, GO! a higher, longer one, like the start of a race
export function countdown(go) {
  play([ go ? { frequency: 880, length: 0.4, volume: 0.18 } : { frequency: 440, length: 0.16, volume: 0.15 } ], go && 20)
}

// The clock in a game's last seconds: a short, woody tock, lower than a right answer's tick so they're told apart
export function clockTick() {
  play([ { frequency: 750, length: 0.04, wave: "square", volume: 0.06 } ])
}

// C, E, G and a long high C
export function fanfare() {
  const notes = [ 523, 659, 784 ].map((frequency, i) => ({ frequency, at: i * 0.13, length: 0.15, wave: "triangle", volume: 0.18 }))
  play([ ...notes, { frequency: 1047, at: 0.39, length: 0.7, wave: "triangle", volume: 0.2 } ], [ 30, 60, 30, 60, 120 ])
}
