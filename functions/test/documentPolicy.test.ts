import {test} from 'node:test';
import assert from 'node:assert/strict';
import {
  cooldownMessage, DOCUMENT_COOLDOWN_MS, documentKey, isValidDocument, nextChangeMs, normalizeDocument,
} from '../src/documentPolicy';

const NOW = Date.UTC(2026, 10, 27, 12);
const DAY = 86_400_000;

test('no previous change: allowed now', () => {
  assert.equal(nextChangeMs(undefined, NOW), null);
});

test('cooldown boundary: 29 days blocked, exactly 30 and 31 allowed', () => {
  assert.equal(nextChangeMs(NOW - 29 * DAY, NOW), NOW - 29 * DAY + DOCUMENT_COOLDOWN_MS);
  assert.equal(nextChangeMs(NOW - 30 * DAY, NOW), null);
  assert.equal(nextChangeMs(NOW - 31 * DAY, NOW), null);
});

test('isValidDocument mirrors the registration rules', () => {
  assert.equal(isValidDocument('dni', '12345678'), true);
  assert.equal(isValidDocument('ce', 'AB1234567'), true);
  for (const [t, n] of [
    ['dni', '1234567'], ['dni', '1234567A'], ['ce', 'A1234567'], ['ce', 'ABC1234567890'],
    ['passport', 'X'], ['dni', 12345678], ['dni', undefined],
  ]) assert.equal(isValidDocument(t, n), false, `${t} ${n}`);
});

test('normalize and key', () => {
  assert.equal(normalizeDocument(' ab1234567 '), 'AB1234567');
  assert.equal(documentKey('dni', '12345678'), 'dni_12345678');
});

test('cooldown message names the 30 days', () => {
  assert.match(cooldownMessage(NOW), /30 días/);
});
