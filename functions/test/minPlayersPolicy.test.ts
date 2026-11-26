import {test} from 'node:test';
import assert from 'node:assert/strict';
import {
  minCancelOrganizerPush, minCancelPlayerPush, shouldAutoCancel, validMin,
} from '../src/minPlayersPolicy';

const H = 3600_000;
const NOW = Date.UTC(2026, 10, 26, 12);
const base = {nowMs: NOW, min: 6, players: 3};

test('a usable minimum is a whole number of at least 2', () => {
  for (const v of [2, 4, 12]) assert.equal(validMin(v), true, String(v));
  for (const v of [0, 1, -3, 2.5, NaN, '6', null, undefined]) assert.equal(validMin(v), false, String(v));
});

test('checked only in the hour after the 24 h mark', () => {
  assert.equal(shouldAutoCancel({...base, eventMs: NOW + 24 * H}), true);
  assert.equal(shouldAutoCancel({...base, eventMs: NOW + 23.5 * H}), true);
  assert.equal(shouldAutoCancel({...base, eventMs: NOW + 23 * H}), false); // window closed
  assert.equal(shouldAutoCancel({...base, eventMs: NOW + 24 * H + 1}), false); // not yet
  assert.equal(shouldAutoCancel({...base, eventMs: NOW + 5 * H}), false); // created late: never checked
  assert.equal(shouldAutoCancel({...base, eventMs: NOW - H}), false);
});

test('only an underfilled event with a valid minimum is cancelled', () => {
  const at = {eventMs: NOW + 23.5 * H, nowMs: NOW};
  assert.equal(shouldAutoCancel({...at, min: 6, players: 5}), true);
  assert.equal(shouldAutoCancel({...at, min: 6, players: 6}), false);
  assert.equal(shouldAutoCancel({...at, min: 6, players: 9}), false);
  assert.equal(shouldAutoCancel({...at, min: undefined, players: 0}), false);
  assert.equal(shouldAutoCancel({...at, min: 1, players: 0}), false);
  assert.equal(shouldAutoCancel({...at, min: '6', players: 0}), false);
});

test('copy is Spanish, says saldo, names the numbers', () => {
  const p = minCancelPlayerPush('Fútbol 7', 6, 12);
  assert.match(p.body, /Fútbol 7.*mínimo de 6 jugadores/);
  assert.match(p.body, /S\/ 12\.00 de saldo/);
  assert.match(minCancelPlayerPush('X', 6, 0).body, /No se te cobró nada/);
  assert.match(minCancelOrganizerPush('Fútbol 7', 6, 3).body, /3 de 6/);
});
