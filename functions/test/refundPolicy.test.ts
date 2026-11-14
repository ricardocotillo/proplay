import {test} from 'node:test';
import assert from 'node:assert/strict';
import {
  isRefundable,
  formatCredits,
  refundDocId,
  refundAmount,
  pickUnrefundedSpend,
  REFUND_WINDOW_MS,
} from '../src/refundPolicy';

const now = new Date('2026-11-13T12:00:00Z');

test('exactly 24 h before is refundable', () => {
  assert.equal(isRefundable(new Date(now.getTime() + REFUND_WINDOW_MS), now), true);
});

test('24 h minus 1 ms is not refundable', () => {
  assert.equal(isRefundable(new Date(now.getTime() + REFUND_WINDOW_MS - 1), now), false);
});

test('past event is not refundable', () => {
  assert.equal(isRefundable(new Date(now.getTime() - 1000), now), false);
});

test('formatCredits uses 2 decimals', () => {
  assert.equal(formatCredits(15), '15.00');
  assert.equal(formatCredits(7.5), '7.50');
});

test('refundDocId derives from the spend id', () => {
  assert.equal(refundDocId('abc'), 'refund_abc');
});

test('refundAmount is capped at the event price', () => {
  assert.equal(refundAmount(500, 10), 10);
  assert.equal(refundAmount(10, 10), 10);
  assert.equal(refundAmount(5, 10), 5);
});

test('refundAmount refunds nothing on invalid input', () => {
  assert.equal(refundAmount(-3, 10), 0);
  assert.equal(refundAmount(10, undefined), 0);
  assert.equal(refundAmount(NaN, 10), 0);
});

test('pickUnrefundedSpend takes the latest unrefunded row', () => {
  const rows = [
    {id: 'a', creditAmount: 10, createdAtMs: 1, refunded: false},
    {id: 'b', creditAmount: 10, createdAtMs: 3, refunded: true},
    {id: 'c', creditAmount: 10, createdAtMs: 2, refunded: false},
  ];
  assert.equal(pickUnrefundedSpend(rows)?.id, 'c');
  assert.equal(pickUnrefundedSpend(rows.map((r) => ({...r, refunded: true}))), undefined);
  assert.equal(pickUnrefundedSpend([]), undefined);
});
