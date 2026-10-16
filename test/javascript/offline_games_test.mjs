import { test, beforeEach } from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const source = await readFile(new URL('../../app/javascript/lib/offline_games.js', import.meta.url), 'utf8')
const offline = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`)
let owner, version, blocked

beforeEach(() => {
  owner = 'ada'
  version = 1
  blocked = false
  const storage = {}
  Object.defineProperties(storage, {
    getItem: { value: key => storage[key] ?? null },
    setItem: { value: (key, value) => { if (blocked) throw new Error('QuotaExceededError'); storage[key] = String(value) } },
    removeItem: { value: key => { delete storage[key] } }
  })
  globalThis.localStorage = storage
  globalThis.document = { querySelector: selector => ({ content: selector.includes('player-version') ? String(version) : owner }) }
  offline.preparePlayer()
})

const game = () => ({ player_key: owner, client_id: 'one-game', results: [] })

test('a blocked storage write reports failure instead of claiming the game was saved', () => {
  blocked = true
  assert.equal(offline.saveForLater(game()), false)
  assert.deepEqual(offline.unsentGames(), [])
})

test('switching players clears the previous queue and blocks a stale tab', async () => {
  const previous = game()
  assert.equal(offline.saveForLater(previous), true)
  owner = 'bob'
  version = 2
  offline.preparePlayer()
  assert.deepEqual(offline.unsentGames(), [])
  owner = 'ada'
  version = 1
  offline.preparePlayer()
  globalThis.fetch = () => { throw new Error('a stale game must not be sent') }
  assert.equal(offline.saveForLater(previous), false)
  assert.equal((await offline.postGame('/attempts', previous)).outcome, 'rejected')
  assert.equal(localStorage.getItem('matheminute:active-player'), 'bob')
})

test('online play still works when the browser cannot write player state', async () => {
  owner = 'bob'
  version = 2
  blocked = true
  offline.preparePlayer()
  globalThis.fetch = async () => new Response(JSON.stringify({ url: '/attempts/1' }), { status: 201 })
  assert.equal((await offline.postGame('/attempts', game())).outcome, 'saved')
  assert.equal(offline.saveForLater(game()), false)
})

test('switching accounts during an upload cannot modify the new queue', async () => {
  offline.saveForLater(game())
  let finish
  globalThis.fetch = () => new Promise(resolve => { finish = resolve })
  const sending = offline.sendUnsentGames('/attempts')
  owner = 'bob'
  version = 2
  offline.preparePlayer()
  offline.saveForLater(game())
  finish(new Response(JSON.stringify({ url: '/attempts/1' }), { status: 201 }))
  assert.equal(await sending, 0)
  assert.equal(offline.unsentGames().length, 1)
})

test('a server refusal is reported and does not prevent subsequent uploads', async () => {
  offline.saveForLater(game())
  offline.saveForLater({ ...game(), client_id: 'two' })
  let count = 0
  globalThis.fetch = async () => ++count === 1
    ? new Response(JSON.stringify({ error: 'expired' }), { status: 422 })
    : new Response(JSON.stringify({ url: '/attempts/2' }), { status: 201 })
  assert.equal(await offline.sendUnsentGames('/attempts'), 1)
  assert.deepEqual(offline.unsentGames(), [])
  assert.equal(offline.takeRefusedGames(), 1)
  assert.equal(offline.takeRefusedGames(), 0)
})

test('offline sets stay with their topic and level and are never reused', () => {
  const tables = [{ id: 't1' }, { id: 't2' }]
  const equations = [{ id: 'e1' }, { id: 'e2' }]
  assert.equal(offline.chooseQuestionSet(tables, 'tables:1').id, 't1')
  assert.equal(offline.chooseQuestionSet(equations, 'equations:2').id, 'e1')
  assert.equal(offline.chooseQuestionSet(tables, 'tables:1').id, 't2')
  assert.equal(offline.chooseQuestionSet(tables, 'tables:1'), null)
})
