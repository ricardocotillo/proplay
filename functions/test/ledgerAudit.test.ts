import {test} from 'node:test';
import assert from 'node:assert/strict';
import {ledgerSuspicion} from '../src/ledgerAudit';

const NOW = 1_000_000;
const at = (ms: number) => ({toMillis: () => ms});

test('function-shaped rows pass', () => {
  assert.deepEqual(ledgerSuspicion('spend_s_u_t', {
    entryType: 'spend', createdAt: at(NOW - 1), balanceBefore: 20, balanceAfter: 10,
  }, NOW), []);
  assert.deepEqual(ledgerSuspicion('refund_spend_s_u_t', {entryType: 'refund', createdAt: at(1)}, NOW), []);
  assert.deepEqual(ledgerSuspicion('abc', {entryType: 'purchase', creditAmount: 15, amountPaid: 17}, NOW), []);
});

test('forged shapes are flagged', () => {
  assert.ok(ledgerSuspicion('x', {entryType: 'spend', createdAt: at(NOW + 1)}, NOW).length >= 2);
  assert.match(ledgerSuspicion('refund_spend_s_v_t', {entryType: 'purchase', creditAmount: 1, amountPaid: 1}, NOW)[0], /blocks/);
  assert.match(ledgerSuspicion('y', {entryType: 'refund'}, NOW)[0], /refund_spend_/);
  assert.match(ledgerSuspicion('z', {entryType: 'purchase', creditAmount: 1000, amountPaid: 10}, NOW)[0], /more saldo/);
});
