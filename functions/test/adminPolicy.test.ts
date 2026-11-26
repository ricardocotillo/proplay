import {test} from 'node:test';
import assert from 'node:assert/strict';
import {canManageEvent, reviewError} from '../src/adminPolicy';

test('creator, group owner/admin and superUser manage; members and strangers do not', () => {
  const base = {uid: 'u1', creatorId: 'other', memberRole: undefined, superUser: false};
  assert.equal(canManageEvent(base), false);
  assert.equal(canManageEvent({...base, memberRole: 'member'}), false);
  assert.equal(canManageEvent({...base, creatorId: 'u1'}), true);
  assert.equal(canManageEvent({...base, memberRole: 'owner'}), true);
  assert.equal(canManageEvent({...base, memberRole: 'admin'}), true);
  assert.equal(canManageEvent({...base, superUser: true}), true);
  assert.equal(canManageEvent({...base, uid: '', creatorId: ''}), false);
});

test('only a valid pending purchase can be reviewed', () => {
  const ok = {status: 'pending', entryType: 'purchase', userId: 'u1', creditAmount: 20, amountPaid: 21};
  assert.equal(reviewError(ok), null);
  assert.equal(reviewError({...ok, amountPaid: 20}), null);
  assert.equal(reviewError(undefined)?.code, 'not-found');
  for (const status of ['approved', 'rejected', 'completed']) {
    assert.match(reviewError({...ok, status})!.message, /ya fue revisada/);
  }
  for (const bad of [
    {entryType: 'spend'}, {userId: ''}, {userId: 7}, {creditAmount: 0},
    {creditAmount: -5}, {creditAmount: '20'}, {creditAmount: NaN},
    {amountPaid: 10}, {amountPaid: undefined}, {amountPaid: '21'},
  ]) {
    assert.match(reviewError({...ok, ...bad})!.message, /no es válida/, JSON.stringify(bad));
  }
});
