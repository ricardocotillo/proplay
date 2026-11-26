import {test} from 'node:test';
import assert from 'node:assert/strict';
import {joinError, spendDocId, JoinCheck} from '../src/joinPolicy';

const NOW = Date.UTC(2026, 10, 26, 12);
const ok: JoinCheck = {
  eventDateMs: NOW + 3600_000, nowMs: NOW, isPrivate: false, isMember: false,
  playerCount: 3, maxPlayers: 10, balance: 20, cost: 10,
};

test('open public event with enough balance: no error', () => {
  assert.equal(joinError(ok), null);
  assert.equal(joinError({...ok, balance: 10}), null);
});

test('private event needs membership', () => {
  assert.equal(joinError({...ok, isPrivate: true})?.code, 'permission-denied');
  assert.equal(joinError({...ok, isPrivate: true, isMember: true}), null);
});

test('started, undated, full, and short balance are rejected in that order', () => {
  assert.match(joinError({...ok, eventDateMs: NOW})!.message, /empezó/);
  assert.match(joinError({...ok, eventDateMs: null})!.message, /empezó/);
  assert.match(joinError({...ok, playerCount: 10, balance: 0})!.message, /lleno/);
  assert.match(joinError({...ok, maxPlayers: 0})!.message, /lleno/);
  assert.equal(
    joinError({...ok, balance: 9.5})!.message,
    'No tienes saldo suficiente. Necesitas S/ 10.00 y tienes S/ 9.50.',
  );
});

test('spend id is deterministic per join token', () => {
  assert.equal(spendDocId('s', 'u', 't'), 'spend_s_u_t');
});
