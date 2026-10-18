import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

const source = await readFile(new URL('../../app/javascript/lib/answer_input.js', import.meta.url), 'utf8')
const { allowedKey, finished, shown, typedWith } = await import(`data:text/javascript;base64,${Buffer.from(source).toString('base64')}`)

test('an answer is only finished once it ends in a digit', () => {
  assert.equal(finished('18'), true)
  assert.equal(finished('0.'), false)
  assert.equal(finished('-'), false)
  assert.equal(finished('3/'), false)
  assert.equal(finished('-0.24'), true)
})

test('a minus only comes first, and a point or fraction line once, after a digit', () => {
  assert.equal(allowedKey('', '-', [ '-' ]), true)
  assert.equal(allowedKey('4', '-', [ '-' ]), false)
  assert.equal(allowedKey('0', '.', [ '.' ]), true)
  assert.equal(allowedKey('0.2', '.', [ '.' ]), false)
  assert.equal(allowedKey('', '.', [ '.' ]), false)
  assert.equal(allowedKey('3', '/', []), false, 'only the level\'s own keys')
})

test('a decimal point with nothing before it starts with 0', () => {
  assert.equal(typedWith('', '.', [ '.' ]), '0.')
  assert.equal(typedWith('-', '.', [ '-', '.' ]), '-0.')
  assert.equal(typedWith('0.', '2', [ '.' ]), '0.2')
  assert.equal(typedWith('3', '.', [ '.' ]), '3.')
  assert.equal(typedWith('', '.', []), null, 'only where the level has a decimal point')
  assert.equal(typedWith('0.2', '.', [ '.' ]), null)
})

test('shown with a proper minus sign', () => {
  assert.equal(shown('-56'), '−56')
})
