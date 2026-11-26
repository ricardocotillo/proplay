import {test} from 'node:test';
import assert from 'node:assert/strict';
import {
  Entry, freeSeats, HOLD_MS, isActiveOffer, minutesLeft, offerExpiryMs, pickLateCancel, pickNext,
} from '../src/waitlistPolicy';
import {lateCancelRefundPush, waitlistOfferPush} from '../src/reminderPolicy';

const NOW = 1_000_000_000;

test('an offer holds a seat only until it expires', () => {
  const e: Entry = {uid: 'a', status: 'offered', joinedAtMs: 1, offerExpiresAtMs: NOW + 1};
  assert.equal(isActiveOffer(e, NOW), true);
  assert.equal(isActiveOffer(e, NOW + 1), false);
  assert.equal(isActiveOffer({...e, status: 'waiting'}, NOW), false);
  assert.equal(isActiveOffer({...e, offerExpiresAtMs: undefined}, NOW), false);
});

test('hold is 30 min, capped at the event start', () => {
  assert.equal(offerExpiryMs(NOW, NOW + 5 * 3600_000), NOW + HOLD_MS);
  assert.equal(offerExpiryMs(NOW, NOW + 10 * 60_000), NOW + 10 * 60_000);
});

test('free seats subtract players and live holds, never below 0', () => {
  assert.equal(freeSeats(10, 9, 0), 1);
  assert.equal(freeSeats(10, 9, 1), 0);
  assert.equal(freeSeats(10, 10, 0), 0);
  assert.equal(freeSeats(10, 12, 3), 0);
});

test('next in line is the oldest waiting entry; offered ones are skipped', () => {
  const list: Entry[] = [
    {uid: 'c', status: 'waiting', joinedAtMs: 30},
    {uid: 'a', status: 'offered', joinedAtMs: 5, offerExpiresAtMs: NOW},
    {uid: 'b', status: 'waiting', joinedAtMs: 10},
    {uid: 'a2', status: 'waiting', joinedAtMs: 10},
  ];
  assert.equal(pickNext(list)?.uid, 'a2'); // tie on time: uid order
  assert.equal(pickNext([{uid: 'x', status: 'offered', joinedAtMs: 1}]), undefined);
  assert.equal(pickNext([]), undefined);
});

test('a waitlist fill pays back the oldest unrefunded late cancel, never the filler', () => {
  const rows = [
    {uid: 'u1', spendId: 's1', createdAtMs: 30, refunded: false},
    {uid: 'u2', spendId: 's2', createdAtMs: 10, refunded: true},
    {uid: 'u3', spendId: 's3', createdAtMs: 20, refunded: false},
    {uid: 'filler', spendId: 's4', createdAtMs: 1, refunded: false},
  ];
  assert.equal(pickLateCancel(rows, 'filler')?.uid, 'u3');
  assert.equal(pickLateCancel(rows.map((r) => ({...r, refunded: true})), 'filler'), undefined);
});

test('minutes left rounds up and is at least 1', () => {
  assert.equal(minutesLeft(NOW + 30 * 60_000, NOW), 30);
  assert.equal(minutesLeft(NOW + 90_000, NOW), 2);
  assert.equal(minutesLeft(NOW, NOW), 1);
});

test('push copy names the event and the hold; refund says saldo in S/', () => {
  const o = waitlistOfferPush('Fútbol 7', 'e1', 30);
  assert.match(o.body, /Fútbol 7.*30 min/);
  assert.equal(o.path, '/events/e1');
  assert.match(lateCancelRefundPush(12, 'Fútbol 7').body, /S\/ 12\.00/);
});
