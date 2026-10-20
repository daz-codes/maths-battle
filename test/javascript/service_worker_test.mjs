import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import vm from 'node:vm'

const source = await readFile(new URL('../../app/views/pwa/service-worker.js', import.meta.url), 'utf8')

function worker() {
  const stores = new Map()
  const caches = {
    keys: async () => [...stores.keys()],
    delete: async key => stores.delete(key),
    open: async name => {
      if (!stores.has(name)) stores.set(name, new Map())
      const entries = stores.get(name)
      return {
        put: async (key, response) => entries.set(String(key), response.clone()),
        match: async key => entries.get(String(key))?.clone()
      }
    },
    match: async (key, { cacheName } = {}) => (await caches.open(cacheName)).match(key)
  }
  const context = vm.createContext({ caches, Response, Date, URL, setTimeout, clearTimeout, self: { addEventListener() {} } })
  vm.runInContext(source, context)
  return { context, stores, caches, ...vm.runInContext('({ fromNetwork })', context) }
}

const request = path => new Request(`https://example.test${path}`, { headers: { Accept: 'text/html' } })
const page = (owner, version, body = owner, expires = new Date(Date.now() + 60000).toISOString()) => new Response(body, {
  headers: { 'X-Player-Key': owner, 'X-Player-Version': String(version), 'X-Player-Expires': expires }
})

async function load(w, path, response) {
  w.context.fetch = async () => response
  return w.fromNetwork(request(path), new URL(`https://example.test${path}`))
}

test('account changes erase private pages and a late response cannot restore the old cache', async () => {
  const w = worker()
  await load(w, '/stats', page('ada', 1))
  let finish
  const fetching = new Promise(started => {
    w.context.fetch = () => new Promise(resolve => { finish = resolve; started() })
  })
  const oldRequest = w.fromNetwork(request('/stats'), new URL('https://example.test/stats'))
  await fetching
  await load(w, '/', page('bob', 2))
  finish(page('ada', 1))
  await oldRequest
  assert.equal(w.stores.has('matheminute-pages-v4-ada'), false)
  w.context.fetch = async () => { throw new Error('offline') }
  await (await w.caches.open('matheminute-v6')).put('/offline.html', new Response('offline'))
  const response = await w.fromNetwork(request('/stats'), new URL('https://example.test/stats'))
  assert.equal(await response.text(), 'offline')
})

test('level query parameters select separate offline pages', async () => {
  const w = worker()
  await load(w, '/play/times-tables?level=1', page('ada', 1, 'level one'))
  await load(w, '/play/times-tables?level=2', page('ada', 1, 'level two'))
  w.context.fetch = async () => { throw new Error('offline') }
  const response = await w.fromNetwork(request('/play/times-tables?level=1'), new URL('https://example.test/play/times-tables?level=1'))
  assert.equal(await response.text(), 'level one')
})

test('the awards page opens offline', async () => {
  const w = worker()
  await load(w, '/awards', page('ada', 1, 'achievements'))
  w.context.fetch = async () => { throw new Error('offline') }
  const response = await w.fromNetwork(request('/awards'), new URL('https://example.test/awards'))
  assert.equal(await response.text(), 'achievements')
})

test('expired sessions cannot open private cached pages offline', async () => {
  const w = worker()
  await load(w, '/stats', page('ada', 1, 'private', '2000-01-01T00:00:00Z'))
  await (await w.caches.open('matheminute-v6')).put('/offline.html', new Response('offline'))
  w.context.fetch = async () => { throw new Error('offline') }
  const response = await w.fromNetwork(request('/stats'), new URL('https://example.test/stats'))
  assert.equal(await response.text(), 'offline')
})

test('on a connection that never answers, the app opens to the copy kept for offline, quickly', async () => {
  const w = worker()
  vm.runInContext('TIMEOUTS.withCopy = 20; TIMEOUTS.network = 60_000', w.context)
  await load(w, '/', page('ada', 1, 'kept home'))
  w.context.fetch = () => new Promise(() => {})

  const response = await w.fromNetwork(request('/'), new URL('https://example.test/'))
  assert.equal(await response.text(), 'kept home')
})

test('a page with no copy waits longer, then shows the offline page', async () => {
  const w = worker()
  vm.runInContext('TIMEOUTS.withCopy = 60_000; TIMEOUTS.network = 20', w.context)
  await load(w, '/', page('ada', 1, 'kept home'))
  await (await w.caches.open('matheminute-v6')).put('/offline.html', new Response('offline'))
  w.context.fetch = () => new Promise(() => {})

  const response = await w.fromNetwork(request('/topics'), new URL('https://example.test/topics'))
  assert.equal(await response.text(), 'offline')
})

test('a copy that never finishes keeping doesn\'t hold up this page or the next', async () => {
  const w = worker()
  vm.runInContext('TIMEOUTS.keeping = 20', w.context)
  const stuck = w.caches.open
  w.caches.open = async name => {
    const cache = await stuck(name)
    return name.startsWith('matheminute-pages') ? { ...cache, put: () => new Promise(() => {}) } : cache
  }

  assert.equal(await (await load(w, '/', page('ada', 1, 'home'))).text(), 'home')
  assert.equal(await (await load(w, '/stats', page('ada', 1, 'stats'))).text(), 'stats')
})
