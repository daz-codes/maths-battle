import { test, beforeEach } from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

// A page with a fake audio context that records each note, and a vibration motor that records each buzz
let notes, buzzes, contexts, resumes, silences, state = 'running'
globalThis.document = { documentElement: { dataset: {} }, addEventListener() {} }
globalThis.window = {
  AudioContext: class {
    constructor() { contexts++; this.currentTime = 0; this.destination = {} }
    get state() { return state }
    resume() { resumes++; return Promise.resolve() }
    createBuffer() { return {} }
    createBufferSource() { return { connect() {}, start() { silences++ } } }
    createOscillator() {
      const oscillator = { frequency: { setValueAtTime: hz => oscillator.hz = hz, exponentialRampToValueAtTime() {} }, connect: gain => gain, start() { notes.push(oscillator.hz) }, stop() {} }
      return oscillator
    }
    createGain() { return { gain: { setValueAtTime() {}, exponentialRampToValueAtTime() {} }, connect() {} } }
  }
}
Object.defineProperty(globalThis, 'navigator', { value: { vibrate: pattern => buzzes.push(pattern) }, configurable: true })

const source = await readFile(new URL('../../app/javascript/lib/feedback.js', import.meta.url), 'utf8')
const feedback = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`)

beforeEach(() => {
  notes = []
  buzzes = []
  contexts = 0
  resumes = 0
  silences = 0
  state = 'running'
  document.documentElement.dataset.sounds = 'on'
})

test('a tick and a tap for right, a low buzz for wrong, a rising fanfare for a level up', () => {
  feedback.right()
  feedback.wrong()
  feedback.fanfare()

  assert.deepEqual(notes, [ 1568, 180, 523, 659, 784, 1047 ])
  assert.deepEqual(buzzes, [ 10, [ 35, 40, 35 ], [ 30, 60, 30, 60, 120 ] ])
})

test('one audio context for the whole visit', () => {
  feedback.right()
  feedback.right()
  assert.ok(contexts <= 1)
})

test('a tap wakes audio iOS has stopped, suspended or interrupted, with a moment of silence', () => {
  for (state of [ 'suspended', 'interrupted' ]) feedback.wakeAudio()
  assert.deepEqual([ resumes, silences ], [ 2, 2 ])

  state = 'running'
  feedback.wakeAudio()
  assert.deepEqual([ resumes, silences ], [ 2, 2 ], 'nothing to do once it is running')
})

test('silent and still when turned off', () => {
  document.documentElement.dataset.sounds = 'off'
  feedback.right()
  feedback.wrong()
  feedback.fanfare()
  feedback.wakeAudio()

  assert.deepEqual([ notes, buzzes ], [ [], [] ])
})

test('no sound where there is no Web Audio, but still a buzz', () => {
  const { AudioContext } = window
  delete window.AudioContext
  try {
    feedback.right()
    assert.deepEqual([ notes, buzzes ], [ [], [ 10 ] ])
  } finally {
    window.AudioContext = AudioContext
  }
})
