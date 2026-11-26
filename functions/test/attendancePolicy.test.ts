import {test} from 'node:test';
import assert from 'node:assert/strict';
import {
  blockedMessage, BLOCK_MS, isBlocked, isNoShow, nextBlockMs, noShowActions, noShowBlockPush,
  noShowWarnPush, WINDOW_MS,
} from '../src/attendancePolicy';

const NOW = Date.UTC(2026, 10, 26, 12);

test('the 2nd no-show warns, the 3rd and later block, the 1st does nothing', () => {
  assert.deepEqual(noShowActions(1), {warn: false, block: false});
  assert.deepEqual(noShowActions(2), {warn: true, block: false});
  assert.deepEqual(noShowActions(3), {warn: false, block: true});
  assert.deepEqual(noShowActions(5), {warn: false, block: true});
});

test('a block lasts until its date; absent means not blocked', () => {
  assert.equal(isBlocked(NOW + 1, NOW), true);
  assert.equal(isBlocked(NOW, NOW), false);
  assert.equal(isBlocked(undefined, NOW), false);
});

test('a new block is 14 days out and never shortens an existing one', () => {
  assert.equal(nextBlockMs(undefined, NOW), NOW + BLOCK_MS);
  assert.equal(nextBlockMs(NOW + 20 * 86_400_000, NOW), NOW + 20 * 86_400_000);
  assert.equal(nextBlockMs(NOW - 1000, NOW), NOW + BLOCK_MS);
});

test('only a never-used ticket of an event with attendance is a no-show', () => {
  assert.equal(isNoShow('valid', true), true);
  assert.equal(isNoShow('used', true), false);
  assert.equal(isNoShow('valid', false), false); // nobody checked in: attendance was not taken
});

test('the window is 90 days', () => {
  assert.equal(WINDOW_MS, 90 * 86_400_000);
});

test('copy is Spanish, links to the policy, says the numbers', () => {
  assert.match(noShowWarnPush('Fútbol 7').body, /2 ausencias en 90 días.*14 días/);
  assert.equal(noShowWarnPush('x').path, '/politica-asistencia');
  assert.match(noShowBlockPush(NOW + BLOCK_MS).body, /3 ausencias/);
  assert.match(blockedMessage(Date.UTC(2026, 11, 10, 15)), /hasta el 10 de diciembre/);
});
